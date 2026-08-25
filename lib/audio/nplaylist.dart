import 'dart:convert';
import 'dart:io';
import 'package:blossom/tools/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class PlaylistManager {
  static const String _playlistFileName = 'playlists.json';
  static Map<String, Map<String, dynamic>> _playlists = {};
  static late String _playlistArtDir;
  static late String _playlistDir;
  static bool _isInitialized = false;

  /// Initialize the PlaylistManager - must be called before using any other methods
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Use platform-appropriate storage directory
      final Directory appDocDir;
      if (Platform.isAndroid || Platform.isIOS) {
        // Mobile: use external storage
        final dir = await getExternalStorageDirectory();
        if (dir == null) {
          throw Exception('Could not access external storage directory');
        }
        appDocDir = dir;
      } else {
        // Desktop (Linux, Windows, macOS): use application documents directory
        appDocDir = await getApplicationDocumentsDirectory();
      }

      _playlistDir = path.join(appDocDir.path, 'playlists');
      _playlistArtDir = path.join(_playlistDir, 'playlistArt');

      // Create directories if they don't exist
      await Directory(_playlistDir).create(recursive: true);
      await Directory(_playlistArtDir).create(recursive: true);

      _isInitialized = true;
      Log.i(LogTag.playlist, 'Initialized. dir=$_playlistDir');
    } catch (e) {
      Log.e(LogTag.playlist, 'Error during initialization: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Ensure the manager is initialized before operations
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  static Future<void> load() async {
    await _ensureInitialized();

    try {
      final file = File(path.join(_playlistDir, _playlistFileName));

      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isEmpty) {
          Log.d(LogTag.playlist, 'Playlist file is empty — starting fresh');
          _playlists = {};
          return;
        }

        final json = jsonDecode(content);
        if (json is Map<String, dynamic>) {
          _playlists = json.map((key, value) {
            if (value is! Map<String, dynamic>) {
              // Convert old format or fix corrupted data
              if (value is List) {
                return MapEntry(key, {'songs': value, 'imagePath': null});
              } else {
                return MapEntry(key, {'songs': [], 'imagePath': null});
              }
            }

            // Ensure required keys exist
            if (!value.containsKey('songs')) {
              value['songs'] = [];
            }
            if (!value.containsKey('imagePath')) {
              value['imagePath'] = null;
            }

            return MapEntry(key, value);
          });
          Log.i(LogTag.playlist, 'Loaded ${_playlists.length} playlists');
        } else {
          Log.w(LogTag.playlist, 'Invalid playlist file format');
          await _backupCorruptPlaylistFile(file);
          _playlists = {};
        }
      } else {
        Log.d(LogTag.playlist, 'No playlist file found — starting fresh');
        _playlists = {};
      }
    } catch (e) {
      Log.e(LogTag.playlist, 'Error loading playlists: $e');
      final file = File(path.join(_playlistDir, _playlistFileName));
      if (await file.exists()) {
        await _backupCorruptPlaylistFile(file);
      }
      _playlists = {};
    }
  }

  static Future<void> _backupCorruptPlaylistFile(File file) async {
    try {
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final backupPath = '${file.path}.corrupt.$timestamp';
      await file.rename(backupPath);
      Log.w(LogTag.playlist, 'Backed up corrupt playlist file: $backupPath');
    } catch (e) {
      Log.e(LogTag.playlist, 'Error backing up corrupt playlist file: $e');
    }
  }

  static Future<void> save() async {
    await _ensureInitialized();

    try {
      final file = File(path.join(_playlistDir, _playlistFileName));

      // Ensure the parent directory exists
      await file.parent.create(recursive: true);

      // Validate data before saving
      final validatedPlaylists = <String, Map<String, dynamic>>{};
      for (final entry in _playlists.entries) {
        final playlist = Map<String, dynamic>.from(entry.value);

        // Ensure songs is a valid list
        if (playlist['songs'] is! List) {
          playlist['songs'] = [];
        } else {
          // Ensure all songs are strings
          playlist['songs'] = List<String>.from(
              (playlist['songs'] as List).where((item) => item is String));
        }

        // Validate image path
        if (playlist['imagePath'] != null &&
            playlist['imagePath'] is String &&
            !await File(playlist['imagePath'] as String).exists()) {
          playlist['imagePath'] = null;
        }

        validatedPlaylists[entry.key] = playlist;
      }

      _playlists = validatedPlaylists;

      final jsonString = jsonEncode(_playlists);
      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsString(jsonString, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);

      // Verify the file was written correctly
      if (await file.exists()) {
        final savedContent = await file.readAsString();
        if (savedContent == jsonString) {
          Log.d(LogTag.playlist, 'Saved ${_playlists.length} playlists');
        } else {
          Log.w(LogTag.playlist, 'Saved content differs from expected');
        }
      } else {
        Log.w(LogTag.playlist, 'File does not exist after save attempt');
      }
    } catch (e) {
      Log.e(LogTag.playlist, 'Error saving playlists: $e');
      rethrow;
    }
  }

  static List<String> get playlistNames => _playlists.keys.toList();

  static List<String> getPlaylistSongs(String playlistName) {
    final playlist = _playlists[playlistName];
    if (playlist == null) return [];

    final songs = playlist['songs'];
    if (songs is List) {
      return List<String>.from(songs.where((item) => item is String));
    }
    return [];
  }

  static String? getPlaylistImagePath(String playlistName) {
    final playlist = _playlists[playlistName];
    if (playlist == null) return null;

    String? imagePath = playlist['imagePath'];
    if (imagePath != null && File(imagePath).existsSync()) {
      return imagePath;
    } else {
      // Try to find an image with the playlist name in the _playlistArtDir
      try {
        final dir = Directory(_playlistArtDir);
        if (dir.existsSync()) {
          List<FileSystemEntity> files = dir.listSync();
          for (var file in files) {
            if (file is File &&
                path.basenameWithoutExtension(file.path) == playlistName) {
              // Update in-memory only — this getter runs during widget builds,
              // and an unawaited save() here can interleave with other saves.
              // The recovered path persists on the next regular save().
              _playlists[playlistName]!['imagePath'] = file.path;
              return file.path;
            }
          }
        }
      } catch (e) {
        Log.w(LogTag.playlist, 'Error searching for playlist image: $e');
      }
    }
    return null;
  }

  static Future<void> createPlaylist(String name, {String? imagePath}) async {
    await _ensureInitialized();

    if (name.trim().isEmpty) {
      throw ArgumentError('Playlist name cannot be empty');
    }

    if (!_playlists.containsKey(name)) {
      _playlists[name] = {
        'songs': <String>[],
        'imagePath': imagePath,
        'created': DateTime.now().toIso8601String(),
      };
      await save();
      Log.d(LogTag.playlist, 'Created playlist: $name');
    } else {
      Log.d(LogTag.playlist, 'Playlist already exists: $name');
    }
  }

  static Future<void> deletePlaylist(String name) async {
    await _ensureInitialized();

    if (!_playlists.containsKey(name)) {
      Log.w(LogTag.playlist, 'deletePlaylist: not found: $name');
      return;
    }

    try {
      String? imagePath = _playlists[name]?['imagePath'];
      if (imagePath != null && File(imagePath).existsSync()) {
        await File(imagePath).delete();
        Log.d(LogTag.playlist, 'Deleted playlist image: $imagePath');
      }
    } catch (e) {
      Log.w(LogTag.playlist, 'Error deleting playlist image: $e');
      // Continue with playlist deletion even if image deletion fails
    }

    _playlists.remove(name);
    await save();
    Log.d(LogTag.playlist, 'Deleted playlist: $name');
  }

  static Future<void> addSongToPlaylist(
      String playlistName, String songId) async {
    await _ensureInitialized();

    if (songId.trim().isEmpty) {
      Log.w(LogTag.playlist, 'Cannot add empty song id to playlist');
      return;
    }

    if (!_playlists.containsKey(playlistName)) {
      await createPlaylist(playlistName);
    }

    final songs = List<String>.from(_playlists[playlistName]!['songs']);
    if (!songs.contains(songId)) {
      songs.add(songId);
      _playlists[playlistName]!['songs'] = songs;
      _playlists[playlistName]!['modified'] = DateTime.now().toIso8601String();
      await save();
      Log.d(LogTag.playlist, 'Added "$songId" to "$playlistName"');
    } else {
      Log.v(LogTag.playlist, '"$songId" already in "$playlistName"');
    }
  }

  static Future<void> removeSongFromPlaylist(
      String playlistName, String songId) async {
    await _ensureInitialized();

    if (!_playlists.containsKey(playlistName)) {
      Log.w(LogTag.playlist, 'removeSong: playlist not found: $playlistName');
      return;
    }

    final songs = List<String>.from(_playlists[playlistName]!['songs']);
    if (songs.remove(songId)) {
      _playlists[playlistName]!['songs'] = songs;
      _playlists[playlistName]!['modified'] = DateTime.now().toIso8601String();
      await save();
      Log.d(LogTag.playlist, 'Removed "$songId" from "$playlistName"');
    } else {
      Log.v(LogTag.playlist, '"$songId" was not in "$playlistName"');
    }
  }

  static Future<void> reorderSongs(
      String playlistName, List<String> orderedSongIds) async {
    await _ensureInitialized();

    if (!_playlists.containsKey(playlistName)) {
      Log.w(LogTag.playlist, 'reorderSongs: playlist not found: $playlistName');
      return;
    }

    // Simply replace the songs list with the new ordered list
    _playlists[playlistName]!['songs'] = orderedSongIds;
    _playlists[playlistName]!['modified'] = DateTime.now().toIso8601String();

    await save();
    Log.d(LogTag.playlist,
        'Reordered "$playlistName" (${orderedSongIds.length} songs)');
  }

  static Future<void> setPlaylistImage(
      String playlistName, File imageFile) async {
    await _ensureInitialized();

    if (!_playlists.containsKey(playlistName)) {
      Log.w(LogTag.playlist,
          'setPlaylistImage: playlist not found: $playlistName');
      return;
    }

    if (!await imageFile.exists()) {
      throw ArgumentError('Image file does not exist: ${imageFile.path}');
    }

    try {
      String extension = path.extension(imageFile.path);
      String newImagePath =
          path.join(_playlistArtDir, '$playlistName$extension');

      // Remove old image if it exists
      String? oldImagePath = _playlists[playlistName]!['imagePath'];
      if (oldImagePath != null && File(oldImagePath).existsSync()) {
        await File(oldImagePath).delete();
      }

      await imageFile.copy(newImagePath);
      _playlists[playlistName]!['imagePath'] = newImagePath;
      _playlists[playlistName]!['modified'] = DateTime.now().toIso8601String();
      await save();
      Log.d(LogTag.playlist, 'Set image for "$playlistName": $newImagePath');
    } catch (e) {
      Log.e(LogTag.playlist, 'Error setting playlist image: $e');
      rethrow;
    }
  }

  /// Debug method to check current state
  static Map<String, dynamic> getDebugInfo() {
    return {
      'isInitialized': _isInitialized,
      'playlistCount': _playlists.length,
      'playlistNames': playlistNames,
      'artDirectory': _playlistArtDir,
      'playlistDirectory': _playlistDir,
    };
  }

  /// Get the playlist directory path (useful for debugging or migration)
  static String get playlistDirectory => _playlistDir;

  /// Get the playlist art directory path
  static String get playlistArtDirectory => _playlistArtDir;
}
