import 'dart:convert';
import 'dart:io';
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
      print('[PlaylistManager] Initialized successfully');
      print('[PlaylistManager] Playlist directory: $_playlistDir');
      print('[PlaylistManager] Playlist art directory: $_playlistArtDir');
    } catch (e) {
      print('[PlaylistManager] Error during initialization: $e');
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
          print('[PlaylistManager] Playlist file is empty, initializing with empty playlists');
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
          print('[PlaylistManager] Loaded ${_playlists.length} playlists');
        } else {
          print('[PlaylistManager] Invalid playlist file format, resetting');
          _playlists = {};
        }
      } else {
        print('[PlaylistManager] No playlist file found, starting fresh');
        _playlists = {};
      }
    } catch (e) {
      print('[PlaylistManager] Error loading playlists: $e');
      _playlists = {};
      // Try to save an empty playlist file to ensure the system works
      await _forceSave();
    }
  }

  /// Force save without validation - used for recovery
  static Future<void> _forceSave() async {
    try {
      final file = File(path.join(_playlistDir, _playlistFileName));
      
      // Ensure directory exists
      await file.parent.create(recursive: true);
      
      await file.writeAsString(jsonEncode(_playlists));
      print('[PlaylistManager] Force saved playlists');
    } catch (e) {
      print('[PlaylistManager] Error in force save: $e');
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
            (playlist['songs'] as List).where((item) => item is String)
          );
        }
        
        // Validate image path
        if (playlist['imagePath'] != null && 
            playlist['imagePath'] is String && 
            !File(playlist['imagePath']).existsSync()) {
          playlist['imagePath'] = null;
        }
        
        validatedPlaylists[entry.key] = playlist;
      }
      
      _playlists = validatedPlaylists;
      
      final jsonString = jsonEncode(_playlists);
      await file.writeAsString(jsonString);
      
      // Verify the file was written correctly
      if (await file.exists()) {
        final savedContent = await file.readAsString();
        if (savedContent == jsonString) {
          print('[PlaylistManager] Successfully saved ${_playlists.length} playlists');
        } else {
          print('[PlaylistManager] Warning: Saved content differs from expected');
        }
      } else {
        print('[PlaylistManager] Warning: File does not exist after save attempt');
      }
    } catch (e) {
      print('[PlaylistManager] Error saving playlists: $e');
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
        Directory dir = Directory(_playlistArtDir);
        if (dir.existsSync()) {
          List<FileSystemEntity> files = dir.listSync();
          for (var file in files) {
            if (file is File && path.basenameWithoutExtension(file.path) == playlistName) {
              _playlists[playlistName]!['imagePath'] = file.path;
              save(); // Update the saved playlist data
              return file.path;
            }
          }
        }
      } catch (e) {
        print('[PlaylistManager] Error searching for playlist image: $e');
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
      print('[PlaylistManager] Created playlist: $name');
    } else {
      print('[PlaylistManager] Playlist already exists: $name');
    }
  }

  static Future<void> deletePlaylist(String name) async {
    await _ensureInitialized();
    
    if (!_playlists.containsKey(name)) {
      print('[PlaylistManager] Playlist does not exist: $name');
      return;
    }
    
    try {
      String? imagePath = _playlists[name]?['imagePath'];
      if (imagePath != null && File(imagePath).existsSync()) {
        await File(imagePath).delete();
        print('[PlaylistManager] Deleted playlist image: $imagePath');
      }
    } catch (e) {
      print('[PlaylistManager] Error deleting playlist image: $e');
      // Continue with playlist deletion even if image deletion fails
    }
    
    _playlists.remove(name);
    await save();
    print('[PlaylistManager] Deleted playlist: $name');
  }

  static Future<void> addSongToPlaylist(String playlistName, String songName) async {
    await _ensureInitialized();
    
    if (songName.trim().isEmpty) {
      print('[PlaylistManager] Cannot add empty song name to playlist');
      return;
    }
    
    if (!_playlists.containsKey(playlistName)) {
      await createPlaylist(playlistName);
    }
    
    final songs = List<String>.from(_playlists[playlistName]!['songs']);
    if (!songs.contains(songName)) {
      songs.add(songName);
      _playlists[playlistName]!['songs'] = songs;
      _playlists[playlistName]!['modified'] = DateTime.now().toIso8601String();
      await save();
      print('[PlaylistManager] Added "$songName" to playlist "$playlistName"');
    } else {
      print('[PlaylistManager] Song "$songName" already exists in playlist "$playlistName"');
    }
  }

  static Future<void> removeSongFromPlaylist(String playlistName, String songName) async {
    await _ensureInitialized();
    
    if (!_playlists.containsKey(playlistName)) {
      print('[PlaylistManager] Playlist does not exist: $playlistName');
      return;
    }
    
    final songs = List<String>.from(_playlists[playlistName]!['songs']);
    if (songs.remove(songName)) {
      _playlists[playlistName]!['songs'] = songs;
      _playlists[playlistName]!['modified'] = DateTime.now().toIso8601String();
      await save();
      print('[PlaylistManager] Removed "$songName" from playlist "$playlistName"');
    } else {
      print('[PlaylistManager] Song "$songName" was not in playlist "$playlistName"');
    }
  }

  static Future<void> setPlaylistImage(String playlistName, File imageFile) async {
    await _ensureInitialized();
    
    if (!_playlists.containsKey(playlistName)) {
      print('[PlaylistManager] Playlist does not exist: $playlistName');
      return;
    }
    
    if (!await imageFile.exists()) {
      throw ArgumentError('Image file does not exist: ${imageFile.path}');
    }
    
    try {
      String extension = path.extension(imageFile.path);
      String newImagePath = path.join(_playlistArtDir, '$playlistName$extension');
      
      // Remove old image if it exists
      String? oldImagePath = _playlists[playlistName]!['imagePath'];
      if (oldImagePath != null && File(oldImagePath).existsSync()) {
        await File(oldImagePath).delete();
      }
      
      await imageFile.copy(newImagePath);
      _playlists[playlistName]!['imagePath'] = newImagePath;
      _playlists[playlistName]!['modified'] = DateTime.now().toIso8601String();
      await save();
      print('[PlaylistManager] Set image for playlist "$playlistName": $newImagePath');
    } catch (e) {
      print('[PlaylistManager] Error setting playlist image: $e');
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
