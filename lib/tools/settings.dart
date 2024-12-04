/// Settings Management System
/// Handles persistent storage and retrieval of application settings
/// Uses SharedPreferences for data persistence

import 'dart:io';
import 'package:blossom/audio/song_data.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}

/// Manages application settings and preferences
class Settings {
  static late SharedPreferences _prefs;
  
  /// Initialize settings system
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await SongData.init();
    
    // Migrate existing favorites if needed
    if (_prefs.containsKey('favoriteSongs')) {
      final oldFavorites = _prefs.getStringList('favoriteSongs') ?? [];
      for (final song in oldFavorites) {
        await SongData.setFavorite(song, true);
      }
      await _prefs.remove('favoriteSongs');
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
    print('Last playing song: $song');
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
  /// File System Settings
  ///***************************************************************************
  
  /// Get the directory where songs are stored
  static Future<String> getSongDir() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final directory = await getApplicationDocumentsDirectory();
      final blossomMediaDir = Directory('${directory.path}/BlossomMedia');
      if (!await blossomMediaDir.exists()) {
        await blossomMediaDir.create(recursive: true);
      }
      return blossomMediaDir.path;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
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
