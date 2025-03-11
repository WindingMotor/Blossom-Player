import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SongData {
  static const String _fileName = 'song_data.json';
  static Map<String, dynamic> _data = {};
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$_fileName');
    
    if (await file.exists()) {
      final jsonString = await file.readAsString();
      _data = json.decode(jsonString);
    }
    
    _initialized = true;
  }

  static Future<void> _save() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$_fileName');
    await file.writeAsString(json.encode(_data));
  }

  static bool isFavorite(String songPath) {
    final songData = _data[songPath] ?? {};
    return songData['favorite'] ?? false;
  }

  static Future<void> setFavorite(String songPath, bool favorite) async {
    if (!_data.containsKey(songPath)) {
      _data[songPath] = {};
    }
    _data[songPath]['favorite'] = favorite;
    await _save();
  }

  static int getPlayCount(String songPath) {
    final songData = _data[songPath] ?? {};
    return songData['playCount'] ?? 0;
  }

  static Future<void> incrementPlayCount(String songPath) async {
    if (!_data.containsKey(songPath)) {
      _data[songPath] = {};
    }
    final currentCount = _data[songPath]['playCount'] ?? 0;
    _data[songPath]['playCount'] = currentCount + 1;
    await _save();
  }

  static List<String> getFavoriteSongs() {
    return _data.entries
        .where((entry) => entry.value['favorite'] == true)
        .map((entry) => entry.key)
        .toList();
  }

  static Future<void> removeSongEntry(String songPath) async {
    if (_data.containsKey(songPath)) {
      _data.remove(songPath);
      await _save();
    }
  }
}
