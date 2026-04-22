import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:blossom/tools/sync_notification.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:blossom/audio/nplayer.dart';
import 'package:blossom/tools/settings.dart';
import 'package:blossom/tools/supported_formats.dart';


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Data Models
// ─────────────────────────────────────────────────────────────────────────────


enum SyncStatus { idle, checking, syncing, success, error }


class RemoteFile {
  final String   path;
  final String   name;
  final int      size;
  final DateTime modified;
  final bool     isDirectory;


  const RemoteFile({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
    required this.isDirectory,
  });
}


class SyncDiff {
  final List<RemoteFile> toDownload;
  final List<File>       toUpload;
  final int              unchangedCount;


  const SyncDiff({
    required this.toDownload,
    required this.toUpload,
    required this.unchangedCount,
  });


  bool get hasChanges   => toDownload.isNotEmpty || toUpload.isNotEmpty;
  int  get totalChanges => toDownload.length + toUpload.length;
}


class SyncProgress {
  final int       total;
  final int       completed;
  final int       failed;
  final String    currentFile;
  final int       totalBytes;
  final int       transferredBytes;
  final double    speedBps;
  final Duration? eta;


  const SyncProgress({
    required this.total,
    required this.completed,
    required this.failed,
    required this.currentFile,
    required this.totalBytes,
    required this.transferredBytes,
    required this.speedBps,
    this.eta,
  });


  double get fileFraction  => total == 0 ? 0 : completed / total;
  double get bytesFraction => totalBytes == 0 ? 0 : transferredBytes / totalBytes;


  String get speedLabel {
    if (speedBps <= 0) return '—';
    if (speedBps >= 1024 * 1024) return '${(speedBps / 1024 / 1024).toStringAsFixed(1)} MB/s';
    if (speedBps >= 1024)        return '${(speedBps / 1024).toStringAsFixed(0)} KB/s';
    return '${speedBps.toStringAsFixed(0)} B/s';
  }


