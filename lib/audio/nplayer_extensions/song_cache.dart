import 'dart:io';
import 'package:blossom/audio/nplayer.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Manages persistent caching of song metadata using SQLite
/// 
/// Optimized for large libraries (10,000+ songs):
/// - No in-memory cache - all data stored in SQLite
/// - Non-blocking async database operations
/// - Automatic batched writes for performance
/// - Minimal memory footprint
class SongCache {
  // ============================================================================
  // MARK: - Constants
  // ============================================================================
  
  static const String _dbFileName = 'song_cache.db';
  static const int _dbVersion = 2;
  static const int _writeBatchSize = 100; // Write in batches for speed
  
  // ============================================================================
  // MARK: - Properties
  // ============================================================================
  
  Database? _database;
  bool _isInitialized = false;
  final List<CachedSongEntry> _pendingWrites = [];
  bool _isWriting = false;

  // ============================================================================
  // MARK: - Initialization
  // ============================================================================
  
  /// Initialize the cache system
  /// 
  /// Opens SQLite database and creates tables if needed.
  /// Safe to call multiple times (idempotent).
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dbPath = path.join(directory.path, _dbFileName);
      
      _database = await openDatabase(
        dbPath,
        version: _dbVersion,
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
      );
      
      _isInitialized = true;
      final count = await _getEntryCount();
      _log("Cache initialized with $count entries");
    } catch (e) {
      _log("Error initializing cache: $e");
      _isInitialized = true;
    }
  }
  
  /// Create database tables
  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE songs (
        path TEXT PRIMARY KEY,
        folderName TEXT NOT NULL,
        lastModified INTEGER NOT NULL,
        fileSize INTEGER NOT NULL,
        title TEXT NOT NULL,
        album TEXT NOT NULL,
        artist TEXT NOT NULL,
        duration INTEGER NOT NULL,
        pictureData BLOB,
        year TEXT NOT NULL,
        genre TEXT NOT NULL
      )
    ''');
    
    // Index for fast lookups
    await db.execute('CREATE INDEX idx_path ON songs(path)');
    await db.execute('CREATE INDEX idx_lastModified ON songs(lastModified)');
    
    _log("Database tables created");
  }
  
  /// Upgrade database schema
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    _log("Upgrading database from v$oldVersion to v$newVersion");
    // Future migrations go here
  }

  // ============================================================================
  // MARK: - Cache Operations
  // ============================================================================
  
  /// Get cached entry for a file path
  Future<CachedSongEntry?> get(String filePath) async {
    if (_database == null) return null;
    
    try {
      final result = await _database!.query(
        'songs',
        where: 'path = ?',
        whereArgs: [filePath],
        limit: 1,
      );
      
      if (result.isEmpty) return null;
      return CachedSongEntry.fromMap(result.first);
    } catch (e) {
      _log("Error getting cache entry: $e");
      return null;
    }
  }
  
  /// Check if a file is cached and still valid
  Future<bool> isValid(String filePath, DateTime lastModified, int fileSize) async {
    if (_database == null) return false;
    
    try {
      final result = await _database!.query(
        'songs',
        columns: ['lastModified', 'fileSize'],
        where: 'path = ?',
        whereArgs: [filePath],
        limit: 1,
      );
      
      if (result.isEmpty) return false;
      
      return result.first['lastModified'] == lastModified.millisecondsSinceEpoch &&
             result.first['fileSize'] == fileSize;
    } catch (e) {
      _log("Error checking validity: $e");
      return false;
    }
  }
  
  /// Add or update a cache entry with batched writes
  /// 
  /// Entries are queued and written in batches for performance.
  /// Does NOT block the UI thread.
Future<void> put(String filePath, CachedSongEntry entry) async {
  if (_database == null) return;
  
  // Remove any existing entry with the same path before adding
  _pendingWrites.removeWhere((e) => e.path == filePath);
  
  _pendingWrites.add(entry);
  
  // Trigger batch write when we have enough entries
  if (_pendingWrites.length >= _writeBatchSize) {
    // Don't await - let it run in background
    _flushPendingWrites();
  }
}
  
/// Flush all pending writes to database
Future<void> _flushPendingWrites() async {
  if (_isWriting || _pendingWrites.isEmpty || _database == null) return;
  
  _isWriting = true;
  
  // Deduplicate by path - keep only the last occurrence of each path
  final Map<String, CachedSongEntry> uniqueEntries = {};
  for (final entry in _pendingWrites) {
    uniqueEntries[entry.path] = entry; // Later entries overwrite earlier ones
  }
  
  final toWrite = uniqueEntries.values.toList();
  _pendingWrites.clear();
  
  try {
    final batch = _database!.batch();
    
    for (final entry in toWrite) {
      batch.insert(
        'songs',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
    _log("Flushed ${toWrite.length} unique entries to cache");
  } catch (e) {
    _log("Error flushing writes: $e");
    // Re-add failed writes to queue
    _pendingWrites.addAll(toWrite.map((e) => e));
  } finally {
    _isWriting = false;
  }
}
  
  /// Remove invalid entries for files that no longer exist
  Future<void> cleanInvalidEntries(Set<String> validPaths) async {
    if (_database == null) return;
    
    try {
      // Get all paths from database
      final allPaths = await _database!.query('songs', columns: ['path']);
      
      final invalidPaths = allPaths
          .map((row) => row['path'] as String)
          .where((p) => !validPaths.contains(p))
          .toList();
      
      if (invalidPaths.isEmpty) return;
      
      // Delete invalid entries in batches
      final batch = _database!.batch();
      for (final invalidPath in invalidPaths) {
        batch.delete('songs', where: 'path = ?', whereArgs: [invalidPath]);
      }
      
      await batch.commit(noResult: true);
      _log("Removed ${invalidPaths.length} invalid cache entries");
    } catch (e) {
      _log("Error cleaning invalid entries: $e");
    }
  }
  
  /// Clear entire cache
  Future<void> clear() async {
    if (_database == null) return;
    
    try {
      await _database!.delete('songs');
      _pendingWrites.clear();
      _log("Cache cleared");
    } catch (e) {
      _log("Error clearing cache: $e");
    }
  }
  
  /// Ensure all pending writes are saved
  Future<void> save() async {
    await _flushPendingWrites();
  }

/// Load ALL cache entries at once into memory for fast lookups
/// 
/// Returns a Map of path -> CachedSongEntry for O(1) lookups
/// This is much faster than individual queries for large libraries
/// Load ALL cache entries at once into memory WITHOUT picture data
/// 
/// Returns a Map of path -> CachedSongEntry for O(1) lookups
/// Picture data is excluded to save memory and loaded on-demand
Future<Map<String, CachedSongEntry>> loadAll() async {
  if (_database == null) return {};
  
  try {
    final startTime = DateTime.now();
    
    // Query ALL rows at once BUT EXCLUDE pictureData to save memory
    final List<Map<String, dynamic>> results = await _database!.query(
      'songs',
      columns: [
        'path',
        'folderName', 
        'lastModified',
        'fileSize',
        'title',
        'album',
        'artist',
        'duration',
        // 'pictureData', // EXCLUDE THIS - saves ~300MB memory!
        'year',
        'genre',
      ],
    );
    
    // Convert to Map for O(1) lookups
    final Map<String, CachedSongEntry> cache = {};
    for (final row in results) {
      // Add null pictureData since we didn't query it
      final rowWithNullPicture = Map<String, dynamic>.from(row);
      rowWithNullPicture['pictureData'] = null;
      
      final entry = CachedSongEntry.fromMap(rowWithNullPicture);
      cache[entry.path] = entry;
    }
    
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    _log("Loaded ${cache.length} cache entries (without pictures) in ${elapsed}ms");
    
    return cache;
  } catch (e) {
    _log("Error loading all cache entries: $e");
    return {};
  }
}

/// Get album art for a specific song (lazy loading)
/// 
/// Only loads picture data when actually needed
Future<Uint8List?> getPicture(String filePath) async {
  if (_database == null) return null;
  
  try {
    final result = await _database!.query(
      'songs',
      columns: ['pictureData'],
      where: 'path = ?',
      whereArgs: [filePath],
      limit: 1,
    );
    
    if (result.isEmpty) return null;
    return result.first['pictureData'] as Uint8List?;
  } catch (e) {
    _log("Error getting picture: $e");
    return null;
  }
}

/// Bulk validate multiple files at once
/// 
/// Much faster than calling isValid() individually for each file
Future<Map<String, bool>> validateBulk(Map<String, FileStat> files) async {
  if (_database == null) return {};
  
  try {
    final paths = files.keys.toList();
    final results = <String, bool>{};
    
    // Query all paths at once using IN clause
    // Split into chunks to avoid SQLite parameter limits (999)
    const chunkSize = 500;
    
    for (int i = 0; i < paths.length; i += chunkSize) {
      final chunk = paths.skip(i).take(chunkSize).toList();
      final placeholders = List.filled(chunk.length, '?').join(',');
      
      final rows = await _database!.query(
        'songs',
        columns: ['path', 'lastModified', 'fileSize'],
        where: 'path IN ($placeholders)',
        whereArgs: chunk,
      );
      
      for (final row in rows) {
        final path = row['path'] as String;
        final stat = files[path];
        if (stat != null) {
          results[path] = 
            row['lastModified'] == stat.modified.millisecondsSinceEpoch &&
            row['fileSize'] == stat.size;
        }
      }
    }
    
    return results;
  } catch (e) {
    _log("Error bulk validating: $e");
    return {};
  }
}

  // ============================================================================
  // MARK: - Statistics
  // ============================================================================
  
  /// Get count of cached entries
  Future<int> _getEntryCount() async {
    if (_database == null) return 0;
    
    try {
      final result = await _database!.rawQuery('SELECT COUNT(*) as count FROM songs');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      _log("Error getting entry count: $e");
      return 0;
    }
  }
  
  /// Get cache statistics
  Future<Map<String, dynamic>> getStats() async {
    final count = await _getEntryCount();
    return {
      'totalEntries': count,
      'pendingWrites': _pendingWrites.length,
      'isInitialized': _isInitialized,
      'isWriting': _isWriting,
    };
  }

  // ============================================================================
  // MARK: - Utilities
  // ============================================================================
  
  void _log(String message) {
    if (kDebugMode) {
      print("[SongCache] $message");
    }
  }
  
  /// Close database connection
  Future<void> close() async {
    await _flushPendingWrites();
    await _database?.close();
    _database = null;
    _isInitialized = false;
  }
}

// ==============================================================================
// MARK: - CachedSongEntry
// ==============================================================================

/// Represents a cached song entry with metadata
class CachedSongEntry {
  final String path;
  final String folderName;
  final int lastModified;
  final String title;
  final String album;
  final String artist;
  final int duration;
  final Uint8List? pictureData;
  final String year;
  final String genre;
  final int fileSize;

  CachedSongEntry({
    required this.path,
    required this.folderName,
    required this.lastModified,
    required this.title,
    required this.album,
    required this.artist,
    required this.duration,
    this.pictureData,
    required this.year,
    required this.genre,
    required this.fileSize,
  });

  // ============================================================================
  // MARK: - Database Serialization
  // ============================================================================
  
  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'folderName': folderName,
      'lastModified': lastModified,
      'fileSize': fileSize,
      'title': title,
      'album': album,
      'artist': artist,
      'duration': duration,
      'pictureData': pictureData,
      'year': year,
      'genre': genre,
    };
  }
  
  factory CachedSongEntry.fromMap(Map<String, dynamic> map) {
    return CachedSongEntry(
      path: map['path'] as String,
      folderName: map['folderName'] as String,
      lastModified: map['lastModified'] as int,
      title: map['title'] as String,
      album: map['album'] as String,
      artist: map['artist'] as String,
      duration: map['duration'] as int,
      pictureData: map['pictureData'] as Uint8List?,
      year: map['year'] as String,
      genre: map['genre'] as String,
      fileSize: map['fileSize'] as int,
    );
  }

  // ============================================================================
  // MARK: - Conversion Methods
  // ============================================================================
  
  /// Create a Music object from this cached entry
  Music toMusic({required bool isFavorite}) {
    return Music(
      path: path,
      folderName: folderName,
      lastModified: DateTime.fromMillisecondsSinceEpoch(lastModified),
      title: title,
      album: album,
      artist: artist,
      duration: duration,
      picture: pictureData,
      year: year,
      genre: genre,
      size: fileSize,
      isFavorite: isFavorite,
    );
  }

  /// Create a cache entry from a Music object
  static CachedSongEntry fromMusic(Music music) {
    return CachedSongEntry(
      path: music.path,
      folderName: music.folderName,
      lastModified: music.lastModified.millisecondsSinceEpoch,
      title: music.title,
      album: music.album,
      artist: music.artist,
      duration: music.duration,
      pictureData: music.picture,
      year: music.year,
      genre: music.genre,
      fileSize: music.size,
    );
  }
}