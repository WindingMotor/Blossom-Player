import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:blossom/audio/nplayer.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player;
  final NPlayer _nPlayer;

  MyAudioHandler(this._player, this._nPlayer) {
    _player.onPlayerStateChanged.listen((state) {
      playbackState.add(playbackState.value.copyWith(
        playing: state == PlayerState.playing,
        processingState: AudioProcessingState.ready,
      ));
    });

    _player.onDurationChanged.listen((duration) {
      mediaItem.add(mediaItem.value?.copyWith(duration: duration));
    });

    _player.onPositionChanged.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });
  }

  @override
  Future<void> play() => _nPlayer.resumeSong();

  @override
  Future<void> pause() => _nPlayer.pauseSong();

  @override
  Future<void> seek(Duration position) => _nPlayer.seek(position);

  @override
  Future<void> stop() => _nPlayer.stopSong();

  @override
  Future<void> skipToNext() => _nPlayer.nextSong();

  @override
  Future<void> skipToPrevious() => _nPlayer.previousSong();

  Future<void> updateMediaItem(MediaItem item) async {
    mediaItem.add(item);
  }
}