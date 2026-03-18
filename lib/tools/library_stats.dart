/// library_stats.dart
/// Computes aggregate statistics from the user's music library.

import 'dart:convert';
import 'dart:io';
import 'package:blossom/audio/nplayer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class ArtistStat {
  final String name;
  final int songCount;
  final int totalDurationMs;
  final Set<String> albums;

  const ArtistStat({
    required this.name,
    required this.songCount,
    required this.totalDurationMs,
    required this.albums,
  });

  String get formattedDuration => _formatDuration(totalDurationMs);
  int get albumCount => albums.length;
}

class AlbumStat {
  final String name;
  final String artist;
  final int songCount;
  final int totalDurationMs;
  final String year;

  const AlbumStat({
    required this.name,
    required this.artist,
    required this.songCount,
    required this.totalDurationMs,
    required this.year,
  });

  String get formattedDuration => _formatDuration(totalDurationMs);
}

class GenreStat {
  final String name;
  final int songCount;
  final double percentage;

  const GenreStat({
    required this.name,
    required this.songCount,
    required this.percentage,
  });
}

class YearStat {
  final String year;
  final int songCount;

  const YearStat({required this.year, required this.songCount});
}

class LibraryStats {
  // Overview
  final int totalSongs;
  final int totalDurationMs;
  final int totalSizeBytes;
  final int totalAlbums;
  final int totalArtists;
  final int totalGenres;
  final int favoritesCount;

  // Top lists
  final List<ArtistStat> topArtists;
  final List<AlbumStat> topAlbums;
  final List<GenreStat> genreBreakdown;
  final List<YearStat> songsByYear;

  // Extremes
  final Music? longestSong;
  final Music? shortestSong;
  final Music? largestFile;
  final Music? smallestFile;

  // Favorites
  final List<Music> topFavorites;

  // Folder breakdown
  final Map<String, int> songsByFolder;

  final DateTime generatedAt;

  const LibraryStats({
    required this.totalSongs,
    required this.totalDurationMs,
    required this.totalSizeBytes,
    required this.totalAlbums,
    required this.totalArtists,
    required this.totalGenres,
    required this.favoritesCount,
    required this.topArtists,
    required this.topAlbums,
    required this.genreBreakdown,
    required this.songsByYear,
    required this.longestSong,
    required this.shortestSong,
    required this.largestFile,
    required this.smallestFile,
    required this.topFavorites,
    required this.songsByFolder,
    required this.generatedAt,
  });

  String get formattedTotalDuration => _formatDuration(totalDurationMs);
  String get formattedTotalSize => _formatSize(totalSizeBytes);

  // ---------------------------------------------------------------------------
  // Factory – compute stats from an NPlayer instance
  // ---------------------------------------------------------------------------

