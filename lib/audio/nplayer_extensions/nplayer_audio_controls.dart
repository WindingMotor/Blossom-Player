part of '../nplayer.dart';

extension NPlayerAudioControls on NPlayer {
  // MARK: Settings and Controls
  
  Future<void> setVolume(double newVolume) async {
    await _audioPlayer.setVolume(newVolume);
    await Settings.setVolume(newVolume);
    _internalNotifyListeners();
  }

// Add this to nplayer_audio_controls.dart extension
Future<void> seek(Duration position) async {
  try {
    await _audioPlayer.seek(position);
    _currentPosition = position;
    _internalNotifyListeners(); // Update UI immediately
    _log("Seeked to position: ${position.inMilliseconds}ms");
  } catch (e) {
    _log("Error seeking: $e");
  }
}

  Future<void> setRepeatMode(String mode) async {
    _repeatMode = mode;
    await Settings.setRepeatMode(mode);
    _internalNotifyListeners();
  }
}
