/// Settings Management System
/// Handles persistent storage and retrieval of application settings
/// Uses SharedPreferences for data persistence

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:blossom/audio/song_data.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'dart:math'; 

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

  static String uuid = '';
  static String? publicUsername;
  static bool isPublicSharingEnabled = false;
  
  /// Initialize settings system
  static Future<void> init() async {

    _prefs = await SharedPreferences.getInstance();
    await SongData.init();
    
    // Set debug mode
    _debugMode = _prefs.getBool(SettingsKeys.debugMode) ?? true;
    
    uuid = _prefs.getString('uuid') ?? '';
  if (uuid.isEmpty) {
    await generateAndSaveUuid();
  }
  publicUsername = _prefs.getString('publicUsername');
  isPublicSharingEnabled = _prefs.getBool('isPublicSharingEnabled') ?? false;

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

// Friends list
static List<String> _friendsList = [];
static const String _friendsListKey = 'friends_list';

static List<String> get friendsList => _friendsList;

static Future<void> loadFriendsList() async {
  final friendsJson = _prefs.getString(_friendsListKey);
  if (friendsJson != null) {
    try {
      _friendsList = (jsonDecode(friendsJson) as List<dynamic>).cast<String>();
    } catch (e) {
      print('Error loading friends list: $e');
      _friendsList = [];
    }
  }
}

static Future<void> saveFriendsList(List<String> friends) async {
  _friendsList = friends;
  await _prefs.setString(_friendsListKey, jsonEncode(friends));
}

static Future<void> addFriend(String uuid) async {
  if (!_friendsList.contains(uuid)) {
    _friendsList.add(uuid);
    await saveFriendsList(_friendsList);
  }
}

static Future<void> removeFriend(String uuid) async {
  _friendsList.remove(uuid);
  await saveFriendsList(_friendsList);
}

// Generate random username
static const List<String> _adjectives = [
  'Cosmic', 'Electric', 'Melodic', 'Rhythmic', 'Harmonic',
  'Sonic', 'Groovy', 'Funky', 'Jazzy', 'Rockin',
  'Stellar', 'Lunar', 'Solar', 'Nebula', 'Quantum',
  'Digital', 'Analog', 'Synth', 'Vinyl', 'Echo',
  'Retro', 'Neon', 'Crystal', 'Velvet', 'Thunder',
];

static const List<String> _nouns = [
  'Dreamer', 'Wanderer', 'Explorer', 'Listener', 'Dancer',
  'Seeker', 'Vibes', 'Beats', 'Notes', 'Waves',
  'Soul', 'Spirit', 'Phoenix', 'Dragon', 'Tiger',
  'Wolf', 'Eagle', 'Hawk', 'Raven', 'Falcon',
  'Storm', 'Breeze', 'Thunder', 'Lightning', 'Aurora',
];

static String generateRandomUsername() {
  final random = Random();
  final adjective = _adjectives[random.nextInt(_adjectives.length)];
  final noun = _nouns[random.nextInt(_nouns.length)];
  return '$adjective $noun';
}

// Initialize random username if not set
static Future<void> initializeUsername() async {
  if (publicUsername == null || publicUsername!.isEmpty) {  // ✅ Check for null first
    final randomUsername = generateRandomUsername();
    await setPublicUsername(randomUsername);
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
/// Get all directories where songs might be stored
static Future<List<Directory>> getAllSongDirs() async {
  List<Directory> directories = [];
  
  // Check for user-selected directory FIRST
  final String? customDir = customMusicDirectory;
  
  if (customDir != null && customDir.isNotEmpty) {
    _log("Using user-selected music directory: $customDir");
    final dir = Directory(customDir);
    if (await isDirectoryAccessible(dir)) {
      directories.add(dir);
      return directories; // RETURN IMMEDIATELY - use ONLY this directory
    } else {
      _log("WARNING: User-selected directory not accessible: $customDir");
    }
  }
  
  // If no custom directory set or it's not accessible, use platform default
  _log("No custom directory set, using platform default");
  
  if (Platform.isAndroid) {
    // Android: Use /storage/emulated/0/Music as default
    final defaultDir = Directory('/storage/emulated/0/Music');
    if (await isDirectoryAccessible(defaultDir)) {
      directories.add(defaultDir);
      _log("Using Android default: ${defaultDir.path}");
    } else {
      _log("WARNING: Default Music directory not accessible, using app documents");
      final appDir = await getApplicationDocumentsDirectory();
      directories.add(Directory(appDir.path));
    }
    
  } else if (Platform.isIOS) {
    // iOS: Use application documents directory
    final directory = await getApplicationDocumentsDirectory();
    directories.add(Directory(directory.path));
    _log("Using iOS documents directory: ${directory.path}");
    
  } else {
    // Desktop: Use BlossomMedia folder in documents
    final directory = await getApplicationDocumentsDirectory();
    final blossomMediaDir = Directory('${directory.path}/BlossomMedia');
    if (!await blossomMediaDir.exists()) {
      await blossomMediaDir.create(recursive: true);
    }
    directories.add(blossomMediaDir);
    _log("Desktop using BlossomMedia directory: ${blossomMediaDir.path}");
  }
  
  _log("Final directories list (${directories.length} directories):");
  for (var dir in directories) {
    _log(" - ${dir.path}");
  }
  
  return directories;
}

/// Get the primary directory where songs are stored (for backward compatibility)
static Future<String> getSongDir() async {
  final dirs = await getAllSongDirs();
  return dirs.isNotEmpty ? dirs.first.path : '';
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

  ///***************************************************************************
  /// Public Sharing Settings 
  ///***************************************************************************
  
  /// Generate and save a unique UUID for this user
  static Future<void> generateAndSaveUuid() async {
    uuid = 'user-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    await _prefs.setString('uuid', uuid);
    _log('Generated new UUID: $uuid');
  }
  
  /// Set public username
  static Future<void> setPublicUsername(String username) async {
    publicUsername = username;
    await _prefs.setString('publicUsername', username);
  }
  
  /// Set public sharing enabled state
  static Future<void> setPublicSharingEnabled(bool enabled) async {
    isPublicSharingEnabled = enabled;
    await _prefs.setBool('isPublicSharingEnabled', enabled);
  }
}