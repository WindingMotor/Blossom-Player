import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

// Song directory

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

  // Last playing song
  static String? get lastPlayingSong => _prefs.getString('lastPlayingSong');
  static Future<void> setLastPlayingSong(String? song) {
    print('Last playing song: $song');
    return _prefs.setString('lastPlayingSong', song ?? '');
  }

  // Volume
  static const double _defaultVolume = 1.0;
  static double get volume => _prefs.getDouble('volume') ?? _defaultVolume;
  static Future<void> setVolume(double vol) => _prefs.setDouble('volume', vol);

// Previous shuffle setting
static bool get previousForShuffle => _prefs.getBool('previousForShuffle') ?? false;
static Future<void> setPreviousForShuffle(bool enabled) => 
    _prefs.setBool('previousForShuffle', enabled);

  // Repeat mode
  static String get repeatMode => _prefs.getString('repeatMode') ?? 'off';
  static Future<void> setRepeatMode(String mode) =>
      _prefs.setString('repeatMode', mode);

  // Theme mode
  static String get themeMode => _prefs.getString('themeMode') ?? 'system';
  static Future<void> setThemeMode(String mode) =>
      _prefs.setString('themeMode', mode);

// Artist sort preference
  static String get artistSortBy => _prefs.getString('artistSortBy') ?? 'name';
  static bool get artistSortAscending =>
      _prefs.getBool('artistSortAscending') ?? true;
  static Future<void> setArtistSort(String sortBy, bool ascending) async {
    await _prefs.setString('artistSortBy', sortBy);
    await _prefs.setBool('artistSortAscending', ascending);
  }

// Album sort preference
static String get albumSortBy {
  String sortBy = _prefs.getString('albumSortBy') ?? 'name';
  if (!['name', 'year', 'artist', 'folder'].contains(sortBy)) {
    sortBy = 'name'; // Default to 'name' if an invalid value is stored
  }
  return sortBy;
}

static Future setAlbumSort(
    String sortBy, bool ascending, bool organizeByFolder) async {
  if (['name', 'year', 'artist', 'folder'].contains(sortBy)) {
    await _prefs.setString('albumSortBy', sortBy);
  } else {
    await _prefs.setString('albumSortBy', 'name'); // Default to 'name' if invalid
  }
  await _prefs.setBool('albumSortAscending', ascending);
  await _prefs.setBool('albumOrganizeByFolder', organizeByFolder);
}

  // Library sort preference
  static String get songSortBy => _prefs.getString('songSortBy') ?? 'title';
  static bool get songSortAscending => _prefs.getBool('songSortAscending') ?? true;

  static Future<void> setLibrarySongSort(String sortBy, bool ascending) async {
    await _prefs.setString('songSortBy', sortBy);
    await _prefs.setBool('songSortAscending', ascending);
  }

  static bool get albumSortAscending =>
      _prefs.getBool('albumSortAscending') ?? true;
  static bool get albumOrganizeByFolder =>
      _prefs.getBool('albumOrganizeByFolder') ?? false;
      
  static String get appTheme => _prefs.getString('appTheme') ?? 'system';
  static Future<void> setAppTheme(String theme) =>
      _prefs.setString('appTheme', theme);

// Has seen welcome page
static bool get hasSeenWelcomePage => _prefs.getBool('hasSeenWelcomePage') ?? false;
static Future<void> setHasSeenWelcomePage(bool seen) => 
    _prefs.setBool('hasSeenWelcomePage', seen);


      
}
