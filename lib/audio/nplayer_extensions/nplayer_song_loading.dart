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
    _log("Reloading songs");
    _allSongs.clear();
    _playingSongs.clear();
    _currentSongIndex = null;
    await _loadSongs();
    sortSongs(); // Re-apply current sort
    _internalNotifyListeners();
  }
  
  /// Forces a complete cache refresh and reloads all songs
  /// 
  /// Clears the cache and re-processes all metadata.
  /// Use this after bulk file operations or if cache seems corrupted.
  Future<void> refreshCache() async {
    _log("Forcing cache refresh");
    await _songCache.clear();
    await reloadSongs();
  }
  
  /// Requests storage permission on Android/iOS platforms
  /// 
  /// Returns true if permission is granted, false otherwise.
  /// Always returns true on desktop platforms.
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      _log("Requesting storage permission");
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      _log("Storage permission ${status.isGranted ? 'granted' : 'denied'}");
      return status.isGranted;
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
      _log("Listing files from: $directoryPath");
      final directory = Directory(directoryPath);

      if (!await directory.exists()) {
        _log('Directory does not exist: $directoryPath');
        return [];
      }

      if (!await requestStoragePermission()) {
        _log('Storage permission denied');
        return [];
      }

      List<FileSystemEntity> files = await directory
          .list(recursive: true, followLinks: false)
          .toList();

      // Filter to include only supported audio formats
      files = files.where((file) {
        if (file is! File) return false;
        final extension = path.extension(file.path).toLowerCase();
        return extension == '.mp3' || 
               extension == '.flac' || 
               extension == '.m4a';
      }).toList();

      _log("Found ${files.length} audio files (.mp3, .flac, .m4a)");
      return files;
    } catch (e) {
      _log("Error while listing files: $e");
      return [];
    }
  }
  
  // ============================================================================
  // MARK: - Core Loading Logic
  // ============================================================================
  
  /// Main song loading method with integrated caching
  Future<void> _loadSongs() async {
    try {
      _log("Starting to load songs...");
      final loadStartTime = DateTime.now();
      
      // Initialize cache if not already done
      await _songCache.initialize();
      
      // **OPTIMIZATION: Load entire cache into memory at once**
      final cacheMap = await _songCache.loadAll();
      _log("Cache loaded with ${cacheMap.length} entries, starting file scan...");
      
      // Platform-specific initialization
      if (!Platform.isAndroid && !Platform.isIOS) {
        await iOS_Binder.getInitialCheck();
      }

      // Get configured music directories
      final List<Directory> directories = await Settings.getAllSongDirs();
      if (directories.isEmpty) {
        _log('No valid directories found');
        return;
      }
      
      _log("Scanning ${directories.length} directories");

      // Android-specific direct access test
      if (Platform.isAndroid) {
        await _testDirectAccess();
      }
      
      // Track all valid file paths for cache cleanup
      final Set<String> validPaths = {};
      
      // Track loaded song titles to prevent duplicate titles
      final Set<String> loadedTitles = {};
      
      int cacheHits = 0;
      int cacheMisses = 0;
      
      // Process directories with cache map
      for (var dir in directories) {
        final result = await _processDirectoryFast(dir, validPaths, loadedTitles, cacheMap);
        cacheHits += result['hits'] as int;
        cacheMisses += result['misses'] as int;
      }
      
      _log("Cache performance: $cacheHits hits, $cacheMisses misses (${(cacheHits / (cacheHits + cacheMisses) * 100).toStringAsFixed(1)}% hit rate)");
      
      // Clean up cache entries for files that no longer exist
      await _songCache.cleanInvalidEntries(validPaths);
      
      // Save cache after processing all files
      await _songCache.save();
      
      final totalTime = DateTime.now().difference(loadStartTime).inMilliseconds;
      _log("Finished loading ${_allSongs.length} songs in ${totalTime}ms (${((_allSongs.length / totalTime) * 1000).round()} songs/sec)");

      // Restore playlist associations for all loaded songs
      _restorePlaylistAssociations();

      // Load favorites from settings
      await _loadFavorites();
      
      // Apply current sorting and filtering
      _filterAndSortSongs();
      
      _internalNotifyListeners();
    } catch (e) {
      _log("Error loading songs: $e");
    }
  }

  /// Fast directory processing with in-memory cache
  Future<Map<String, int>> _processDirectoryFast(
    Directory directory,
    Set<String> validPaths,
    Set<String> loadedTitles,
    Map<String, CachedSongEntry> cacheMap,
  ) async {
    int hits = 0;
    int misses = 0;
    
    try {
      List<FileSystemEntity> entities = await directory
          .list(recursive: false)
          .toList();
      
      for (final entity in entities) {
        if (entity is File) {
          final extension = path.extension(entity.path).toLowerCase();
          if (_isSupportedAudioFormat(extension)) {
            final result = await _processAudioFileFast(entity, validPaths, loadedTitles, cacheMap);
            if (result) hits++; else misses++;
          }
        } else if (entity is Directory) {
          // Recursively process subdirectories
          final result = await _processDirectoryFast(entity, validPaths, loadedTitles, cacheMap);
          hits += result['hits'] as int;
          misses += result['misses'] as int;
        }
      }
    } catch (e) {
      _log("Error processing directory ${directory.path}: $e");
    }
    
    return {'hits': hits, 'misses': misses};
  }

  /// Fast file processing with in-memory cache lookup
  /// Returns true if cache hit, false if cache miss
  /// Fast file processing with in-memory cache lookup
