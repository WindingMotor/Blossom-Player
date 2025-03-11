part of '../nplayer.dart';

extension NPlayerSongLoading on NPlayer {
  // MARK: Song Loading and Management
  Future<void> reloadSongs() async {
  _log("Reloading songs");
  _allSongs.clear();
  _playingSongs.clear();
  _currentSongIndex = null;
  await _loadSongs();
  sortSongs(); // Re-apply current sort
  _internalNotifyListeners();
}

Future<void> _loadSongs() async {
  try {
    _log("Starting to load songs...");
    
    if (!Platform.isAndroid && !Platform.isIOS) {
      await iOS_Binder.getInitialCheck();
    }

    final List<Directory> directories = await Settings.getAllSongDirs();
    if (directories.isEmpty) {
      _log('No valid directories found');
      return;
    }

    if (Platform.isAndroid) {
      await _testDirectAccess();
    }
    
    _log("Starting to scan ${directories.length} directories for music files");
    bool timedOut = false;
    await Future.any([
      _processAllDirectories(directories),
      Future.delayed(const Duration(seconds: 30), () {
        timedOut = true;
      })
    ]);
    
    if (timedOut) {
      _log("Warning: Scan timed out.");
    }
    
    _log("Finished loading songs. Total songs: ${_allSongs.length}");

    for (var song in _allSongs) {
      song.playlists.clear();
      for (var playlist in playlists) {
        if (PlaylistManager.getPlaylistSongs(playlist).contains(song.title)) {
          song.playlists.add(playlist);
        }
      }
    }

    await _loadFavorites();
    _filterAndSortSongs();
    _internalNotifyListeners();
  } catch (e) {
    _log("Error loading songs: $e");
  }
}

Future<void> _processAllDirectories(List<Directory> directories) async {
  for (var dir in directories) {
    await _processDirectory(dir);
  }
}

Future<bool> _testDirectAccess() async {
  final String? customDir = Settings.customMusicDirectory;
  if (customDir == null || customDir.isEmpty) return false;
  try {
    final String testFilePath = path.join(customDir, 'Song.m4a');
    final File testFile = File(testFilePath);
    if (await testFile.exists()) {
      await _processAudioFile(testFile);
      return true;
    }
    return false;
  } catch (e) {
    _log("Error in direct file access test: $e");
    return false;
  }
}

Future<void> _processDirectory(Directory directory) async {
  try {
    List<FileSystemEntity> entities = await directory.list(recursive: false).toList();
    for (final entity in entities) {
      if (entity is File) {
        final extension = path.extension(entity.path).toLowerCase();
        if (extension == '.mp3' || extension == '.flac' || extension == '.m4a') {
          await _processAudioFile(entity);
        }
      } else if (entity is Directory) {
        await _processDirectory(entity);
      }
    }
  } catch (e) {
    _log("Error processing directory ${directory.path}: $e");
  }
}

Future<void> _processAudioFile(File file) async {
  try {
    if (await file.length() <= 0) return;
    
    final metadata = await MetadataGod.readMetadata(file: file.path);
    String title = metadata.title ?? path.basenameWithoutExtension(file.path);

    if (_allSongs.any((song) => song.title == title)) return;

    FileStat fileStat = await file.stat();
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
    _allSongs.add(music);
  } catch (e) {
    _log('Error parsing file ${file.path}: $e');
  }
}

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

    List<FileSystemEntity> files =
        await directory.list(recursive: true, followLinks: false).toList();

    // Filter to include only .mp3 and .flac files
    files = files
        .where((file) =>
            file is File &&
            (path.extension(file.path).toLowerCase() == '.mp3' ||
                path.extension(file.path).toLowerCase() == '.flac' ||
                path.extension(file.path).toLowerCase() == '.m4a'))
        .toList();

    _log("Found ${files.length} .mp3, .flac and .m4a files");
    return files;
  } catch (e) {
    _log("Error while listing files: $e");
    return [];
  }
}
}