  String get etaLabel {
    final d = eta;
    if (d == null || speedBps <= 0) return '—';
    if (d.inSeconds < 5)  return 'almost done';
    if (d.inMinutes < 1)  return '${d.inSeconds}s';
    if (d.inHours   < 1)  return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Settings Keys
// ─────────────────────────────────────────────────────────────────────────────


class NextcloudKeys {
  static const String serverUrl     = 'nc_server_url';
  static const String username      = 'nc_username';
  static const String password      = 'nc_password';
  static const String remotePath    = 'nc_remote_path';
  static const String enabled       = 'nc_enabled';
  static const String lastSyncTime  = 'nc_last_sync_time';
  static const String uploadEnabled = 'nc_upload_enabled';
}


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - NextcloudSync Service
// ─────────────────────────────────────────────────────────────────────────────


class NextcloudSync extends ChangeNotifier {
  static final NextcloudSync _instance = NextcloudSync._internal();
  factory NextcloudSync() => _instance;
  NextcloudSync._internal();


  // ── Config ─────────────────────────────────────────────────────────────────
  String _serverUrl     = '';
  String _username      = '';
  String _password      = '';
  String _remotePath    = '/Music';
  bool   _enabled       = false;
  bool   _uploadEnabled = true;


  String get serverUrl     => _serverUrl;
  String get username      => _username;
  String get remotePath    => _remotePath;
  bool   get enabled       => _enabled;
  bool   get uploadEnabled => _uploadEnabled;
  bool   get isConfigured  =>
      _serverUrl.isNotEmpty && _username.isNotEmpty && _password.isNotEmpty;


  // ── Runtime State ──────────────────────────────────────────────────────────
  SyncStatus    _status        = SyncStatus.idle;
  String        _statusMessage = 'Not configured';
  SyncProgress? _progress;
  DateTime?     _lastSyncTime;
  SyncDiff?     _pendingDiff;
  String?       _lastError;


  bool _initComplete = false;
  bool get isReady => _initComplete && isConfigured && _enabled;


  SyncStatus    get status        => _status;
  String        get statusMessage => _statusMessage;
  SyncProgress? get progress      => _progress;
  DateTime?     get lastSyncTime  => _lastSyncTime;
  SyncDiff?     get pendingDiff   => _pendingDiff;
  String?       get lastError     => _lastError;
  bool get hasPendingChanges      => _pendingDiff?.hasChanges == true;


  // ── Concurrency ────────────────────────────────────────────────────────────
  // Downloads: 6 parallel streams works well; WebDAV reads are server-bound.
  // Uploads: 8 parallel streams to saturate uplink across multiple TCP flows.
  // Chunked uploads further parallelise within a single large file.
  static const int _downloadConcurrency = 6;
  static const int _uploadConcurrency   = 8;

  // Files >= this threshold use the Nextcloud chunked upload API (v2).
  // Files below it use a single direct PUT via dio (faster for small files).
  // Chunk requirement: 5 MB minimum per chunk (except the last).
  static const int _chunkedThresholdBytes = 10 * 1024 * 1024; // 10 MB
  static const int _chunkSize             = 10 * 1024 * 1024; // 10 MB chunks


  int       _totalBytes       = 0;
  int       _transferredBytes = 0;
  DateTime? _syncStartTime;


  // ── Cancellation ────────────────────────────────────────────────────────
  bool _cancelled = false;
  bool get isCancelled => _cancelled;

  // Active dio CancelTokens so in-flight requests are aborted on cancel.
  final List<CancelToken> _activeCancelTokens = [];

  SyncNotificationManager? _notifier;

  void attachTo(SyncNotificationManager notifier) {
    _notifier = notifier;
  }

  /// Call to abort an in-progress sync gracefully.
  void cancelSync() {
    if (_status != SyncStatus.syncing && _status != SyncStatus.checking) return;
    _cancelled = true;
    for (final token in _activeCancelTokens) {
      token.cancel('Sync cancelled by user');
    }
    _activeCancelTokens.clear();
    _pendingDiff  = null;
    _progress     = null;
    _setStatus(SyncStatus.idle, 'Sync cancelled');
    _log('Sync cancelled by user');
  }


  // ── Throttled notify ─────────────────────────────────────────────────────
  DateTime? _lastThrottledNotify;
  void _throttledNotify() {
    final now = DateTime.now();
    if (_lastThrottledNotify == null ||
        now.difference(_lastThrottledNotify!) >=
            const Duration(milliseconds: 150)) {
      _lastThrottledNotify = now;
      notifyListeners();
    }
  }


  // ── Clients ──────────────────────────────────────────────────────────────
  // webdav.Client for directory operations and downloads (well-tested).
  // Dio instance for uploads — direct PUT / chunked API, no readAsBytes().
  webdav.Client? _client;
  Dio?           _dio;


  webdav.Client _buildClient() {
    final base    = _serverUrl.trimRight().replaceAll(RegExp(r'/$'), '');
    final davRoot = '$base/remote.php/dav/files/$_username/';
    final client  = webdav.newClient(
      davRoot,
      user:     _username,
      password: _password,
      debug:    kDebugMode,
    );
    client.setConnectTimeout(10000);
    client.setSendTimeout(600000);
    client.setReceiveTimeout(600000);
    return client;
  }

  /// Builds a Dio instance pointed at the WebDAV files root.
  /// Uses Basic auth and generous timeouts; connection pooling is handled
  /// internally by Dio's HttpClientAdapter (persistent keep-alive).
  Dio _buildDio() {
    final base    = _serverUrl.trimRight().replaceAll(RegExp(r'/$'), '');
    final davRoot = '$base/remote.php/dav/files/$_username/';
    final credentials = base64Encode(utf8.encode('$_username:$_password'));

    final dio = Dio(BaseOptions(
      baseUrl:        davRoot,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout:    const Duration(minutes: 10),
      receiveTimeout: const Duration(minutes: 10),
      headers: {
        HttpHeaders.authorizationHeader: 'Basic $credentials',
        HttpHeaders.userAgentHeader:     'BlossomMusicApp/1.0',
      },
      // Do not follow redirects automatically for WebDAV MOVE/MKCOL.
      followRedirects:    false,
      validateStatus: (status) => status != null && status < 500,
    ));

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody:  false,
        responseBody: false,
        logPrint:     (obj) => _log(obj.toString()),
      ));
    }

