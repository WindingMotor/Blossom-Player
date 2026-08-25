import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:blossom/audio/nplayer_extensions/song_cache.dart';
import 'package:blossom/tools/supported_formats.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:blossom/audio/nplaylist.dart';
import 'package:blossom/audio/nserver.dart';
import 'package:blossom/tools/settings.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:headset_connection_event/headset_event.dart';
import 'package:http/http.dart' as http;
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:blossom/audio/song_data.dart';
import 'package:blossom/audio/nplayer_extensions/nplayer_audio_handler.dart';
import 'package:blossom/tools/logger.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:blossom/audio/nplayer.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:image/image.dart' as img;

part 'nplayer_extensions/nplayer_sorting.dart';
part 'nplayer_extensions/nplayer_playback.dart';
part 'nplayer_extensions/nplayer_audio_controls.dart';
part 'nplayer_extensions/nplayer_playlist_management.dart';
part 'nplayer_extensions/nplayer_song_loading.dart';
part 'nplayer_extensions/nplayer_server.dart';
part 'nplayer_extensions/nplayer_song_utils.dart';
part 'nplayer_extensions/nplayer_public.dart';
part 'nplayer_extensions/nplayer_albums.dart';

/// Represents a music file with its metadata and associated playlists.
class Music {
  final String path;
  final String folderName;
  final DateTime lastModified;
  final String title;
  final String album;
  final String artist;
  final int duration;
  final Uint8List? picture;
  final String year;
  final String genre;
  final int size;
  List<String> playlists;
  bool isFavorite;

  Music({
    required this.path,
    required this.folderName,
    required this.lastModified,
    required this.title,
    required this.album,
    required this.artist,
    required this.duration,
    this.picture,
    required this.year,
    required this.genre,
    required this.size,
    List<String>? playlists,
    this.isFavorite = false,
  }) : playlists = playlists ?? [];

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      path: json['path'],
      folderName: json['folderName'],
      lastModified: DateTime.parse(json['lastModified']),
      title: json['title'],
      album: json['album'],
      artist: json['artist'],
      duration: json['duration'],
      picture: json['picture'] != null
          ? Uint8List.fromList(List<int>.from(json['picture']))
          : null,
      year: json['year'],
      genre: json['genre'],
      size: json['size'],
      playlists: List<String>.from(json['playlists'] ?? []),
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'folderName': folderName,
      'lastModified': lastModified.toIso8601String(),
      'title': title,
      'album': album,
      'artist': artist,
      'duration': duration,
      'picture': picture?.toList(),
      'year': year,
      'genre': genre,
      'size': size,
      'playlists': playlists,
      'isFavorite': isFavorite,
    };
  }

  void updatePlaylists(List<String> newPlaylists) {
    playlists = List.from(newPlaylists);
  }
}

enum PlaybackSourceType { library, album, artist, playlist }

class PlaybackSource {
  final PlaybackSourceType type;
  final String? name;

  const PlaybackSource(this.type, {this.name});

  bool get canOpen =>
      type == PlaybackSourceType.album || type == PlaybackSourceType.playlist;
}

/// Main class for managing music playback and related functionality.
class NPlayer extends ChangeNotifier {
  // MARK: Properties
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  CustomAudioHandler? _audioHandler;
  final Random _random = Random();
  final List<Music> _allSongs = [];
  List<Music> _sortedSongs = [];
  List<Music> _playingSongs = [];

  final SongCache _songCache = SongCache();
  SongCache get cache => _songCache;

  String _searchQuery = '';
  int? _currentSongIndex;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  String _repeatMode = Settings.repeatMode;
  String _sortBy = 'title';
  bool _sortAscending = true;

  bool _isPausing = false;
  bool _isResuming = false;
  bool _isStoppingInProgress = false;
  bool _isChangingSong = false;
  bool _isPausedByInterruption = false;

  List<String> get playlists => PlaylistManager.playlistNames;

  NServer? _server;
  NClient? _client;
  bool _isServerOn = false;

  Timer? _debounceTimer;
  final Duration _debounceDuration = Duration(milliseconds: 300);

  final HeadsetEvent _headsetPlugin = HeadsetEvent();
  bool _isHeadphonesConnected = false;

  Timer? _sleepTimer;
  Timer? _fadeTimer;
  Timer? _heartbeatTimer;
  int? _sleepTimerMinutes;
  Duration? _remainingTime;
  double? _originalVolume;
  static const fadeStartSeconds = 10;
  static const fadeUpdateInterval = 50;

