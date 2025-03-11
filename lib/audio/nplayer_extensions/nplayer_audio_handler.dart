import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:blossom/audio/nplayer.dart';
import 'package:blossom/tools/settings.dart';
import 'package:path_provider/path_provider.dart';

class CustomAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player;
  final NPlayer _nPlayer;
  late final AudioSession _audioSession;
  bool _hasAudioFocus = false;
  bool _isInitializing = false;
  Timer? _positionTimer;
  bool _completionHandled = false;

  CustomAudioHandler(this._player, this._nPlayer) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      _audioSession = await AudioSession.instance;
      
      // Enhanced completion detection with multiple fallbacks
      _player.onPlayerComplete.listen((_) async {
        if (_completionHandled) return;
        _completionHandled = true;
        
        print('AudioHandler: Song completed, triggering next song');
        try {
          // Update processing state to completed
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.completed,
          ));
          
          // Delay to ensure state propagation
          await Future.delayed(const Duration(milliseconds: 200));
          
          // Trigger next song through NPlayer
          await _nPlayer.handleSongCompletion();
          
          // Reset completion flag after successful handling
          await Future.delayed(const Duration(milliseconds: 500));
          _completionHandled = false;
          
        } catch (e) {
          print('AudioHandler: Error handling song completion: $e');
          _completionHandled = false;
        }
      });
      
      if (Platform.isAndroid) {
        await _audioSession.configure(AudioSessionConfiguration.music().copyWith(
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
            flags: AndroidAudioFlags.none,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          // When true, the app will pause when audio focus is lost (e.g., during a phone call)
          // When false, the app will continue playing but with reduced volume (ducking)
          androidWillPauseWhenDucked: false,
        ));
        
        // Force audio session activation
        try {
          await _audioSession.setActive(true, 
            avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation);
          _hasAudioFocus = true;
        } catch (e) {
          print("Error activating audio session: $e");
        }
      } else {
        await _audioSession.configure(AudioSessionConfiguration.music());
      }

// Update the interruption listener in _initialize()
_audioSession.interruptionEventStream.listen((event) async {
  try {
    print('AudioHandler: Audio interruption - begin: ${event.begin}, type: ${event.type}');
    
    if (event.begin) {
      if (Platform.isAndroid && event.type == AudioInterruptionType.duck) {
        await _player.setVolume(0.2);
      } else {
        _hasAudioFocus = false;
        await _nPlayer.pauseSong(isInterruption: true);
      }
    } else {
      // Interruption ended
      if (Platform.isAndroid && event.type == AudioInterruptionType.duck) {
        await _player.setVolume(Settings.volume);
      } else if (_nPlayer.isPausedByInterruption) {
        print('AudioHandler: Trying to resume after interruption');
        await Future.delayed(const Duration(milliseconds: 1000));
        
        // Try to regain focus
        final focusRequest = await _audioSession.setActive(true);
        if (focusRequest) {
          _hasAudioFocus = true;
          await _nPlayer.resumeSong();
          print('AudioHandler: Successfully resumed after interruption');
        } else {
          print('AudioHandler: Could not regain focus after interruption');
        }
      }
    }
  } catch (e) {
    print('AudioHandler: Error handling interruption: $e');
  }
});

      _audioSession.becomingNoisyEventStream.listen((_) {
        _nPlayer.pauseSong();
      });

      // Enhanced state monitoring with position tracking
   _player.onPlayerStateChanged.listen((state) {
  try {
    final isPlaying = state == PlayerState.playing;
    
    // Add debouncing for rapid state changes
    Timer(const Duration(milliseconds: 100), () {
      playbackState.add(playbackState.value.copyWith(
        playing: isPlaying,
        processingState: AudioProcessingState.ready,
        controls: [
          MediaControl.skipToPrevious,
          isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
      ));
    });
    
    // Start/stop position timer based on playback state
    if (isPlaying) {
      _startPositionTimer();
    } else {
      _stopPositionTimer();
    }
    
    if (Platform.isAndroid) {
      // Add delay before forcing media buttons to avoid rapid calls
      Timer(const Duration(milliseconds: 200), () {
        AudioService.androidForceEnableMediaButtons();
      });
    }
  } catch (e) {
    print('AudioHandler: Error in onPlayerStateChanged: $e');
  }
});

      _player.onDurationChanged.listen((duration) {
        try {
          if (mediaItem.value != null) {
            mediaItem.add(mediaItem.value!.copyWith(duration: duration));
          }
        } catch (e) {
          print('AudioHandler: Error in onDurationChanged: $e');
        }
      });

      // Position updates for seek bar
      _player.onPositionChanged.listen((position) async {
        try {
          playbackState.add(playbackState.value.copyWith(
            updatePosition: position,
          ));
          
          // Backup completion detection
          final duration = mediaItem.value?.duration ?? Duration.zero;
          if (duration.inMilliseconds > 0) {
            final timeRemaining = duration - position;
            if (timeRemaining.inMilliseconds <= 100 && 
                timeRemaining.inMilliseconds > 0 &&
                !_completionHandled) {
              print('AudioHandler: Near end detected, preparing completion');
              // Set a timer for the exact completion moment
              Timer(timeRemaining, () async {
                if (!_completionHandled && _player.state == PlayerState.playing) {
                  print('AudioHandler: Backup completion triggered');
                  _completionHandled = true;
                  await _nPlayer.handleSongCompletion();
                  await Future.delayed(const Duration(milliseconds: 500));
                  _completionHandled = false;
                }
              });
            }
          }
        } catch (e) {
          print('AudioHandler: Error in onPositionChanged: $e');
        }
      });

    } catch (e) {
      print('AudioHandler: Error during initialization: $e');
    } finally {
      _isInitializing = false;
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      // Keep the service alive during playback
      if (_player.state == PlayerState.playing) {
        final position = await _player.getCurrentPosition();
        if (position != null) {
          playbackState.add(playbackState.value.copyWith(
            updatePosition: position,
          ));
        }
      }
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }
  @override