    return dio;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MARK: - Init & Config
  // ─────────────────────────────────────────────────────────────────────────


  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl     = prefs.getString(NextcloudKeys.serverUrl)   ?? '';
    _username      = prefs.getString(NextcloudKeys.username)    ?? '';
    _password      = prefs.getString(NextcloudKeys.password)    ?? '';
    _remotePath    = prefs.getString(NextcloudKeys.remotePath)  ?? '/Music';
    _enabled       = prefs.getBool(NextcloudKeys.enabled)       ?? false;
    _uploadEnabled = prefs.getBool(NextcloudKeys.uploadEnabled) ?? true;


    final lastSyncMs = prefs.getInt(NextcloudKeys.lastSyncTime);
    if (lastSyncMs != null) {
      _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
    }


    if (isConfigured) {
      _client = _buildClient();
      _dio    = _buildDio();
    }


    _statusMessage = isConfigured ? 'Ready' : 'Not configured';
    _initComplete  = true;
    notifyListeners();
    _log('Initialized. enabled=$_enabled configured=$isConfigured');
  }


  Future<void> saveConfig({
    required String serverUrl,
    required String username,
    required String password,
    required String remotePath,
    required bool   uploadEnabled,
  }) async {
    _serverUrl     = serverUrl.trimRight().replaceAll(RegExp(r'/$'), '');
    _username      = username.trim();
    _password      = password;
    _remotePath    = remotePath.trim().startsWith('/')
        ? remotePath.trim()
        : '/${remotePath.trim()}';
    _uploadEnabled = uploadEnabled;


    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(NextcloudKeys.serverUrl,   _serverUrl);
    await prefs.setString(NextcloudKeys.username,    _username);
    await prefs.setString(NextcloudKeys.password,    _password);
    await prefs.setString(NextcloudKeys.remotePath,  _remotePath);
    await prefs.setBool(NextcloudKeys.uploadEnabled, _uploadEnabled);


    if (isConfigured) {
      _client = _buildClient();
      _dio    = _buildDio();
    } else {
      _client = null;
      _dio    = null;
    }

    _statusMessage = isConfigured ? 'Ready' : 'Not configured';
    _pendingDiff   = null;
    notifyListeners();
    _log('Config saved: $_serverUrl  path: $_remotePath');
  }


  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NextcloudKeys.enabled, value);
    notifyListeners();
  }


  // ─────────────────────────────────────────────────────────────────────────
  // MARK: - Connection Test
  // ─────────────────────────────────────────────────────────────────────────


  Future<bool> testConnection() async {
    if (!isConfigured) return false;
    try {
      await _buildClient().ping();
      return true;
    } catch (e) {
      _log('testConnection failed: $e');
      return false;
    }
  }


  /// Quick TCP probe to verify the server is up before issuing WebDAV requests.
  Future<bool> _isServerReachable() async {
    try {
      final uri  = Uri.parse(_serverUrl);
      final host = uri.host;
      final port = uri.port > 0 ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      final socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 5));
      await socket.close();
      return true;
    } catch (e) {
      _log('Reachability check failed: $e');
      return false;
    }
  }


  // ─────────────────────────────────────────────────────────────────────────
  // MARK: - Check For Changes
  // ─────────────────────────────────────────────────────────────────────────


  Future<SyncDiff?> checkForChanges({List<Music>? localMusic}) async {
    if (!isReady) {
      _log('Skipping check — not ready (initComplete=$_initComplete '
          'configured=$isConfigured enabled=$_enabled)');
      return null;
    }


    _cancelled = false;
    _setStatus(SyncStatus.checking, 'Checking Nextcloud…');


    try {
      final client = _client!;


      final reachable = await _isServerReachable();
      if (!reachable) {
        _setStatus(SyncStatus.error, 'Server unreachable');
        _log('Server not reachable — skipping sync');
        return null;
      }


      await _ensureRemoteDirExists(client, _remotePath);


      final remoteList = await client.readDir(_remotePath);


      // ── Build local file map ─────────────────────────────────────────────
      final Map<String, File> localMap = {};


      if (localMusic != null && localMusic.isNotEmpty) {
        final snapshot = List<Music>.unmodifiable(localMusic);
        for (final track in snapshot) {
          localMap[p.basename(track.path)] = File(track.path);
        }
        _log('Snapshot of NPlayer songs: ${localMap.length} files');
      } else {
        final localDir = await _localMusicDir();
        final files    = await _listLocalAudioFiles(localDir);
        for (final f in files) {
          localMap[p.basename(f.path)] = f;
        }
        _log('Filesystem scan: ${localMap.length} files');
      }


      // ── Build remote file map ────────────────────────────────────────────
      final remoteMap = <String, webdav.File>{};
      for (final f in remoteList) {
        final name = f.name ?? '';
        if (name.isEmpty || f.isDir == true || !_isSupportedAudio(name)) continue;
        remoteMap[name] = f;
      }


      final toDownload = <RemoteFile>[];
      final toUpload   = <File>[];
      int   unchanged  = 0;


      // ── Remote → local ───────────────────────────────────────────────────
      for (final entry in remoteMap.entries) {
        final name   = entry.key;
        final remote = entry.value;
        final local  = localMap[name];


        if (local == null) {
          toDownload.add(_toRemoteFile(remote));
        } else {
          final remoteSize = remote.size?.toInt() ?? -1;
          if (remoteSize > 0) {
            final localSize = FileStat.statSync(local.path).size;
            if (localSize == remoteSize) {
              unchanged++;
            } else if (localSize < 0) {
              toDownload.add(_toRemoteFile(remote));
            } else {
              final remoteModified = remote.mTime ?? DateTime.now();
              final localModified  = FileStat.statSync(local.path).modified;
              if (remoteModified.isAfter(
                  localModified.add(const Duration(seconds: 60)))) {
                toDownload.add(_toRemoteFile(remote));
              } else {
                unchanged++;
              }
            }
          } else {
            final remoteModified = remote.mTime ?? DateTime.now();
            final localModified  = FileStat.statSync(local.path).modified;
            if (remoteModified.isAfter(
                localModified.add(const Duration(seconds: 60)))) {
              toDownload.add(_toRemoteFile(remote));
            } else {
              unchanged++;
            }
          }
        }
      }


      // ── Local → remote ───────────────────────────────────────────────────
      if (_uploadEnabled) {
        for (final entry in localMap.entries) {
          if (!remoteMap.containsKey(entry.key)) {
            toUpload.add(entry.value);
          }
        }
      }


      final diff = SyncDiff(
        toDownload:     toDownload,
        toUpload:       toUpload,
        unchangedCount: unchanged,
      );


      _pendingDiff = diff;


      if (diff.hasChanges) {
        _setStatus(SyncStatus.idle,
            '${diff.totalChanges} change(s) · ↓${toDownload.length} ↑${toUpload.length}');
      } else {
        _setStatus(SyncStatus.success,
            'Up to date · ${localMap.length} local · ${remoteMap.length} remote');
        _pendingDiff = null;
      }


      _log('Check done: ↓${toDownload.length} ↑${toUpload.length} '
          '=${unchanged} local=${localMap.length} remote=${remoteMap.length}');
      return diff;
    } catch (e, stack) {
      _lastError = e.toString();
      _setStatus(SyncStatus.error, 'Check failed: $e');
      _log('checkForChanges error: $e\n$stack');
      return null;
    }
  }


  // ─────────────────────────────────────────────────────────────────────────
  // MARK: - Apply Sync
  // ─────────────────────────────────────────────────────────────────────────


  Future<void> applySync({VoidCallback? onReloadNeeded}) async {
    final diff = _pendingDiff;
    if (diff == null || !diff.hasChanges) return;


    _cancelled = false;
    _activeCancelTokens.clear();


    // ── Pre-calculate total bytes for accurate progress ───────────────────
    int totalBytes = 0;
    for (final r in diff.toDownload) totalBytes += r.size;
    for (final f in diff.toUpload) {
      try { totalBytes += FileStat.statSync(f.path).size.clamp(0, 1 << 40); }
      catch (_) {}
    }


    _totalBytes       = totalBytes;
    _transferredBytes = 0;
    _syncStartTime    = DateTime.now();


    _setStatus(SyncStatus.syncing, 'Syncing…');
    _updateProgress(
      total:       diff.totalChanges,
      completed:   0,
      failed:      0,
      currentFile: 'Starting…',
    );


    final client   = _client ?? _buildClient();
    final dio      = _dio    ?? _buildDio();
    final localDir = await _localMusicDir();


    int completed = 0;
    int errors    = 0;


    // ── Downloads ─────────────────────────────────────────────────────────
    if (diff.toDownload.isNotEmpty) {
      await _runParallel(
        items: diff.toDownload,
        concurrency: _downloadConcurrency,
        task: (RemoteFile remote) async {
          if (_cancelled) return;


          _updateProgress(
            total:       diff.totalChanges,
            completed:   completed,
            failed:      errors,
            currentFile: '↓ ${remote.name}',
          );


          try {
            final localPath    = p.join(localDir.path, remote.name);
            final existingSize = FileStat.statSync(localPath).size;
            if (existingSize == remote.size && remote.size > 0) {
              _log('Skipped (already exists): ${remote.name}');
              _transferredBytes += remote.size;
              completed++;
              return;
            }


            int fileTransferred = 0;


            await client.read2File(
              _encodePath(remote.path),
              localPath,
              onProgress: (received, total) {
                if (_cancelled) return;
                final delta       = received - fileTransferred;
                fileTransferred   = received;
                _transferredBytes += delta;
                _throttledNotify();
              },
            );


            final written = FileStat.statSync(localPath).size;
            if (written <= 0) {
              await File(localPath).delete();
              throw Exception('Downloaded file is empty');
            }

            // Reconcile byte counter to exact file size.
            final shortfall = remote.size - fileTransferred;
            if (shortfall > 0) _transferredBytes += shortfall;

            completed++;
            _log('Downloaded: ${remote.name} ($written bytes)');
          } catch (e) {
            if (_cancelled) return;
            errors++;
            _log('Download failed for ${remote.name}: $e');
          }


          _updateProgress(
            total:       diff.totalChanges,
            completed:   completed,
            failed:      errors,
            currentFile: completed < diff.totalChanges ? '↓ processing…' : '',
          );
        },
      );
    }


    if (_cancelled) {
      _progress = null;
      _setStatus(SyncStatus.idle, 'Sync cancelled');
      return;
    }


    // ── Uploads ───────────────────────────────────────────────────────────
    // Strategy:
    //   • Small files  (< _chunkedThresholdBytes): single direct PUT via dio.
    //     A plain PUT avoids chunking overhead and is fastest for small files.
    //   • Large files  (>= _chunkedThresholdBytes): Nextcloud chunked upload
    //     API v2. Chunks are uploaded sequentially then assembled server-side.
    //     This matches what the official Nextcloud app does and saturates the
    //     uplink far better than a single-stream PUT.
    if (_uploadEnabled && diff.toUpload.isNotEmpty) {
      await _runParallel(
        items: diff.toUpload,
        concurrency: _uploadConcurrency,
        task: (File local) async {
          if (_cancelled) return;


          final name       = p.basename(local.path);
          final fileSize   = FileStat.statSync(local.path).size;
          final remoteDest = '$_remotePath/$name';


          _updateProgress(
            total:       diff.totalChanges,
            completed:   completed,
            failed:      errors,
            currentFile: '↑ $name',
          );


          try {
            final int fileStartBytes = _transferredBytes;


            if (fileSize >= _chunkedThresholdBytes) {
              // ── Chunked upload (large files) ───────────────────────────
              await _chunkedUpload(
                dio:             dio,
                file:            local,
                remoteDest:      remoteDest,
                fileSize:        fileSize,
                fileStartBytes:  fileStartBytes,
              );
            } else {
              // ── Direct PUT (small files) ───────────────────────────────
              await _directUpload(
                dio:            dio,
                file:           local,
                remoteDest:     remoteDest,
                fileSize:       fileSize,
                fileStartBytes: fileStartBytes,
              );
            }


            // Reconcile byte counter.
            final expected = fileStartBytes + fileSize;
            if (_transferredBytes < expected) _transferredBytes = expected;

            completed++;
            _log('Uploaded: $name ($fileSize bytes)');
          } catch (e) {
            if (_cancelled) return;
            errors++;
            _log('Upload failed for $name: $e');
          }


          _updateProgress(
            total:       diff.totalChanges,
            completed:   completed,
            failed:      errors,
            currentFile: completed < diff.totalChanges ? '↑ processing…' : '',
          );
        },
      );
    }


    if (_cancelled) {
      _progress = null;
      _setStatus(SyncStatus.idle, 'Sync cancelled');
      return;
    }


    // ── Finish ────────────────────────────────────────────────────────────
    _pendingDiff  = null;
    _progress     = null;
    _lastSyncTime = DateTime.now();
    _activeCancelTokens.clear();


    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        NextcloudKeys.lastSyncTime, _lastSyncTime!.millisecondsSinceEpoch);


    if (errors == 0) {
      _setStatus(SyncStatus.success,
          'Synced ${diff.toDownload.length}↓  ${diff.toUpload.length}↑');
    } else {
      _setStatus(SyncStatus.error,
          'Done with $errors error(s) — $completed succeeded');
    }


    if (diff.toDownload.isNotEmpty && onReloadNeeded != null) {
      onReloadNeeded();
    }
  }


  void dismissPendingDiff() {
    _pendingDiff = null;
    _setStatus(SyncStatus.idle, 'Sync skipped');
  }


  /// Convenience: check then immediately apply if changes exist.
  Future<void> manualSync({
    VoidCallback? onReloadNeeded,
    List<Music>?  localMusic,
  }) async {
    final diff = await checkForChanges(localMusic: localMusic);
    if (diff == null) return;
    if (diff.hasChanges) await applySync(onReloadNeeded: onReloadNeeded);
  }


  // ─────────────────────────────────────────────────────────────────────────
  // MARK: - Upload Strategies
  // ─────────────────────────────────────────────────────────────────────────


  /// Single-stream PUT upload for small files.
  /// Streams directly from disk — no readAsBytes(), no memory pressure.
  Future<void> _directUpload({
    required Dio    dio,
    required File   file,
    required String remoteDest,
    required int    fileSize,
    required int    fileStartBytes,
  }) async {
    final cancelToken = CancelToken();
    _activeCancelTokens.add(cancelToken);

    int sentSoFar = 0;

    try {
      final response = await dio.put(
        _encodedRelativePath(remoteDest),
        data: file.openRead(),
        cancelToken: cancelToken,
        options: Options(
          headers: {
            HttpHeaders.contentLengthHeader: fileSize,
            // Hint to Nextcloud that this is a complete, single-part upload.
            'OC-Total-Length': fileSize,
          },
        ),
        onSendProgress: (sent, total) {
          if (_cancelled) return;
          final delta       = sent - sentSoFar;
          sentSoFar         = sent;
          _transferredBytes += delta;
          _throttledNotify();
        },
      );

      _assertSuccessStatus(response.statusCode, 'PUT $remoteDest');
    } finally {
      _activeCancelTokens.remove(cancelToken);
    }
  }


  /// Nextcloud chunked upload API v2.
  ///
  /// Flow:
  ///   1. MKCOL  <uploads>/<uploadId>        (with Destination header)
  ///   2. PUT    <uploads>/<uploadId>/<N>     for each chunk (1-based index)
  ///   3. MOVE   <uploads>/<uploadId>/.file  → final destination
  ///
  /// The server assembles chunks in numerical order and deletes the temp
  /// directory. This is exactly what the official Nextcloud app does and
  /// allows the uplink to stay saturated with large files.
  Future<void> _chunkedUpload({
    required Dio    dio,
    required File   file,
    required String remoteDest,
    required int    fileSize,
    required int    fileStartBytes,
  }) async {
    final base       = _serverUrl.trimRight().replaceAll(RegExp(r'/$'), '');
    final uploadId   = 'blossom-${DateTime.now().millisecondsSinceEpoch}-'
                       '${file.path.hashCode.abs()}';
    final uploadBase = '$base/remote.php/dav/uploads/$_username/$uploadId';

    // Absolute destination for the Destination header.
    final absDestination =
        '$base/remote.php/dav/files/$_username${Uri.encodeFull(remoteDest)}';

    _log('Chunked upload start: ${p.basename(file.path)} '
         '(${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB) → $uploadId');

    // ── 1. Create upload directory ────────────────────────────────────────
    {
      final cancelToken = CancelToken();
      _activeCancelTokens.add(cancelToken);
      try {
        final response = await dio.request(
          uploadBase,
          cancelToken: cancelToken,
          options: Options(
            method:  'MKCOL',
            headers: {'Destination': absDestination},
          ),
        );
        // 201 Created or 405 Method Not Allowed (dir already exists) are fine.
        if (response.statusCode != 201 && response.statusCode != 405) {
          _assertSuccessStatus(response.statusCode, 'MKCOL $uploadBase');
        }
      } finally {
        _activeCancelTokens.remove(cancelToken);
      }
    }

    // ── 2. Upload chunks sequentially ────────────────────────────────────
    // Chunks are numbered 1..N (Nextcloud v2 requires numeric names 1–10000).
    final totalChunks = (fileSize / _chunkSize).ceil();

    for (int i = 0; i < totalChunks; i++) {
      if (_cancelled) {
        // Best-effort cleanup of the partial upload directory.
        _deleteUploadDir(dio, uploadBase).ignore();
        throw Exception('Cancelled during chunked upload');
      }

      final chunkStart = i * _chunkSize;
      final chunkEnd   = (chunkStart + _chunkSize).clamp(0, fileSize);
      final chunkIndex = i + 1; // 1-based
      final chunkBytes = chunkEnd - chunkStart;

      final cancelToken = CancelToken();
      _activeCancelTokens.add(cancelToken);

      int chunkSentSoFar = 0;

      try {
        final response = await dio.put(
          '$uploadBase/$chunkIndex',
          data: file.openRead(chunkStart, chunkEnd),
          cancelToken: cancelToken,
          options: Options(
            headers: {
              HttpHeaders.contentLengthHeader: chunkBytes,
              'Destination':    absDestination,
              'OC-Total-Length': fileSize,
            },
          ),
          onSendProgress: (sent, total) {
            if (_cancelled) return;
            final delta       = sent - chunkSentSoFar;
            chunkSentSoFar    = sent;
            _transferredBytes += delta;
            _throttledNotify();
          },
        );

        _assertSuccessStatus(response.statusCode,
            'PUT chunk $chunkIndex/$totalChunks of ${p.basename(file.path)}');
        _log('  chunk $chunkIndex/$totalChunks uploaded '
             '($chunkStart–$chunkEnd bytes)');
      } finally {
        _activeCancelTokens.remove(cancelToken);
      }
    }

    // ── 3. Assemble: MOVE .file → destination ────────────────────────────
    {
      final cancelToken = CancelToken();
      _activeCancelTokens.add(cancelToken);
      try {
        final response = await dio.request(
          '$uploadBase/.file',
          cancelToken: cancelToken,
          options: Options(
            method: 'MOVE',
            headers: {
              'Destination': absDestination,
              'Overwrite':   'T',
              'OC-Total-Length': fileSize,
              // Preserve the file's last-modified time on the server.
              'X-OC-Mtime': (file.lastModifiedSync().millisecondsSinceEpoch ~/ 1000)
                            .toString(),
            },
            // Assembly can take a few seconds for very large files.
            receiveTimeout: const Duration(minutes: 2),
          ),
        );
        _assertSuccessStatus(response.statusCode,
            'MOVE assemble ${p.basename(file.path)}');
        _log('Chunked upload assembled: ${p.basename(file.path)}');
      } finally {
        _activeCancelTokens.remove(cancelToken);
      }
    }
  }


  /// Best-effort DELETE of an in-progress upload directory (on cancel/error).
  Future<void> _deleteUploadDir(Dio dio, String uploadBase) async {
    try {
      await dio.delete(uploadBase);
      _log('Cleaned up upload dir: $uploadBase');
    } catch (e) {
      _log('Could not clean up upload dir $uploadBase: $e');
    }
  }


  /// Throws a descriptive exception for non-2xx/non-3xx status codes.
  void _assertSuccessStatus(int? statusCode, String context) {
    if (statusCode == null || (statusCode >= 400)) {
      throw Exception('HTTP $statusCode for $context');
    }
  }


  // ─────────────────────────────────────────────────────────────────────────
  // MARK: - Parallel Runner
  // ─────────────────────────────────────────────────────────────────────────


  Future<void> _runParallel<T>({
    required List<T> items,
    required int concurrency,
    required Future<void> Function(T item) task,
  }) async {
    for (int i = 0; i < items.length; i += concurrency) {
      if (_cancelled) return;
      final batch = items.skip(i).take(concurrency).toList();
      await Future.wait(batch.map(task));
    }
  }


  // ─────────────────────────────────────────────────────────────────────────
  // MARK: - Progress Helper
  // ─────────────────────────────────────────────────────────────────────────


