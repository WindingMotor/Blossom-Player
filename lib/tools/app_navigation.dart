import 'package:blossom/audio/nplayer.dart';
import 'package:flutter/foundation.dart';

enum AppNavigationTarget { album, artist, playlist }

class AppNavigationRequest {
  final AppNavigationTarget target;
  final Music? song;
  final String? name;

  const AppNavigationRequest._({
    required this.target,
    this.song,
    this.name,
  });

  const AppNavigationRequest.album(Music song)
      : this._(target: AppNavigationTarget.album, song: song);

  const AppNavigationRequest.artist(String artist)
      : this._(target: AppNavigationTarget.artist, name: artist);

  const AppNavigationRequest.playlist(String playlist)
      : this._(target: AppNavigationTarget.playlist, name: playlist);
}

class AppNavigationController extends ChangeNotifier {
  AppNavigationRequest? _pendingRequest;

  AppNavigationRequest? takeRequest() {
    final request = _pendingRequest;
    _pendingRequest = null;
    return request;
  }

  void openAlbum(Music song) {
    _pendingRequest = AppNavigationRequest.album(song);
    notifyListeners();
  }

  void openArtist(String artist) {
    _pendingRequest = AppNavigationRequest.artist(artist);
    notifyListeners();
  }

  void openPlaylist(String playlist) {
    _pendingRequest = AppNavigationRequest.playlist(playlist);
    notifyListeners();
  }
}
