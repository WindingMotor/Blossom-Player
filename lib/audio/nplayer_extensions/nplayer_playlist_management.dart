part of '../nplayer.dart';

extension NPlayerPlaylistManagement on NPlayer {
  // MARK: Playlist Management
  Future<void> createPlaylist(String name) async {
    await PlaylistManager.createPlaylist(name);
    _internalNotifyListeners();
  }

  Future<void> deletePlaylist(String name) async {
    await PlaylistManager.deletePlaylist(name);
    _internalNotifyListeners();
  }

  Future<void> addSongToPlaylist(String playlistName, Music song) async {
    await PlaylistManager.addSongToPlaylist(playlistName, song.path);
    if (!song.playlists.contains(playlistName)) {
      song.playlists.add(playlistName);
    }
    _internalNotifyListeners();
  }

  Future<void> removeSongFromPlaylist(String playlistName, Music song) async {
    await PlaylistManager.removeSongFromPlaylist(playlistName, song.path);
    await PlaylistManager.removeSongFromPlaylist(playlistName, song.title);
    song.playlists.remove(playlistName);
    _internalNotifyListeners();
  }

  List<Music> getPlaylistSongs(String playlistName) {
    final songIds = PlaylistManager.getPlaylistSongs(playlistName);
    final songsByPath = {for (final song in _allSongs) song.path: song};
    return songIds.expand((id) {
      final byPath = songsByPath[id];
      if (byPath != null) return [byPath];

      // Backward compatibility for playlists saved before paths were used.
      return _allSongs.where((song) => song.title == id);
    }).toList();
  }

  Future<void> refreshPlaylists() async {
    await PlaylistManager.load();
    // After reloading playlists, update the song objects
    for (var song in _allSongs) {
      song.playlists.clear();
      for (var playlistName in playlists) {
        final ids = PlaylistManager.getPlaylistSongs(playlistName);
        if (ids.contains(song.path) || ids.contains(song.title)) {
          song.playlists.add(playlistName);
        }
      }
    }
    _internalNotifyListeners();
  }

  Future<void> setPlaylistImage(String playlistName, File imageFile) async {
    await PlaylistManager.setPlaylistImage(playlistName, imageFile);
    _internalNotifyListeners();
  }

  String? getPlaylistImagePath(String playlistName) {
    return PlaylistManager.getPlaylistImagePath(playlistName);
  }

  Future<void> reorderPlaylistSongs(
      String playlistName, List<Music> reorderedSongs) async {
    final songIds = reorderedSongs.map((song) => song.path).toList();
    await PlaylistManager.reorderSongs(playlistName, songIds);
    _internalNotifyListeners();
    Log.d(LogTag.playlist,
        'Reordered "$playlistName" (${reorderedSongs.length} songs)');
  }
}
