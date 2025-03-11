/// Settings Management System
/// Handles persistent storage and retrieval of application settings
/// Uses SharedPreferences for data persistence

import 'dart:io';
import 'dart:typed_data';
import 'package:blossom/audio/song_data.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;

/// Keys used for storing settings
/// Centralizes all setting keys to avoid typos and make maintenance easier
class SettingsKeys {
  // Theme related keys
  static const String themeMode = 'themeMode';
  static const String appTheme = 'appTheme';
  
  // Playback related keys
  static const String volume = 'volume';
  static const String lastPlayingSong = 'lastPlayingSong';
  static const String repeatMode = 'repeatMode';
  static const String previousForShuffle = 'previousForShuffle';
  static const String showConfetti = 'showConfetti';
  
  // Library sort keys
  static const String songSortBy = 'songSortBy';
  static const String songSortAscending = 'songSortAscending';
  static const String artistSortBy = 'artistSortBy';
  static const String artistSortAscending = 'artistSortAscending';
  static const String albumSortBy = 'albumSortBy';
  static const String albumSortAscending = 'albumSortAscending';
  static const String albumOrganizeByFolder = 'albumOrganizeByFolder';
  
  // UI related keys
  static const String hasSeenWelcomePage = 'hasSeenWelcomePage';
  
  // Custom directory key
  static const String userSelectedMusicDir = 'userSelectedMusicDir';
  
  // New debug key
  static const String debugMode = 'debugMode';
}

/// Manages application settings and preferences
class Settings {
  static late SharedPreferences _prefs;
  static bool _hasAndroidPermissions = false;
  static bool _debugMode = false;
  
  /// Initialize settings system
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await SongData.init();
    
    // Set debug mode
    _debugMode = _prefs.getBool(SettingsKeys.debugMode) ?? true;
    
    // Migrate existing favorites if needed
    if (_prefs.containsKey('favoriteSongs')) {
      final oldFavorites = _prefs.getStringList('favoriteSongs') ?? [];
      for (final song in oldFavorites) {
        await SongData.setFavorite(song, true);
      }
      await _prefs.remove('favoriteSongs');
    }
    