void _updateProgress({
  required int    total,
  required int    completed,
  required int    failed,
  required String currentFile,
}) {
  final elapsed    = _syncStartTime != null
      ? DateTime.now().difference(_syncStartTime!)
      : Duration.zero;
  final elapsedSec = elapsed.inMilliseconds / 1000.0;
  final speedBps   = elapsedSec > 0.5 ? _transferredBytes / elapsedSec : 0.0;
  final remaining  = _totalBytes - _transferredBytes;
  final eta        = speedBps > 0
      ? Duration(seconds: (remaining / speedBps).round())
      : null;

  _progress = SyncProgress(
    total:            total,
    completed:        completed,
    failed:           failed,
    currentFile:      currentFile,
    totalBytes:       _totalBytes,
    transferredBytes: _transferredBytes,
    speedBps:         speedBps,
    eta:              eta,
  );

  _throttledNotify();
}


  // ─────────────────────────────────────────────────────────────────────────
  // MARK: - Remote Dir Helper
  // ─────────────────────────────────────────────────────────────────────────


  Future<void> _ensureRemoteDirExists(
      webdav.Client client, String path) async {
    try {
      await client.mkdir(path);
      _log('Created remote directory: $path');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('405') ||
          msg.contains('301') ||
          msg.contains('302') ||
          msg.contains('already exists')) {
        _log('Remote directory already exists: $path');
      } else if (e is SocketException || msg.contains('connection')) {
        rethrow;
      } else {
        rethrow;
      }
    }
  }


  // ─────────────────────────────────────────────────────────────────────────
  // MARK: - Local File System Helpers
  // ─────────────────────────────────────────────────────────────────────────


  Future<Directory> _localMusicDir() async {
    final dirPath = await Settings.getSongDir();
    final dir     = Directory(dirPath);
    if (!await dir.exists()) {
      try { await dir.create(recursive: true); } catch (e) {
        _log('Could not create music dir $dirPath: $e');
      }
    }
    return dir;
  }


  Future<List<File>> _listLocalAudioFiles(Directory dir) async {
    if (!await dir.exists()) {
      _log('Local music dir does not exist: ${dir.path}');
      return [];
    }
    try {
      final entities = await dir.list(recursive: false).toList();
      return entities
          .whereType<File>()
          .where((f) => _isSupportedAudio(p.basename(f.path)))
          .toList();
    } catch (e) {
      _log('Error scanning ${dir.path}: $e');
      return [];
    }
  }


  bool _isSupportedAudio(String filename) {
    final ext = p.extension(filename).toLowerCase();
    return SupportedFormats.supportedAudioFormats
        .any((fmt) => fmt['extension']!.toLowerCase() == ext);
  }


  RemoteFile _toRemoteFile(webdav.File f) {
    final name = f.name ?? '';
    return RemoteFile(
      path:        f.path ?? '$_remotePath/$name',
      name:        name,
      size:        f.size?.toInt() ?? 0,
      modified:    f.mTime ?? DateTime.now(),
      isDirectory: f.isDir ?? false,
    );
  }


  /// Percent-encode a full path (e.g. /Music/My Song.mp3) for use in
  /// webdav_client requests. Encodes each segment individually so slashes
  /// are preserved as path separators.
  String _encodePath(String path) =>
      path.split('/').map((seg) => Uri.encodeComponent(seg)).join('/');

  /// Returns a path relative to the Dio baseUrl (which already includes the
  /// /remote.php/dav/files/<user>/ prefix). Strips that prefix if present so
  /// Dio doesn't double-encode it, then percent-encodes each segment.
  String _encodedRelativePath(String remoteDest) {
    // remoteDest is like "/Music/filename.mp3" — Dio's baseUrl already ends
    // with the user prefix, so we just need the path relative to that root.
    // Strip a leading slash so it doesn't become an absolute URL override.
    final trimmed = remoteDest.startsWith('/') ? remoteDest.substring(1) : remoteDest;
    return trimmed.split('/').map(Uri.encodeComponent).join('/');
  }


  // ─────────────────────────────────────────────────────────────────────────
  // MARK: - Helpers
  // ────────────────────POST_NOTIFICATIONS─────────────────────────────────────────────────────


void _setStatus(SyncStatus status, String message) {
  _status        = status;
  _statusMessage = message;
  notifyListeners();
}


  void _log(String msg) {
    if (kDebugMode) print('[NextcloudSync] $msg');
  }
}