  // Pre-shuffle queue snapshot for the 'reversible' shuffle behavior.
  List<Music>? _preShuffleQueue;

  Map<String, List<Music>> _albumMap = {};
  Map<String, List<Music>> _folderMap = {};
  PlaybackSource _playbackSource =
      const PlaybackSource(PlaybackSourceType.library);

  // MARK: Getters
  List<Music> get allSongs => _allSongs;
  List<Music> get playingSongs => _playingSongs;
  List<Music> get sortedSongs => _sortedSongs;
  int? get currentSongIndex => _currentSongIndex;
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  String get repeatMode => _repeatMode;
  double get volume => _audioPlayer.volume;
  String get searchQuery => _searchQuery;
  bool get isPausedByInterruption => _isPausedByInterruption;
  bool get isServerOn => _isServerOn;
  bool get isHeadphonesConnected => _isHeadphonesConnected;
  int? get sleepTimerMinutes => _sleepTimerMinutes;
  Duration? get remainingTime => _remainingTime;
  Map<String, List<Music>> get albumMap => _albumMap;
  Map<String, List<Music>> get folderMap => _folderMap;
  PlaybackSource get playbackSource => _playbackSource;

  /// True when the queue is shuffled and the original order can be restored
  /// (only meaningful with the 'reversible' shuffle behavior).
  bool get isShuffled => _preShuffleQueue != null;

  int _lastPositionSaveMs = 0;

  bool _isInitialized = false;
  bool _isDisposed = false;
  Completer<void>? _initializationCompleter;
  final List<StreamSubscription> _audioPlayerSubscriptions = [];

  Duration get duration {
    final song = getCurrentSong();
    return song != null ? Duration(milliseconds: song.duration) : Duration.zero;
  }

  Music? getCurrentSong() {
    if (_currentSongIndex == null ||
        _playingSongs.isEmpty ||
        _currentSongIndex! >= _playingSongs.length) {
      return null;
    }
    return _playingSongs[_currentSongIndex!];
  }

  // MARK: Constructor and Initialization
  // Helper to allow extensions to trigger notifyListeners correctly
  void _internalNotifyListeners() {
    notifyListeners();
  }

  NPlayer() {
    Log.i(LogTag.playback, 'Initializing NPlayer...');
    _initialize();
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    if (_initializationCompleter != null) {
      await _initializationCompleter!.future;
    }
  }

  Future<void> _initializeAudioHandler() async {
    try {
      _audioHandler = await audio_service.AudioService.init(
        builder: () => CustomAudioHandler(_audioPlayer, this),
        config: const audio_service.AudioServiceConfig(
          androidNotificationChannelId: 'com.wmstudios.blossom.audio',
          androidNotificationChannelName: 'Blossom Music Player',
          androidNotificationClickStartsActivity: true,
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: false,
          androidNotificationIcon: 'drawable/ic_notification',
          androidShowNotificationBadge: false,
          preloadArtwork: false,
          // Downscale album art bitmaps so the MediaSession parcel stays small
          // enough for Android Auto to receive without dropping it.
          artDownscaleWidth: 512,
          artDownscaleHeight: 512,
        ),
      );
      Log.i(LogTag.audioHandler, 'AudioHandler initialized successfully');
    } catch (e) {
      Log.e(LogTag.audioHandler, 'Error initializing AudioHandler: $e');
      _audioHandler = CustomAudioHandler(_audioPlayer, this);
      Log.w(LogTag.audioHandler, 'Fallback: created AudioHandler directly');
    }
  }

