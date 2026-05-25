part of '../nplayer.dart';

/// Pre-computed album and folder groupings for the Albums page.
///
/// Built once inside _initialize() after _loadSongs() completes,
/// and rebuilt whenever songs are reloaded (e.g. Nextcloud sync).
/// The Albums page reads albumMap / folderMap directly — zero
/// computation on page open, no isolates needed.
extension NPlayerAlbums on NPlayer {
  void buildAlbumMaps() {
    final albums  = <String, List<Music>>{};
    final folders = <String, List<Music>>{};

    for (final song in _allSongs) {
      albums .putIfAbsent(song.album,      () => []).add(song);
      folders.putIfAbsent(song.folderName, () => []).add(song);
    }

    _albumMap  = albums;
    _folderMap = folders;
    Log.d(LogTag.playback, 'Built album maps: ${_albumMap.length} albums, ${_folderMap.length} folders');
  }
}