  factory LibraryStats.compute(NPlayer player) {
    final songs = player.allSongs;
    if (songs.isEmpty) {
      return LibraryStats(
        totalSongs: 0,
        totalDurationMs: 0,
        totalSizeBytes: 0,
        totalAlbums: 0,
        totalArtists: 0,
        totalGenres: 0,
        favoritesCount: 0,
        topArtists: [],
        topAlbums: [],
        genreBreakdown: [],
        songsByYear: [],
        longestSong: null,
        shortestSong: null,
        largestFile: null,
        smallestFile: null,
        topFavorites: [],
        songsByFolder: {},
        generatedAt: DateTime.now(),
      );
    }

    // --- Overview totals ---
    final totalDuration = songs.fold<int>(0, (sum, s) => sum + s.duration);
    final totalSize = songs.fold<int>(0, (sum, s) => sum + s.size);
    final favorites = songs.where((s) => s.isFavorite).toList();

    // --- Artists ---
    final artistMap = <String, _ArtistAccum>{};
    for (final s in songs) {
      final key = s.artist.isNotEmpty ? s.artist : 'Unknown Artist';
      artistMap.putIfAbsent(key, () => _ArtistAccum(key));
      artistMap[key]!.add(s);
    }
    final topArtists = artistMap.values
        .map((a) => ArtistStat(
              name: a.name,
              songCount: a.songCount,
              totalDurationMs: a.totalDuration,
              albums: a.albums,
            ))
        .toList()
      ..sort((a, b) => b.songCount.compareTo(a.songCount));

    // --- Albums ---
    final albumMap = <String, _AlbumAccum>{};
    for (final s in songs) {
      final key = '${s.album}__${s.artist}';
      albumMap.putIfAbsent(key, () => _AlbumAccum(s.album, s.artist, s.year));
      albumMap[key]!.add(s);
    }
    final topAlbums = albumMap.values
        .map((a) => AlbumStat(
              name: a.name.isNotEmpty ? a.name : 'Unknown Album',
              artist: a.artist.isNotEmpty ? a.artist : 'Unknown Artist',
              songCount: a.songCount,
              totalDurationMs: a.totalDuration,
              year: a.year,
            ))
        .toList()
      ..sort((a, b) => b.songCount.compareTo(a.songCount));

    // --- Genres ---
    final genreMap = <String, int>{};
    for (final s in songs) {
      final g = s.genre.isNotEmpty ? s.genre : 'Unknown';
      genreMap[g] = (genreMap[g] ?? 0) + 1;
    }
    final genreList = genreMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final genreBreakdown = genreList
        .map((e) => GenreStat(
              name: e.key,
              songCount: e.value,
              percentage: (e.value / songs.length) * 100,
            ))
        .toList();

    // --- Years ---
    final yearMap = <String, int>{};
    for (final s in songs) {
      final y = s.year.isNotEmpty ? s.year : 'Unknown';
      yearMap[y] = (yearMap[y] ?? 0) + 1;
    }
    final songsByYear = yearMap.entries
        .map((e) => YearStat(year: e.key, songCount: e.value))
        .toList()
      ..sort((a, b) {
        final aIsNum = int.tryParse(a.year) != null;
        final bIsNum = int.tryParse(b.year) != null;
        if (aIsNum && bIsNum) return b.year.compareTo(a.year);
        if (aIsNum) return -1;
        if (bIsNum) return 1;
        return a.year.compareTo(b.year);
      });

    // --- Extremes ---
    final sorted = List<Music>.from(songs);
    final longestSong = sorted.reduce((a, b) => a.duration > b.duration ? a : b);
    final shortestSong = sorted.reduce((a, b) => a.duration < b.duration ? a : b);
    final largestFile = sorted.reduce((a, b) => a.size > b.size ? a : b);
    final smallestFile = sorted.reduce((a, b) => a.size < b.size ? a : b);

    // --- Folders ---
    final folderMap = <String, int>{};
    for (final s in songs) {
      final f = s.folderName.isNotEmpty ? s.folderName : 'Root';
      folderMap[f] = (folderMap[f] ?? 0) + 1;
    }

    return LibraryStats(
      totalSongs: songs.length,
      totalDurationMs: totalDuration,
      totalSizeBytes: totalSize,
      totalAlbums: albumMap.length,
      totalArtists: artistMap.length,
      totalGenres: genreMap.length,
      favoritesCount: favorites.length,
      topArtists: topArtists,
      topAlbums: topAlbums,
      genreBreakdown: genreBreakdown,
      songsByYear: songsByYear,
      longestSong: longestSong,
      shortestSong: shortestSong,
      largestFile: largestFile,
      smallestFile: smallestFile,
      topFavorites: favorites.take(20).toList(),
      songsByFolder: Map.fromEntries(
        folderMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
      ),
      generatedAt: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Export helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() {
    return {
      'generatedAt': generatedAt.toIso8601String(),
      'overview': {
        'totalSongs': totalSongs,
        'totalDuration': formattedTotalDuration,
        'totalDurationMs': totalDurationMs,
        'totalSize': formattedTotalSize,
        'totalSizeBytes': totalSizeBytes,
        'totalAlbums': totalAlbums,
        'totalArtists': totalArtists,
        'totalGenres': totalGenres,
        'favoritesCount': favoritesCount,
      },
      'topArtists': topArtists
          .take(20)
          .map((a) => {
                'name': a.name,
                'songCount': a.songCount,
                'albumCount': a.albumCount,
                'totalDuration': a.formattedDuration,
              })
          .toList(),
      'topAlbums': topAlbums
          .take(20)
          .map((a) => {
                'name': a.name,
                'artist': a.artist,
                'songCount': a.songCount,
                'totalDuration': a.formattedDuration,
                'year': a.year,
              })
          .toList(),
      'genreBreakdown': genreBreakdown
          .map((g) => {
                'genre': g.name,
                'songCount': g.songCount,
                'percentage': double.parse(g.percentage.toStringAsFixed(1)),
              })
          .toList(),
      'songsByYear': songsByYear
          .map((y) => {'year': y.year, 'songCount': y.songCount})
          .toList(),
      'extremes': {
        'longestSong': longestSong != null
            ? {'title': longestSong!.title, 'artist': longestSong!.artist, 'duration': _formatDuration(longestSong!.duration)}
            : null,
        'shortestSong': shortestSong != null
            ? {'title': shortestSong!.title, 'artist': shortestSong!.artist, 'duration': _formatDuration(shortestSong!.duration)}
            : null,
        'largestFile': largestFile != null
            ? {'title': largestFile!.title, 'artist': largestFile!.artist, 'size': _formatSize(largestFile!.size)}
            : null,
        'smallestFile': smallestFile != null
            ? {'title': smallestFile!.title, 'artist': smallestFile!.artist, 'size': _formatSize(smallestFile!.size)}
            : null,
      },
      'topFavorites': topFavorites
          .map((s) => {'title': s.title, 'artist': s.artist, 'album': s.album})
          .toList(),
      'songsByFolder': songsByFolder,
    };
  }

  String toCsv() {
    final buf = StringBuffer();

    buf.writeln('=== BLOSSOM LIBRARY STATS ===');
    buf.writeln('Generated at,${generatedAt.toIso8601String()}');
    buf.writeln();

    buf.writeln('--- OVERVIEW ---');
    buf.writeln('Total Songs,$totalSongs');
    buf.writeln('Total Duration,$formattedTotalDuration');
    buf.writeln('Total Size,$formattedTotalSize');
    buf.writeln('Total Albums,$totalAlbums');
    buf.writeln('Total Artists,$totalArtists');
    buf.writeln('Total Genres,$totalGenres');
    buf.writeln('Favorites,$favoritesCount');
    buf.writeln();

    buf.writeln('--- TOP ARTISTS ---');
    buf.writeln('Rank,Artist,Songs,Albums,Total Duration');
    for (var i = 0; i < topArtists.take(20).length; i++) {
      final a = topArtists[i];
      buf.writeln('${i + 1},${_csvEscape(a.name)},${a.songCount},${a.albumCount},${a.formattedDuration}');
    }
    buf.writeln();

    buf.writeln('--- TOP ALBUMS ---');
    buf.writeln('Rank,Album,Artist,Songs,Total Duration,Year');
    for (var i = 0; i < topAlbums.take(20).length; i++) {
      final a = topAlbums[i];
      buf.writeln('${i + 1},${_csvEscape(a.name)},${_csvEscape(a.artist)},${a.songCount},${a.formattedDuration},${a.year}');
    }
    buf.writeln();

    buf.writeln('--- GENRE BREAKDOWN ---');
    buf.writeln('Rank,Genre,Songs,Percentage');
    for (var i = 0; i < genreBreakdown.length; i++) {
      final g = genreBreakdown[i];
      buf.writeln('${i + 1},${_csvEscape(g.name)},${g.songCount},${g.percentage.toStringAsFixed(1)}%');
    }
    buf.writeln();

    buf.writeln('--- SONGS BY YEAR ---');
    buf.writeln('Year,Songs');
    for (final y in songsByYear) {
      buf.writeln('${y.year},${y.songCount}');
    }
    buf.writeln();

    buf.writeln('--- EXTREMES ---');
    if (longestSong != null) {
      buf.writeln('Longest Song,${_csvEscape(longestSong!.title)},${_csvEscape(longestSong!.artist)},${_formatDuration(longestSong!.duration)}');
    }
    if (shortestSong != null) {
      buf.writeln('Shortest Song,${_csvEscape(shortestSong!.title)},${_csvEscape(shortestSong!.artist)},${_formatDuration(shortestSong!.duration)}');
    }
    if (largestFile != null) {
      buf.writeln('Largest File,${_csvEscape(largestFile!.title)},${_csvEscape(largestFile!.artist)},${_formatSize(largestFile!.size)}');
    }
    if (smallestFile != null) {
      buf.writeln('Smallest File,${_csvEscape(smallestFile!.title)},${_csvEscape(smallestFile!.artist)},${_formatSize(smallestFile!.size)}');
    }
    buf.writeln();

    buf.writeln('--- SONGS BY FOLDER ---');
    buf.writeln('Folder,Songs');
    for (final entry in songsByFolder.entries) {
      buf.writeln('${_csvEscape(entry.key)},${entry.value}');
    }

    return buf.toString();
  }

  Future<void> exportAndShare(String format) async {
    final timestamp = generatedAt.toIso8601String().replaceAll(':', '-').substring(0, 19);
    final dir = await getTemporaryDirectory();

    if (format == 'json') {
      final file = File('${dir.path}/blossom_stats_$timestamp.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(toJson()));
      await Share.shareXFiles([XFile(file.path)], subject: 'Blossom Library Stats');
    } else if (format == 'csv') {
      final file = File('${dir.path}/blossom_stats_$timestamp.csv');
      await file.writeAsString(toCsv());
      await Share.shareXFiles([XFile(file.path)], subject: 'Blossom Library Stats');
    }
  }
}

// ---------------------------------------------------------------------------
// Private accumulators
// ---------------------------------------------------------------------------

class _ArtistAccum {
  final String name;
  int songCount = 0;
  int totalDuration = 0;
  final Set<String> albums = {};

  _ArtistAccum(this.name);

  void add(Music s) {
    songCount++;
    totalDuration += s.duration;
    if (s.album.isNotEmpty) albums.add(s.album);
  }
}

class _AlbumAccum {
  final String name;
  final String artist;
  final String year;
  int songCount = 0;
  int totalDuration = 0;

  _AlbumAccum(this.name, this.artist, this.year);

  void add(Music s) {
    songCount++;
    totalDuration += s.duration;
  }
}

// ---------------------------------------------------------------------------
// Global formatting helpers
// ---------------------------------------------------------------------------

String _formatDuration(int ms) {
  final total = Duration(milliseconds: ms);
  final h = total.inHours;
  final m = total.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = total.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
}

String _csvEscape(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}