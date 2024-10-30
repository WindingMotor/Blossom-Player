import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:blossom/audio/nplayer.dart';
import 'package:blossom/tools/settings.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player;
  final NPlayer _nPlayer;
  late final AudioSession _audioSession;

  MyAudioHandler(this._player, this._nPlayer) {
    _initialize();
  }

  Future<void> _initialize() async {
    // Initialize the audio session
    _audioSession = await AudioSession.instance;
    await _audioSession.configure(AudioSessionConfiguration.music());

    // Listen to audio session interruptions
    _audioSession.interruptionEventStream.listen((event) {
      if (event.begin) {
        // An interruption has begun
        _nPlayer.pauseSong();
      } else {
        // An interruption has ended
        if (_nPlayer.isPausedByInterruption) {
          _nPlayer.resumeSong();
        }
      }
    });

    // Listen to audio session becoming noisy (e.g., headphones disconnected)
    _audioSession.becomingNoisyEventStream.listen((_) {
      _nPlayer.pauseSong();
    });

    // Existing listeners
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
Future<void> skipToPrevious() async {
  if (Settings.previousForShuffle) {
      await _nPlayer.shuffle();
    } else {
    await _nPlayer.previousSong();
  }
}


  Future<void> updateMediaItem(MediaItem item) async {
    mediaItem.add(item);
  }
}