Future<void> play() async {
  print('AudioHandler: play called from external control');
  
  if (_player.state == PlayerState.playing) return;
  
  try {
    // For external calls, be more aggressive about getting audio focus
    if (!_hasAudioFocus) {
      print('AudioHandler: Requesting audio focus for external play');
      
      // First, try to reconfigure the session
      await _audioSession.configure(AudioSessionConfiguration.music().copyWith(
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
          flags: AndroidAudioFlags.none,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain, // Use stronger focus gain
        androidWillPauseWhenDucked: false, // Don't auto-pause
      ));
      
      // Request focus with retry logic
      bool focusGranted = false;
      for (int attempt = 0; attempt < 3; attempt++) {
        await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
        focusGranted = await _audioSession.setActive(true);
        if (focusGranted) break;
        print('AudioHandler: Focus attempt ${attempt + 1} failed, retrying...');
      }
      
      if (!focusGranted) {
        print('AudioHandler: Could not gain audio focus after 3 attempts');
        // Continue anyway - some external calls need to work without focus
      } else {
        _hasAudioFocus = true;
        print('AudioHandler: Audio focus granted');
      }
    }
    
    // Call NPlayer's resume method directly instead of _player.resume()
    print('AudioHandler: Calling NPlayer resumeSong()');
    await _nPlayer.resumeSong();
    
    // Update state after successful resume
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.pause,
        MediaControl.skipToNext,
      ],
    ));
    
    if (Platform.isAndroid) {
      Timer(const Duration(milliseconds: 300), () {
        AudioService.androidForceEnableMediaButtons();
      });
    }
  } catch (e) {
    print('AudioHandler: Error in play(): $e');
  }
}



  @override
  Future<void> pause() async {
    print("AudioHandler: pause called");
    
    if (_player.state != PlayerState.playing) return;
    
    try {
      await _player.pause();
      
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.skipToNext,
        ],
      ));
      
      if (Platform.isAndroid) {
        await AudioService.androidForceEnableMediaButtons();
      }
    } catch (e) {
      print('AudioHandler: Error in pause(): $e');
    }
  }