/// Returns true if cache hit, false if cache miss
Future<bool> _processAudioFileFast(
  File file,
  Set<String> validPaths,
  Set<String> loadedTitles,
  Map<String, CachedSongEntry> cacheMap,
) async {
  try {
    final filePath = file.path;
    validPaths.add(filePath);
    
    // **KEY OPTIMIZATION: Check cache FIRST before calling stat()**
    final cachedEntry = cacheMap[filePath];
    
    if (cachedEntry != null) {
      // File is cached - load picture data separately (lazy)
      Uint8List? picture;
      try {
        picture = await _songCache.getPicture(filePath);
      } catch (e) {
        _log("Error loading picture for ${filePath}: $e");
        picture = null;
      }
      
      // Create music entry with separately-loaded picture
      final music = Music(
        path: cachedEntry.path,
        folderName: cachedEntry.folderName,
        lastModified: DateTime.fromMillisecondsSinceEpoch(cachedEntry.lastModified),
        title: cachedEntry.title,
        album: cachedEntry.album,
        artist: cachedEntry.artist,
        duration: cachedEntry.duration,
        picture: picture, // Loaded separately
        year: cachedEntry.year,
        genre: cachedEntry.genre,
        size: cachedEntry.fileSize,
        isFavorite: SongData.isFavorite(filePath),
      );
      
      if (!loadedTitles.contains(music.title)) {
        _allSongs.add(music);
        loadedTitles.add(music.title);
      }
      return true; // Cache hit
    }
    
    // Only call stat() if NOT in cache
    final fileStat = await file.stat();
    
    // Skip empty files
    if (fileStat.size <= 0) return false;
    
    // Process metadata and cache it (file was not cached)
    final music = await _processMetadata(file, fileStat);
    
    if (music != null && !loadedTitles.contains(music.title)) {
      _allSongs.add(music);
      loadedTitles.add(music.title);
    }
    
    return false; // Cache miss
  } catch (e) {
    _log('Error parsing file ${file.path}: $e');
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
      _log("Error processing metadata: $e");
      return null;
    }
  }
  
  // ============================================================================
  // MARK: - Helper Methods
  // ============================================================================
  
  /// Tests direct file access for Android custom directories
  Future<bool> _testDirectAccess() async {
    final String? customDir = Settings.customMusicDirectory;
    if (customDir == null || customDir.isEmpty) return false;
    
    try {
      final String testFilePath = path.join(customDir, 'Song.m4a');
      final File testFile = File(testFilePath);
      
      if (await testFile.exists()) {
        final Set<String> testValidPaths = {};
        final Set<String> testLoadedTitles = {};
        final Map<String, CachedSongEntry> emptyCache = {};
        await _processAudioFileFast(testFile, testValidPaths, testLoadedTitles, emptyCache);
        _log("Direct access test successful");
        return true;
      }
      
      _log("Test file not found: $testFilePath");
      return false;
    } catch (e) {
      _log("Error in direct file access test: $e");
      return false;
    }
  }
  
  /// Restores playlist associations for all loaded songs
  void _restorePlaylistAssociations() {
    for (var song in _allSongs) {
      song.playlists.clear();
      for (var playlist in playlists) {
        if (PlaylistManager.getPlaylistSongs(playlist).contains(song.title)) {
          song.playlists.add(playlist);
        }
      }
    }
    _log("Restored playlist associations for ${_allSongs.length} songs");
  }
  
  /// Checks if a file extension is a supported audio format
  bool _isSupportedAudioFormat(String extension) {
    return extension == '.mp3' || 
           extension == '.flac' || 
           extension == '.m4a';
  }
}
