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
    await PlaylistManager.addSongToPlaylist(playlistName, song.title);
    if (!song.playlists.contains(playlistName)) {
      song.playlists.add(playlistName);
    }
    _internalNotifyListeners();
  }

  Future<void> removeSongFromPlaylist(String playlistName, Music song) async {
    await PlaylistManager.removeSongFromPlaylist(playlistName, song.title);
    song.playlists.remove(playlistName);
    _internalNotifyListeners();
  }

  List<Music> getPlaylistSongs(String playlistName) {
    List<String> songTitles = PlaylistManager.getPlaylistSongs(playlistName);
    return _allSongs.where((song) => songTitles.contains(song.title)).toList();
  }

  Future<void> refreshPlaylists() async {
    await PlaylistManager.load();
    // After reloading playlists, update the song objects
    for (var song in _allSongs) {
        song.playlists.clear();
        for (var playlistName in playlists) {
            if (PlaylistManager.getPlaylistSongs(playlistName).contains(song.title)) {
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
}