@override
Future<void> seek(Duration position) async {
  print('AudioHandler: seek called to position: ${position.inMilliseconds}ms');
  try {
    // Seek through the player directly for immediate response
    await _player.seek(position);
    
    // Update the AudioHandler's state immediately
    playbackState.add(playbackState.value.copyWith(
      updatePosition: position,
    ));
    
    // Also call NPlayer's seek to keep states in sync
    await _nPlayer.seek(position);
    
    print('AudioHandler: seek completed to ${position.inMilliseconds}ms');
  } catch (e) {
    print('AudioHandler: Error in seek(): $e');
  }
}


  @override
  Future<void> stop() async {
    try {
      _stopPositionTimer();
      await _nPlayer.stopSong();
      if (Platform.isAndroid) {
        await _audioSession.setActive(false);
        _hasAudioFocus = false;
      }
    } catch (e) {
      print('AudioHandler: Error in stop(): $e');
    }
  }

  @override
  Future<void> skipToNext() async {
    try {
      if (!_hasAudioFocus) {
        final focusGranted = await _audioSession.setActive(true);
        if (!focusGranted) return;
        _hasAudioFocus = true;
      }
      await _nPlayer.nextSong();
    } catch (e) {
      print('AudioHandler: Error in skipToNext(): $e');
    }
  }

  @override  
  Future<void> skipToPrevious() async {
    try {
      if (!_hasAudioFocus) {
        final focusGranted = await _audioSession.setActive(true);
        if (!focusGranted) return;
        _hasAudioFocus = true;
      }
      
      if (Settings.previousForShuffle) {
        await _nPlayer.shuffle();
      } else {
        await _nPlayer.previousSong();
      }
    } catch (e) {
      print('AudioHandler: Error in skipToPrevious(): $e');
    }
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    try {
      switch (button) {
        case MediaButton.media:
          if (_player.state == PlayerState.playing) {
            await _nPlayer.pauseSong();
          } else {
            await _nPlayer.resumeSong();
          }
          break;
        case MediaButton.next:
          await _nPlayer.nextSong();
          break;
        case MediaButton.previous:
          await _nPlayer.previousSong();
          break;
      }
    } catch (e) {
      print('AudioHandler: Error in click(): $e');
    }
  }

  // MARK: Media Item Management
  Future<void> updateMediaItemFromSong(Music song) async {
  Uri? artUri;
  
  try {
    if (song.picture != null && song.picture!.isNotEmpty) {
      // Always use file-based approach for OneUI 7 compatibility
      try {
        final tempDir = await getTemporaryDirectory();
        final artFile = File('${tempDir.path}/album_art_${song.path.hashCode.abs()}.jpg');
        
        // Write the image data to a temporary file
        await artFile.writeAsBytes(song.picture!);
        artUri = Uri.file(artFile.path);
        print('AudioHandler: Album art saved to: ${artFile.path}');
      } catch (fileError) {
        print('AudioHandler: Error saving album art file: $fileError');
        artUri = null;
      }
    }
  } catch (e) {
    print('AudioHandler: Error processing album art: $e');
    artUri = null;
  }

  final item = MediaItem(
    id: song.path,
    title: song.title.isNotEmpty ? song.title : 'Unknown Title',
    artist: song.artist.isNotEmpty ? song.artist : 'Unknown Artist',
    album: song.album.isNotEmpty ? song.album : 'Unknown Album',
    duration: Duration(milliseconds: song.duration),
    artUri: artUri,
    playable: true,
    displayTitle: song.title.isNotEmpty ? song.title : 'Unknown Title',
    displaySubtitle: song.artist.isNotEmpty ? song.artist : 'Unknown Artist',
    displayDescription: song.album.isNotEmpty ? song.album : 'Unknown Album',
  );
  
  mediaItem.add(item);
  _completionHandled = false;
}


  Future<void> dispose() async {
    try {
      _stopPositionTimer();
      if (_hasAudioFocus && Platform.isAndroid) {
        await _audioSession.setActive(false);
        _hasAudioFocus = false;
      }
    } catch (e) {
      print('AudioHandler: Error during dispose: $e');
    }
  }
}
