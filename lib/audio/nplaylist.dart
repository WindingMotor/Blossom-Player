import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:blossom/tools/settings.dart';

class PlaylistManager {
  static const String _playlistFileName = 'playlists.json';
  static Map<String, List<String>> _playlists = {};

  static Future<void> load() async {
    final songDir = await Settings.getSongDir();
    final file = File(path.join(songDir, _playlistFileName));

    if (await file.exists()) {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      _playlists = json.map((key, value) => MapEntry(key, List<String>.from(value)));
    }
  }

  static Future<void> save() async {
    final songDir = await Settings.getSongDir();
    final file = File(path.join(songDir, _playlistFileName));
    await file.writeAsString(jsonEncode(_playlists));
  }

  static List<String> get playlistNames => _playlists.keys.toList();

  static List<String> getPlaylistSongs(String playlistName) {
    return _playlists[playlistName] ?? [];
  }

  static Future<void> createPlaylist(String name) async {
    if (!_playlists.containsKey(name)) {
      _playlists[name] = [];
      await save();
    }
  }

  static Future<void> deletePlaylist(String name) async {
    _playlists.remove(name);
    await save();
  }

  static Future<void> addSongToPlaylist(String playlistName, String songName) async {
    if (!_playlists.containsKey(playlistName)) {
      await createPlaylist(playlistName);
    }
    if (!_playlists[playlistName]!.contains(songName)) {
      _playlists[playlistName]!.add(songName);
      await save();
    }
  }

  static Future<void> removeSongFromPlaylist(String playlistName, String songName) async {
    if (_playlists.containsKey(playlistName)) {
      _playlists[playlistName]!.remove(songName);
      await save();
    }
  }
}