part of '../nplayer.dart';

/// Extension for song loading and management functionality in NPlayer
///
/// Handles:
/// - Song library loading with caching
/// - Directory scanning and file processing
/// - Metadata extraction and caching
/// - Storage permission management
extension NPlayerSongLoading on NPlayer {
  /// Completely reloads the song library from disk
  ///
  /// Clears all existing songs and rescans directories.
  /// Cache is still used for unchanged files.
  Future<void> reloadSongs() async {
    Log.i(LogTag.songLoading, 'Reloading songs from disk');
    _allSongs.clear();
    _playingSongs.clear();
    _currentSongIndex = null;
    await _loadSongs();
    buildAlbumMaps();
    sortSongs();
    _internalNotifyListeners();
  }

  /// Forces a complete cache refresh and reloads all songs
  ///
  /// Clears the cache and re-processes all metadata.
  /// Use this after bulk file operations or if cache seems corrupted.
  Future<void> refreshCache() async {
    Log.i(LogTag.songLoading, 'Forcing cache refresh');
    await _songCache.clear();
    await reloadSongs();
  }

  /// Requests storage permission on Android/iOS platforms
  ///
  /// Returns true if permission is granted, false otherwise.
  /// Always returns true on desktop platforms.
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      Log.d(LogTag.songLoading, 'Requesting storage permission');
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;
      final permission =
          sdkVersion >= 33 ? Permission.audio : Permission.storage;
      var status = await permission.status;
      if (!status.isGranted) {
        status = await permission.request();
      }
      if (status.isGranted) {
        Log.d(LogTag.songLoading, 'Media permission granted');
      } else {
        Log.w(LogTag.songLoading, 'Media permission denied');
      }
      return status.isGranted;
    }
    if (Platform.isIOS) {
      return true;
    }
    return true; // Always return true for desktop platforms
  }

  /// Lists all audio files in the configured music directory
  ///
  /// Returns a list of FileSystemEntity objects for .mp3, .flac, and .m4a files.
  /// Requires storage permission on Android/iOS.
  Future<List<FileSystemEntity>> listFiles() async {
    try {
      final directoryPath = await Settings.getSongDir();
      Log.d(LogTag.songLoading, 'Listing files from: $directoryPath');
      final directory = Directory(directoryPath);

      if (!await directory.exists()) {
        Log.w(LogTag.songLoading, 'Directory does not exist: $directoryPath');
        return [];
      }

      if (!await requestStoragePermission()) {
        Log.w(LogTag.songLoading, 'Storage permission denied');
        return [];
      }

      List<FileSystemEntity> files =
          await directory.list(recursive: true, followLinks: false).toList();

      // Filter using SupportedFormats
      files = files.where((file) {
        if (file is! File) return false;
        final extension = path.extension(file.path).toLowerCase();
        return _isSupportedAudioFormat(extension);
      }).toList();

      Log.d(LogTag.songLoading, 'Found ${files.length} audio files');
      return files;
    } catch (e) {
      Log.e(LogTag.songLoading, 'Error while listing files: $e');
      return [];
    }
  }

  // ============================================================================
  // MARK: - Core Loading Logic
  // ============================================================================

  Future<void> _loadSongs() async {
    try {
      Log.i(LogTag.songLoading, 'Starting song load...');
      final loadStartTime = DateTime.now();

      // 1. Initialize Cache Safely
      try {
        await _songCache.initialize();
      } catch (e) {
        Log.w(LogTag.songLoading, 'Cache init failed (continuing): $e');
      }

      final cacheMap = await _songCache.loadAll();
      Log.d(LogTag.songLoading, 'Cache: ${cacheMap.length} entries loaded');

      // 2. Get Directories
      final List<Directory> directories = await Settings.getAllSongDirs();
      if (directories.isEmpty) {
        Log.w(LogTag.songLoading, 'No valid directories found — stopping load');
        _internalNotifyListeners();
        return;
      }

      Log.d(LogTag.songLoading, 'Scanning ${directories.length} directories');

      // 3. Process Directories with TIMEOUT safety
      final Set<String> validPaths = {};
      final Set<String> loadedPaths = {};
      int cacheHits = 0;
      int cacheMisses = 0;

      // SAFETY: Limit total scan time to avoid freezing on huge/slow storage
      final scanDeadline = DateTime.now().add(const Duration(seconds: 15));
      bool scanTimedOut = false;

      for (var dir in directories) {
        if (DateTime.now().isAfter(scanDeadline)) {
          scanTimedOut = true;
          break;
        }

        final result = await _processDirectoryFast(
            dir, validPaths, loadedPaths, cacheMap, scanDeadline);
        cacheHits += result['hits'] as int;
        cacheMisses += result['misses'] as int;
        if (result['timedOut'] == 1) scanTimedOut = true;
      }

      if (scanTimedOut) {
        Log.w(LogTag.songLoading,
            'Scan timed out after 15s — library may be incomplete (${_allSongs.length} songs loaded so far)');
      }

      Log.d(LogTag.songLoading, 'Cache: $cacheHits hits, $cacheMisses misses');

      // 4. Clean Cache — but never against a partial scan, or entries for
      // files we simply didn't reach would be evicted.
      if (validPaths.isNotEmpty && !scanTimedOut) {
        await _songCache.cleanInvalidEntries(validPaths);
        await _songCache.save();
      } else if (validPaths.isNotEmpty) {
        await _songCache.save();
      }

      final totalTime = DateTime.now().difference(loadStartTime).inMilliseconds;
      Log.i(LogTag.songLoading,
          'Loaded ${_allSongs.length} songs in ${totalTime}ms');

      // 5. Restore & Notify
      _restorePlaylistAssociations();
      await _loadFavorites();
      _filterAndSortSongs();
      buildAlbumMaps();

      _internalNotifyListeners(); // CRITICAL: Updates the UI to remove loading spinner!
    } catch (e, stack) {
      Log.e(LogTag.songLoading, 'Critical error loading songs: $e', stack);
      _internalNotifyListeners();
    }
  }

  /// Fast directory processing with in-memory cache.
  /// Honors [deadline] at every level of the recursion so the 15s scan cap
  /// works even when everything lives under a single deep directory tree.
  Future<Map<String, int>> _processDirectoryFast(
    Directory directory,
    Set<String> validPaths,
    Set<String> loadedPaths,
    Map<String, CachedSongEntry> cacheMap,
    DateTime deadline,
  ) async {
    int hits = 0;
    int misses = 0;
    int timedOut = 0;

    try {
      List<FileSystemEntity> entities =
          await directory.list(recursive: false).toList();

      for (final entity in entities) {
        if (DateTime.now().isAfter(deadline)) {
          timedOut = 1;
          break;
        }
        if (entity is File) {
          final extension = path.extension(entity.path).toLowerCase();
          if (_isSupportedAudioFormat(extension)) {
            final result = await _processAudioFileFast(
                entity, validPaths, loadedPaths, cacheMap);
            if (result)
              hits++;
            else
              misses++;
          }
        } else if (entity is Directory) {
          // Recursively process subdirectories
          final result = await _processDirectoryFast(
              entity, validPaths, loadedPaths, cacheMap, deadline);
          hits += result['hits'] as int;
          misses += result['misses'] as int;
          if (result['timedOut'] == 1) {
            timedOut = 1;
            break;
          }
        }
      }
    } catch (e) {
      Log.w(LogTag.songLoading,
          'Error processing directory ${directory.path}: $e');
    }

    return {'hits': hits, 'misses': misses, 'timedOut': timedOut};
  }

  /// Fast file processing with in-memory cache lookup
  /// Returns true if cache hit, false if cache miss
  Future<bool> _processAudioFileFast(
    File file,
    Set<String> validPaths,
    Set<String> loadedPaths,
    Map<String, CachedSongEntry> cacheMap,
  ) async {
    try {
      final filePath = file.path;
      validPaths.add(filePath);

      // Skip files already loaded (deduplicate by path, not title)
      if (loadedPaths.contains(filePath)) return true;

      // Always stat the file: cheap (kernel-cached inode) and needed to
      // detect changes (e.g. Nextcloud re-downloads update mtime/size).
      final fileStat = await file.stat();

      final cachedEntry = cacheMap[filePath];

      if (cachedEntry != null &&
          fileStat.modified.millisecondsSinceEpoch ==
              cachedEntry.lastModified &&
          fileStat.size == cachedEntry.fileSize) {
        // Cache is valid — file unchanged since last scan.
        Uint8List? picture;
        try {
          picture = await _songCache.getPicture(filePath);
        } catch (e) {
          Log.w(LogTag.songLoading, 'Error loading picture for $filePath: $e');
          picture = null;
        }

        final music = Music(
          path: cachedEntry.path,
          folderName: cachedEntry.folderName,
          lastModified: fileStat.modified,
          title: cachedEntry.title,
          album: cachedEntry.album,
          artist: cachedEntry.artist,
          duration: cachedEntry.duration,
          picture: picture,
          year: cachedEntry.year,
          genre: cachedEntry.genre,
          size: cachedEntry.fileSize,
          isFavorite: SongData.isFavorite(filePath),
        );

        _allSongs.add(music);
        loadedPaths.add(filePath);
        return true; // Cache hit
      }

      // Cache miss or stale entry — re-read metadata.

      // Skip empty files
      if (fileStat.size <= 0) return false;

      // Process metadata and cache it (file was not cached)
      final music = await _processMetadata(file, fileStat);

      if (music != null) {
        _allSongs.add(music);
        loadedPaths.add(filePath);
      }

      return false; // Cache miss
    } catch (e) {
      Log.w(LogTag.songLoading, 'Error parsing ${file.path}: $e');
      return false;
    }
  }

  Future<Music?> _processMetadata(File file, FileStat fileStat) async {
    try {
      final metadata = await MetadataGod.readMetadata(file: file.path);
      final title = metadata.title ?? path.basenameWithoutExtension(file.path);

      final music = Music(
        path: file.path,
        folderName: path.basename(path.dirname(file.path)),
        lastModified: fileStat.modified,
        title: title,
        album: metadata.album ?? 'Unknown Album',
        artist: metadata.artist ?? 'Unknown Artist',
        duration: metadata.durationMs?.round() ?? 0,
        picture: metadata.picture?.data,
        year: metadata.year?.toString() ?? '',
        genre: metadata.genre ?? 'Unknown Genre',
        size: fileStat.size,
        isFavorite: SongData.isFavorite(file.path),
      );

      // Cache the newly processed song
      await _songCache.put(file.path, CachedSongEntry.fromMusic(music));

      return music;
    } catch (e) {
      Log.w(LogTag.songLoading, 'Error processing metadata: $e');
      return null;
    }
  }

  // ============================================================================
  // MARK: - Helper Methods
  // ============================================================================

  /// Restores playlist associations for all loaded songs
  void _restorePlaylistAssociations() {
    for (var song in _allSongs) {
      song.playlists.clear();
      for (var playlist in playlists) {
        final playlistSongIds = PlaylistManager.getPlaylistSongs(playlist);
        if (playlistSongIds.contains(song.path) ||
            playlistSongIds.contains(song.title)) {
          song.playlists.add(playlist);
        }
      }
    }
    Log.d(LogTag.songLoading,
        'Restored playlist associations for ${_allSongs.length} songs');
  }

  bool _isSupportedAudioFormat(String extension) {
    // Remove leading dot if present for comparison
    final cleanExt = extension.startsWith('.') ? extension : '.$extension';

    return SupportedFormats.supportedAudioFormats.any((format) {
      final matchesExtension =
          format['extension']!.toLowerCase() == cleanExt.toLowerCase();
      final platformMatch = format['platform'] == 'ALL' ||
          (Platform.isAndroid && format['platform'] == 'ANDROID') ||
          (Platform.isIOS && format['platform'] == 'IOS');
      return matchesExtension && platformMatch;
    });
  }
}