    // Request permissions right away
    if (Platform.isAndroid) {
      _hasAndroidPermissions = await _requestAndroidPermissions();
      _log("Android permissions granted: $_hasAndroidPermissions");
    }
  }
  
  /// Helper function for logging
  static void _log(String message) {
    if (_debugMode) {
      print("[Settings] $message");
    }
  }
  
  /// Enable or disable debug mode
  static Future<void> setDebugMode(bool enabled) async {
    _debugMode = enabled;
    await _prefs.setBool(SettingsKeys.debugMode, enabled);
  }
  
  /// Request Android permissions and return success status
  static Future<bool> _requestAndroidPermissions() async {
    try {
      // Get device info to check Android version
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      final int sdkVersion = androidInfo.version.sdkInt;
      
      _log("Android SDK version: $sdkVersion");
      
      if (sdkVersion >= 33) { // Android 13+
        // Request granular media permissions for Android 13+
        final status = await Permission.audio.request();
        _log("Audio permission status: ${status.toString()}");
        return status.isGranted;
      } else if (sdkVersion >= 30) { // Android 11-12
        // For Android 11-12, need both storage and media audio
        final storageStatus = await Permission.storage.request();
        final audioStatus = await Permission.audio.request();
        _log("Storage permission: ${storageStatus.toString()}");
        _log("Audio permission: ${audioStatus.toString()}");
        
        return storageStatus.isGranted || audioStatus.isGranted;
      } else { // Android 10 and below
        final status = await Permission.storage.request();
        _log("Storage permission: ${status.toString()}");
        return status.isGranted;
      }
    } catch (e) {
      _log("Error requesting Android permissions: $e");
      // Try fallback with storage permission
      try {
        final status = await Permission.storage.request();
        return status.isGranted;
      } catch (fallbackError) {
        _log("Fallback permission request also failed: $fallbackError");
        return false;
      }
    }
  }

  ///***************************************************************************
  /// Favorites Settings
  ///***************************************************************************
  
  /// Get list of favorite song paths
  static List<String> get favoriteSongs => SongData.getFavoriteSongs();

  /// Set list of favorite song paths
  static Future<void> setFavoriteSongs(List<String> paths) async {
    for (final path in paths) {
      await SongData.setFavorite(path, true);
    }
  }

  /// Add a song to favorites
  static Future<void> addFavorite(String path) async {
    await SongData.setFavorite(path, true);
  }

  /// Remove a song from favorites
  static Future<void> removeFavorite(String path) async {
    await SongData.setFavorite(path, false);
  }

  ///***************************************************************************
  /// Theme Settings
  ///***************************************************************************
  
  /// Get current theme mode (system, light, dark)
  static String get themeMode => _prefs.getString(SettingsKeys.themeMode) ?? 'system';
  
  /// Set theme mode
  static Future<void> setThemeMode(String mode) =>
      _prefs.setString(SettingsKeys.themeMode, mode);
  
  /// Get current app theme
  static String get appTheme => _prefs.getString(SettingsKeys.appTheme) ?? 'system';
  
  /// Set app theme
  static Future<void> setAppTheme(String theme) =>
      _prefs.setString(SettingsKeys.appTheme, theme);

  ///***************************************************************************
  /// Playback Settings
  ///***************************************************************************
  
  /// Default volume value
  static const double _defaultVolume = 1.0;
  
  /// Get current volume
  static double get volume => _prefs.getDouble(SettingsKeys.volume) ?? _defaultVolume;
  
  /// Set volume
  static Future<void> setVolume(double vol) => 
      _prefs.setDouble(SettingsKeys.volume, vol);
  
  /// Get last playing song
  static String? get lastPlayingSong => 
      _prefs.getString(SettingsKeys.lastPlayingSong);
  
  /// Set last playing song
  static Future<void> setLastPlayingSong(String? song) {
    _log('Last playing song: $song');
    return _prefs.setString(SettingsKeys.lastPlayingSong, song ?? '');
  }
  
  /// Get repeat mode
  static String get repeatMode => 
      _prefs.getString(SettingsKeys.repeatMode) ?? 'off';
  
  /// Set repeat mode
  static Future<void> setRepeatMode(String mode) =>
      _prefs.setString(SettingsKeys.repeatMode, mode);
  
  /// Get previous for shuffle setting
  static bool get previousForShuffle => 
      _prefs.getBool(SettingsKeys.previousForShuffle) ?? false;
  
  /// Set previous for shuffle setting
  static Future<void> setPreviousForShuffle(bool enabled) => 
      _prefs.setBool(SettingsKeys.previousForShuffle, enabled);

  /// Get show confetti setting
  static bool get showConfetti => _prefs.getBool(SettingsKeys.showConfetti) ?? false;

  /// Set show confetti setting
  static Future<void> setShowConfetti(bool value) async {
    await _prefs.setBool(SettingsKeys.showConfetti, value);
  }

  ///***************************************************************************
  /// Library Sort Settings
  ///***************************************************************************
  
  /// Song sort settings
  static String get songSortBy => 
      _prefs.getString(SettingsKeys.songSortBy) ?? 'title';
  static bool get songSortAscending => 
      _prefs.getBool(SettingsKeys.songSortAscending) ?? true;
  static Future<void> setLibrarySongSort(String sortBy, bool ascending) async {
    await _prefs.setString(SettingsKeys.songSortBy, sortBy);
    await _prefs.setBool(SettingsKeys.songSortAscending, ascending);
  }

  /// Artist sort settings
  static String get artistSortBy => 
      _prefs.getString(SettingsKeys.artistSortBy) ?? 'name';
  static bool get artistSortAscending =>
      _prefs.getBool(SettingsKeys.artistSortAscending) ?? true;
  static Future<void> setArtistSort(String sortBy, bool ascending) async {
    await _prefs.setString(SettingsKeys.artistSortBy, sortBy);
    await _prefs.setBool(SettingsKeys.artistSortAscending, ascending);
  }

  /// Album sort settings
  static String get albumSortBy {
    String sortBy = _prefs.getString(SettingsKeys.albumSortBy) ?? 'name';
    if (!['name', 'year', 'artist', 'folder'].contains(sortBy)) {
      sortBy = 'name'; // Default to 'name' if invalid value is stored
    }
    return sortBy;
  }
  static bool get albumSortAscending =>
      _prefs.getBool(SettingsKeys.albumSortAscending) ?? true;
  static bool get albumOrganizeByFolder =>
      _prefs.getBool(SettingsKeys.albumOrganizeByFolder) ?? false;
  static Future<void> setAlbumSort(
      String sortBy, bool ascending, bool organizeByFolder) async {
    if (['name', 'year', 'artist', 'folder'].contains(sortBy)) {
      await _prefs.setString(SettingsKeys.albumSortBy, sortBy);
    } else {
      await _prefs.setString(SettingsKeys.albumSortBy, 'name');
    }
    await _prefs.setBool(SettingsKeys.albumSortAscending, ascending);
    await _prefs.setBool(SettingsKeys.albumOrganizeByFolder, organizeByFolder);
  }

  ///***************************************************************************
  /// Custom Music Directory Settings
  ///***************************************************************************
  
  /// Get user-selected music directory (returns null if not set)
  static String? get customMusicDirectory => 
      _prefs.getString(SettingsKeys.userSelectedMusicDir);
  
  /// Set user-selected music directory
  static Future<void> setCustomMusicDirectory(String path) => 
      _prefs.setString(SettingsKeys.userSelectedMusicDir, path);
  
  /// Clear user-selected music directory
  static Future<void> clearCustomMusicDirectory() => 
      _prefs.remove(SettingsKeys.userSelectedMusicDir);

  ///***************************************************************************
  /// File System Settings
  ///***************************************************************************

  /// Test direct file access to verify permissions
  static Future<bool> testDirectFileAccess(String testPath) async {
    try {
      final String fullPath = path.join(testPath, 'Song.m4a');
      _log("Testing direct file access to: $fullPath");
      
      // Check if the file exists
      final File testFile = File(fullPath);
      final bool exists = await testFile.exists();
      _log("File exists: $exists");
      
      if (exists) {
        // Try to read file length
        final int length = await testFile.length();
        _log("File length: $length bytes");
        
        // Try to read a small chunk of the file
        final RandomAccessFile reader = await testFile.open(mode: FileMode.read);
        final Uint8List bytes = await reader.read(1024);
        await reader.close();
        
        _log("Successfully read ${bytes.length} bytes from file");
        return true;
      } else {
        _log("Test file not found at specified path");
        return false;
      }
    } catch (e) {
      _log("Error accessing test file: $e");
      return false;
    }
  }

  /// Validates if the directory exists and is accessible
  static Future<bool> isDirectoryAccessible(Directory directory) async {
    try {
      _log("Testing directory access: ${directory.path}");
      final bool exists = await directory.exists();
      _log("Directory exists: $exists");
      
      if (exists) {
        // Try to list directory contents
        try {
          final List<FileSystemEntity> entities = await directory.list().take(5).toList();
          _log("Successfully listed ${entities.length} items in directory");
          
          // Log first few items
          for (var entity in entities) {
            _log(" - ${entity.path} (${entity is File ? 'File' : 'Directory'})");
          }
          return true;
        } catch (listError) {
          _log("Error listing directory contents: $listError");
          return false;
        }
      } else {
        // Try to create the directory
        try {
          await directory.create(recursive: true);
          _log("Created directory successfully");
          return true;
        } catch (createError) {
          _log("Failed to create directory: $createError");
          return false;
        }
      }
    } catch (e) {
      _log("General error checking directory: $e");
      return false;
    }
  }

  /// Get all directories where songs might be stored
  static Future<List<Directory>> getAllSongDirs() async {
    List<Directory> directories = [];
    
    if (Platform.isAndroid) {
      _log("Getting Android song directories");
      
      // Check for user-selected directory first
      final String? customDir = customMusicDirectory;
      if (customDir != null && customDir.isNotEmpty) {
        final dir = Directory(customDir);
        
        // Validate directory access
        if (await isDirectoryAccessible(dir)) {
          directories.add(dir);
          _log("Using custom music directory: $customDir");
          
          // Test direct file access
          if (await testDirectFileAccess(customDir)) {
            _log("Direct file access to test file successful");
          } else {
            _log("Direct file access test failed");
          }
        } else {
          _log("Custom directory isn't accessible: $customDir");
        }
      } else {
        _log("No custom directory set, using default locations");
      }
      
      // If no custom directory or it failed, use defaults
      if (directories.isEmpty) {
        // Common Android music directories as fallback
        final List<String> commonPaths = [
          '/storage/emulated/0/Music',
          '/sdcard/Music',
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Documents/Music'
        ];
        
        for (String path in commonPaths) {
          final dir = Directory(path);
          if (await isDirectoryAccessible(dir)) {
            directories.add(dir);
            _log("Added default directory: $path");
          } else {
            _log("Default directory not accessible: $path");
          }
        }
      }
      
      // Also include app's documents directory for backward compatibility
      try {
        final appDir = await getApplicationDocumentsDirectory();
        _log("App documents directory: ${appDir.path}");
        if (await isDirectoryAccessible(Directory(appDir.path))) {
          directories.add(Directory(appDir.path));
        }
      } catch (e) {
        _log("Error getting app documents directory: $e");
      }
      
    } else if (Platform.isIOS) {
      // iOS uses application documents directory
      try {
        final directory = await getApplicationDocumentsDirectory();
        directories.add(Directory(directory.path));
        _log("iOS using documents directory: ${directory.path}");
      } catch (e) {
        _log("Error getting iOS documents directory: $e");
      }
      
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop platforms use BlossomMedia folder in documents
      try {
        final directory = await getApplicationDocumentsDirectory();
        final blossomMediaDir = Directory('${directory.path}/BlossomMedia');
        if (!await blossomMediaDir.exists()) {
          await blossomMediaDir.create(recursive: true);
        }
        directories.add(blossomMediaDir);
        _log("Desktop using BlossomMedia directory: ${blossomMediaDir.path}");
      } catch (e) {
        _log("Error setting up desktop directory: $e");
      }
    }
    
    _log("Final directories list (${directories.length} directories):");
    for (var dir in directories) {
      _log(" - ${dir.path}");
    }
    
    return directories;
  }

  /// Get the primary directory where songs are stored (for backward compatibility)
  static Future<String> getSongDir() async {
    if (Platform.isAndroid) {
      _log("Getting primary Android song directory");
      
      // Check for user-selected directory first
      final String? customDir = customMusicDirectory;
      if (customDir != null && customDir.isNotEmpty) {
        final dir = Directory(customDir);
        if (await isDirectoryAccessible(dir)) {
          _log("Using custom music directory as primary: $customDir");
          return customDir;
        } else {
          _log("Custom directory not accessible, falling back to defaults");
        }
      }
      
      // For Android, prefer the standard Music directory if it exists
      final musicDir = Directory('/storage/emulated/0/Music');
      if (await isDirectoryAccessible(musicDir)) {
        _log("Using /storage/emulated/0/Music as primary");
        return musicDir.path;
      }
      
      // Fallback to /sdcard/Music
      final sdcardMusic = Directory('/sdcard/Music');
      if (await isDirectoryAccessible(sdcardMusic)) {
        _log("Using /sdcard/Music as primary");
        return sdcardMusic.path;
      }
      
      // If neither exists, use app's documents directory
      try {
        final directory = await getApplicationDocumentsDirectory();
        _log("Using app documents as primary: ${directory.path}");
        return directory.path;
      } catch (e) {
        _log("Error getting documents directory: $e");
        return '/storage/emulated/0/Music'; // Last resort
      }
      
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop platforms use BlossomMedia folder in documents
      try {
        final directory = await getApplicationDocumentsDirectory();
        final blossomMediaDir = Directory('${directory.path}/BlossomMedia');
        if (!await blossomMediaDir.exists()) {
          await blossomMediaDir.create(recursive: true);
        }
        _log("Desktop primary: ${blossomMediaDir.path}");
        return blossomMediaDir.path;
      } catch (e) {
        _log("Error with desktop directory: $e");
        final directory = await getApplicationDocumentsDirectory();
        return directory.path;
      }
    } else {
      // iOS uses application documents directory
      try {
        final directory = await getApplicationDocumentsDirectory();
        _log("iOS primary: ${directory.path}");
        return directory.path;
      } catch (e) {
        _log("Error with iOS directory: $e");
        return '';
      }
    }
  }

  ///***************************************************************************
  /// UI Settings
  ///***************************************************************************
  
  /// Get whether welcome page has been seen
  static bool get hasSeenWelcomePage => 
      _prefs.getBool(SettingsKeys.hasSeenWelcomePage) ?? false;
  
  /// Set whether welcome page has been seen
  static Future<void> setHasSeenWelcomePage(bool seen) => 
      _prefs.setBool(SettingsKeys.hasSeenWelcomePage, seen);
}