  Future<void> _initialize() async {
    if (_isInitialized || _initializationCompleter != null) return;
    _initializationCompleter = Completer<void>();

    try {
      // Configure AudioPlayer to delegate all audio focus to our AudioHandler
      try {
        await _audioPlayer.setAudioContext(ap.AudioContext(
          android: ap.AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: ap.AndroidContentType.music,
            usageType: ap.AndroidUsageType.media,
            audioFocus: ap.AndroidAudioFocus.none,
          ),
          iOS: ap.AudioContextIOS(
            category: ap.AVAudioSessionCategory.playback,
            options: {},
          ),
        ));
        Log.d(LogTag.playback, 'AudioContext configured');
      } catch (e) {
        Log.w(LogTag.playback, 'AudioContext config failed (continuing): $e');
      }

      // Initialize AudioHandler (owns all session config + focus requests)
      await _initializeAudioHandler();

      // Initialize synchronous components
      _setupAudioPlayerListeners();
      _initHeadsetDetection();
      _server = NServer(this);
      _client = NClient(this);

      // Initialize asynchronous components
      await _initializeFromSettings();

      await PlaylistManager.initialize();
      await PlaylistManager.load();

      await _loadSongs();
      await loadSortSettings();

      // Apply initial sort based on loaded settings
      sortSongs(sortBy: _sortBy, ascending: _sortAscending);

      // Restore the last playing song (paused) so playback can resume
      // where the user left off.
      await _restoreLastPlayingSession();

      // Initialize public sharing
      await _initializePublicSharing();

      _isInitialized = true;
      _initializationCompleter!.complete();
      Log.i(LogTag.playback, 'NPlayer initialization complete');
      notifyListeners();
    } catch (e) {
      Log.e(LogTag.playback, 'Error during initialization: $e');
      _initializationCompleter!.completeError(e);
      rethrow;
    }
  }

  Future<void> _initializeFromSettings() async {
    await setVolume(Settings.volume);
    _repeatMode = Settings.repeatMode;
    await _loadFavorites();
    Log.d(LogTag.playback,
        'Settings loaded: volume=${Settings.volume}, repeat=$_repeatMode');
  }

  void _setupAudioPlayerListeners() {
    _audioPlayerSubscriptions.add(
      _audioPlayer.onPlayerStateChanged.listen((state) {
        final isNowPlaying = state == ap.PlayerState.playing;
        if (_isPlaying != isNowPlaying) {
          _isPlaying = isNowPlaying;
          if (!_isDisposed) notifyListeners();
        }
      }),
    );

    _audioPlayerSubscriptions.add(
      _audioPlayer.onPositionChanged.listen((position) {
        _currentPosition = position;
        positionNotifier.value = position;
        // Do NOT call notifyListeners() here — it rebuilds the entire widget
        // tree at ~5 Hz and kills 120 Hz rendering.  The progress bar uses
        // ValueListenableBuilder on positionNotifier directly.
        // AudioHandler owns the throttled (1 Hz) MediaSession broadcast.

        // Persist position (throttled) so playback resumes mid-song after
        // an app restart.
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (nowMs - _lastPositionSaveMs >= 5000) {
          _lastPositionSaveMs = nowMs;
          Settings.setLastPlayingPosition(position.inMilliseconds);
        }
      }),
    );
    // onPlayerComplete is intentionally NOT subscribed here.
    // CustomAudioHandler owns all completion logic (guarded by _completionHandled
    // + backup timer).  A second listener here was the cause of double-skips.
  }

  Timer? _headsetDebounce;

  void _initHeadsetDetection() {
    if (!Platform.isLinux && !Platform.isWindows) {
      try {
        _headsetPlugin.getCurrentState.then((val) {
          if (_isDisposed) return;
          _isHeadphonesConnected = val == HeadsetState.CONNECT;
          notifyListeners();
        }).catchError((e) {
          // BLUETOOTH_CONNECT permission may be missing on older OS builds;
          // swallow so the app doesn't crash.
          Log.w(LogTag.playback, 'Error getting initial headset state: $e');
        });

        _headsetPlugin.setListener((val) {
          if (_isDisposed) return;
          // Debounce rapid BT connect/disconnect events to avoid
          // hammering the audio session during device pairing.
          _headsetDebounce?.cancel();
          _headsetDebounce = Timer(const Duration(milliseconds: 400), () {
            try {
              final wasConnected = _isHeadphonesConnected;
              _isHeadphonesConnected = val == HeadsetState.CONNECT;

              if (wasConnected && !_isHeadphonesConnected && _isPlaying) {
                Future.microtask(pauseSong);
              }
              if (!_isDisposed) notifyListeners();
            } catch (e) {
              Log.w(LogTag.playback, 'Error in headset listener: $e');
            }
          });
        });
      } catch (e) {
        Log.w(LogTag.playback, 'Error initializing headset detection: $e');
      }
    }
  }

  Future<Map<String, dynamic>> getCacheStats() async {
    return await _songCache.getStats();
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (final sub in _audioPlayerSubscriptions) {
      sub.cancel();
    }
    _audioPlayerSubscriptions.clear();
    _audioPlayer.dispose();
    positionNotifier.dispose();
    _debounceTimer?.cancel();
    _headsetDebounce?.cancel();
    _sleepTimer?.cancel();
    _fadeTimer?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}
