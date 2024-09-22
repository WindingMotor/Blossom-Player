import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:blossom/tools/settings.dart';

class PlaylistManager {
  static const String _playlistFileName = 'playlists.json';
  static Map<String, Map<String, dynamic>> _playlists = {};
  static late String _playlistArtDir;

  static Future<void> load() async {
    final songDir = await Settings.getSongDir();
    final file = File(path.join(songDir, _playlistFileName));
    _playlistArtDir = path.join(songDir, 'playlistArt');

    // Create playlistArt directory if it doesn't exist
    await Directory(_playlistArtDir).create(recursive: true);

    if (await file.exists()) {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      _playlists = json.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value)));
    }
  }

  static Future<void> save() async {
    final songDir = await Settings.getSongDir();
    final file = File(path.join(songDir, _playlistFileName));
    await file.writeAsString(jsonEncode(_playlists));
  }

  static List<String> get playlistNames => _playlists.keys.toList();

  static List<String> getPlaylistSongs(String playlistName) {
    return List<String>.from(_playlists[playlistName]?['songs'] ?? []);
  }

  static String? getPlaylistImagePath(String playlistName) {
    return _playlists[playlistName]?['imagePath'];
  }

  static Future<void> createPlaylist(String name, {String? imagePath}) async {
    if (!_playlists.containsKey(name)) {
      _playlists[name] = {'songs': [], 'imagePath': imagePath};
      await save();
    }
  }

  static Future<void> deletePlaylist(String name) async {
    String? imagePath = _playlists[name]?['imagePath'];
    if (imagePath != null) {
      await File(imagePath).delete();
    }
    _playlists.remove(name);
    await save();
  }

  static Future<void> addSongToPlaylist(String playlistName, String songName) async {
    if (!_playlists.containsKey(playlistName)) {
      await createPlaylist(playlistName);
    }
    if (!_playlists[playlistName]!['songs'].contains(songName)) {
      _playlists[playlistName]!['songs'].add(songName);
      await save();
    }
  }

  static Future<void> removeSongFromPlaylist(String playlistName, String songName) async {
    if (_playlists.containsKey(playlistName)) {
      _playlists[playlistName]!['songs'].remove(songName);
      await save();
    }
  }

  static Future<void> setPlaylistImage(String playlistName, File imageFile) async {
    String newImagePath = path.join(_playlistArtDir, '$playlistName${path.extension(imageFile.path)}');
    await imageFile.copy(newImagePath);
    _playlists[playlistName]!['imagePath'] = newImagePath;
    await save();
  }
}