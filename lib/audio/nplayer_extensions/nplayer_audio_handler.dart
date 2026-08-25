import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:blossom/android_auto/android_auto_browser.dart';
import 'package:blossom/audio/nplayer.dart';
import 'package:blossom/tools/logger.dart';
import 'package:blossom/tools/settings.dart';
import 'package:path_provider/path_provider.dart';

class CustomAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player;
  final NPlayer _nPlayer;
  late final AudioSession _audioSession;
  bool _hasAudioFocus = false;
  bool _isInitializing = false;
  bool _completionHandled = false;
  Timer? _backupCompletionTimer;
  Timer? _stateDebounceTimer;
  Timer? _mediaItemDebounce;
  Timer? _interruptionDebounce;
  MediaItem? _pendingMediaItem;
  int _lastPositionBroadcastMs = 0;
  final List<StreamSubscription> _subscriptions = [];
  late final AndroidAutoBrowser _browser;

  CustomAudioHandler(this._player, this._nPlayer) {
    _browser = AndroidAutoBrowser(_nPlayer);
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      _audioSession = await AudioSession.instance;

      // Enhanced completion detection with multiple fallbacks
      _subscriptions.add(_player.onPlayerComplete.listen((_) async {
        if (_completionHandled) return;
        _completionHandled = true;

        Log.i(LogTag.audioHandler, 'Song completed — advancing to next');
        try {
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.completed,
          ));

          await Future.delayed(const Duration(milliseconds: 200));
          await _nPlayer.handleSongCompletion();

          await Future.delayed(const Duration(milliseconds: 500));
          _completionHandled = false;
        } catch (e) {
          Log.e(LogTag.audioHandler, 'Error handling song completion: $e');
          _completionHandled = false;
        }
      }));

      if (Platform.isAndroid) {
        await _audioSession
            .configure(AudioSessionConfiguration.music().copyWith(
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
            flags: AndroidAudioFlags.none,
          ),
          // GAIN (not gainTransient) identifies Blossom as the permanent media
          // player to Android Auto and prevents Spotify from reclaiming focus
          // after notifications or BT reconnects.
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ));
      } else {
        await _audioSession.configure(AudioSessionConfiguration.music());
      }

      _subscriptions
          .add(_audioSession.interruptionEventStream.listen((event) async {
        try {
          Log.d(LogTag.audioHandler,
              'Audio interruption — begin: ${event.begin}, type: ${event.type}');

          if (event.begin) {
            if (Platform.isAndroid &&
                event.type == AudioInterruptionType.duck) {
              final behavior = Settings.audioDuckBehavior;
              if (behavior == 'duck') {
                await _player.setVolume(Settings.duckVolume);
              } else if (behavior == 'pause') {
                await _nPlayer.pauseSong(isInterruption: true);
              }
              // 'ignore' → do nothing
            } else {
              _hasAudioFocus = false;
              // Debounce before pausing: Android Auto connection and audio
              // routing changes cause transient focus losses (~100–200ms) that
              // resolve on their own.  Only pause if the loss lasts > 400ms.
              _interruptionDebounce?.cancel();
              _interruptionDebounce =
                  Timer(const Duration(milliseconds: 150), () {
                _interruptionDebounce = null;
                if (!_hasAudioFocus) {
                  _nPlayer.pauseSong(isInterruption: true);
                }
              });
            }
          } else {
            // Interrupt ended — cancel any pending pause and restore state.
            _interruptionDebounce?.cancel();
            _interruptionDebounce = null;
            _hasAudioFocus = true;

            if (Platform.isAndroid &&
                event.type == AudioInterruptionType.duck) {
              if (Settings.audioDuckBehavior == 'duck') {
                await _player.setVolume(Settings.volume);
              } else if (Settings.audioDuckBehavior == 'pause' &&
                  _nPlayer.isPausedByInterruption) {
                if (Settings.autoResumeAfterInterruption) {
                  await _regainFocusAndResume(shortDelay: true);
                }
              }
            } else if (_nPlayer.isPausedByInterruption) {
              if (Settings.autoResumeAfterInterruption) {
                await _regainFocusAndResume(shortDelay: false);
              }
            }
          }
        } catch (e) {
          Log.w(LogTag.audioHandler, 'Error handling interruption: $e');
        }
      }));

      _subscriptions.add(_audioSession.becomingNoisyEventStream.listen((_) {
        if (Settings.pauseOnUnplug) _nPlayer.pauseSong();
      }));

      // Enhanced state monitoring with position tracking
      _subscriptions.add(_player.onPlayerStateChanged.listen((state) {
        try {
          final isPlaying = state == PlayerState.playing;

          // Add debouncing for rapid state changes
          _stateDebounceTimer?.cancel();
          _stateDebounceTimer = Timer(const Duration(milliseconds: 50), () {
            _stateDebounceTimer = null;
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

          if (Platform.isAndroid) {
            Timer(const Duration(milliseconds: 50), () {
              AudioService.androidForceEnableMediaButtons();
            });
          }
        } catch (e) {
          Log.w(LogTag.audioHandler, 'Error in onPlayerStateChanged: $e');
        }
      }));

      _subscriptions.add(_player.onDurationChanged.listen((duration) {
        try {
          // Merge duration into any pending item so we don't send two binder
          // transactions during a single song transition.
          final current = _pendingMediaItem ?? mediaItem.value;
          if (current != null) {
            _scheduleMediaItemUpdate(current.copyWith(duration: duration));
          }
        } catch (e) {
          Log.w(LogTag.audioHandler, 'Error in onDurationChanged: $e');
        }
      }));

      // Position updates — throttled to 1 Hz for binder broadcast.
      // audioplayers fires this every ~200ms; each playbackState.add() turns
      // into one oneway binder call per registered MediaController (head unit,
      // notification, lock screen...).  1 Hz is plenty for a seek bar.
      _subscriptions.add(_player.onPositionChanged.listen((position) async {
        try {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          if (nowMs - _lastPositionBroadcastMs >= 1000) {
            _lastPositionBroadcastMs = nowMs;
            playbackState.add(playbackState.value.copyWith(
              updatePosition: position,
            ));
          }

          // Backup completion detection (still runs at full rate)
          final duration = mediaItem.value?.duration ?? Duration.zero;
          if (duration.inMilliseconds > 0) {
            final timeRemaining = duration - position;
            if (timeRemaining.inMilliseconds <= 100 &&
                timeRemaining.inMilliseconds > 0 &&
                !_completionHandled &&
                _backupCompletionTimer == null) {
              Log.v(LogTag.audioHandler,
                  'Near end detected, arming backup timer');
              _backupCompletionTimer = Timer(timeRemaining, () async {
                _backupCompletionTimer = null;
                if (!_completionHandled &&
                    _player.state == PlayerState.playing) {
                  Log.i(LogTag.audioHandler, 'Backup completion triggered');
                  _completionHandled = true;
                  await _nPlayer.handleSongCompletion();
                  await Future.delayed(const Duration(milliseconds: 500));
                  _completionHandled = false;
                }
              });
            }
          }
        } catch (e) {
          Log.w(LogTag.audioHandler, 'Error in onPositionChanged: $e');
        }
      }));
    } catch (e) {
      Log.e(LogTag.audioHandler, 'Error during initialization: $e');
    } finally {
      _isInitializing = false;
    }
  }

  Future<bool> ensureAudioFocus() async {
    if (_hasAudioFocus) return true;

    try {
      if (Platform.isAndroid) {
        await _audioSession
            .configure(AudioSessionConfiguration.music().copyWith(
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
            flags: AndroidAudioFlags.none,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ));
      }

      bool focusGranted = false;
      for (int attempt = 0; attempt < 3; attempt++) {
        await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
        focusGranted = await _audioSession.setActive(true,
            avAudioSessionSetActiveOptions:
                AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation);
        if (focusGranted) break;
        Log.w(LogTag.audioHandler,
            'Focus attempt ${attempt + 1} failed, retrying...');
      }

      _hasAudioFocus = focusGranted;
      if (focusGranted) {
        Log.d(LogTag.audioHandler, 'Audio focus granted');
      } else {
        Log.w(
            LogTag.audioHandler, 'Could not gain audio focus after 3 attempts');
      }
      return focusGranted;
    } catch (e) {
      Log.w(LogTag.audioHandler, 'Error requesting audio focus: $e');
      return false;
    }
  }

  @override
  Future<void> play() async {
    Log.d(LogTag.audioHandler, 'play() called from external control');

    if (_player.state == PlayerState.playing) return;

    try {
      await ensureAudioFocus();

      await _nPlayer.resumeSong();

      // Update state after successful resume
      playbackState.add(playbackState.value.copyWith(
        playing: true,
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.pause,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 1, 2],
      ));

      if (Platform.isAndroid) {
        Timer(const Duration(milliseconds: 50), () {
          AudioService.androidForceEnableMediaButtons();
        });
      }
    } catch (e) {
      Log.e(LogTag.audioHandler, 'Error in play(): $e');
    }
  }

  @override
  Future<void> pause() async {
    Log.d(LogTag.audioHandler, 'pause() called');

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
        androidCompactActionIndices: const [0, 1, 2],
      ));

      if (Platform.isAndroid) {
        await AudioService.androidForceEnableMediaButtons();
      }
    } catch (e) {
      Log.e(LogTag.audioHandler, 'Error in pause(): $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    Log.v(LogTag.audioHandler, 'seek to ${position.inMilliseconds}ms');
    try {
      // NPlayer.seek() seeks the shared AudioPlayer and updates internal
      // position state — seeking _player here too would seek twice.
      await _nPlayer.seek(position);
      playbackState.add(playbackState.value.copyWith(updatePosition: position));
    } catch (e) {
      Log.w(LogTag.audioHandler, 'Error in seek(): $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _nPlayer.stopSong();
      if (Platform.isAndroid) {
        await _audioSession.setActive(false);
        _hasAudioFocus = false;
      }
    } catch (e) {
      Log.e(LogTag.audioHandler, 'Error in stop(): $e');
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
      Log.e(LogTag.audioHandler, 'Error in skipToNext(): $e');
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
      Log.e(LogTag.audioHandler, 'Error in skipToPrevious(): $e');
    }
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    try {
      // Re-assert focus before acting — BLE reconnects briefly lose focus,
      // which causes a queued button press to be ignored without this guard.
      if (!_hasAudioFocus) {
        final granted = await _audioSession.setActive(true);
        if (granted) _hasAudioFocus = true;
      }
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
      Log.e(LogTag.audioHandler, 'Error in click(): $e');
    }
  }

  // MARK: Media Item Management

  // Coalesces rapid mediaItem.add() calls (e.g. metadata + duration arriving
  // together on song change) into a single binder transaction to avoid
  // exhausting the kernel binder buffer (error -28 ENOSPC).
  void _scheduleMediaItemUpdate(MediaItem item) {
    _pendingMediaItem = item;
    _mediaItemDebounce?.cancel();
    _mediaItemDebounce = Timer(const Duration(milliseconds: 200), () {
      if (_pendingMediaItem != null) {
        mediaItem.add(_pendingMediaItem!);
        _pendingMediaItem = null;
      }
    });
  }

  Future<void> updateMediaItemFromSong(Music song) async {
    String? artCacheFilePath;

    try {
      if (song.picture != null && song.picture!.isNotEmpty) {
        try {
          final tempDir = await getTemporaryDirectory();
          final filename = 'album_art_${song.path.hashCode.abs()}.jpg';
          final artFile = File('${tempDir.path}/$filename');
          // Only re-write if file doesn't exist (avoids re-encoding on every play)
          if (!await artFile.exists()) {
            await artFile.writeAsBytes(song.picture!);
          }
          artCacheFilePath = artFile.path;
          Log.v(LogTag.audioHandler, 'Album art cached: $artCacheFilePath');
        } catch (fileError) {
          Log.w(LogTag.audioHandler, 'Error saving album art: $fileError');
        }
      } else {
        Log.v(LogTag.audioHandler, 'No album art for "${song.title}"');
      }
    } catch (e) {
      Log.w(LogTag.audioHandler, 'Error processing album art: $e');
    }

    final item = MediaItem(
      id: song.path,
      title: song.title.isNotEmpty ? song.title : 'Unknown Title',
      artist: song.artist.isNotEmpty ? song.artist : 'Unknown Artist',
      album: song.album.isNotEmpty ? song.album : 'Unknown Album',
      duration: Duration(milliseconds: song.duration),
      // Don't set artUri to a file:// path — setMetadata() in audio_service only
      // loads a bitmap for artCacheFile or content:// URIs.  A file:// URI falls
      // through to artBitmap = null, and Android Auto then sees no art.
      artUri: null,
      playable: true,
      displayTitle: song.title.isNotEmpty ? song.title : 'Unknown Title',
      displaySubtitle: song.artist.isNotEmpty ? song.artist : 'Unknown Artist',
      displayDescription: song.album.isNotEmpty ? song.album : 'Unknown Album',
      // artCacheFile triggers audio_service native BitmapFactory.decodeFile()
      // → sets METADATA_KEY_ALBUM_ART bitmap that Android Auto reads.
      extras:
          artCacheFilePath != null ? {'artCacheFile': artCacheFilePath} : null,
    );

    _scheduleMediaItemUpdate(item);
    _completionHandled = false;
    _backupCompletionTimer?.cancel();
    _backupCompletionTimer = null;
  }

  // Retry focus reclaim with back-off so Spotify can't sneak in during the gap.
  Future<void> _regainFocusAndResume({required bool shortDelay}) async {
    Log.d(LogTag.audioHandler, 'Attempting to regain focus and resume...');
    final delays = shortDelay
        ? [const Duration(milliseconds: 300)]
        : [
            const Duration(milliseconds: 600),
            const Duration(milliseconds: 1200),
            const Duration(milliseconds: 2000),
          ];

    for (final delay in delays) {
      await Future.delayed(delay);
      try {
        final granted = await _audioSession.setActive(true);
        if (granted) {
          _hasAudioFocus = true;
          await _nPlayer.resumeSong();
          Log.i(LogTag.audioHandler, 'Focus regained and playback resumed');
          return;
        }
      } catch (e) {
        Log.w(LogTag.audioHandler, 'Focus regain attempt failed: $e');
      }
    }
    Log.w(
        LogTag.audioHandler, 'Could not regain audio focus after interruption');
  }

  // ─── Android Auto / MediaBrowser support ────────────────────────────────
  // Full browsing logic lives in AndroidAutoBrowser; this class just delegates.

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId,
          [Map<String, dynamic>? options]) =>
      _browser.getChildren(parentMediaId, options);

  @override
  Future<MediaItem?> getMediaItem(String mediaId) =>
      _browser.getMediaItem(mediaId);

  @override
  Future<void> playFromMediaId(String mediaId,
      [Map<String, dynamic>? extras]) async {
    try {
      // Re-assert focus so audio routes to the car speakers, not the phone.
      if (!_hasAudioFocus) {
        final granted = await _audioSession.setActive(true);
        if (granted) _hasAudioFocus = true;
      }

      // Prefer playing from the queue (preserves queue position).
      // Fall back to sorted list for songs not currently in the queue.
      final queueIdx =
          _nPlayer.playingSongs.indexWhere((s) => s.path == mediaId);
      if (queueIdx != -1) {
        await _nPlayer.playSpecificSong(_nPlayer.playingSongs[queueIdx]);
        return;
      }

      final sortedIdx =
          _nPlayer.sortedSongs.indexWhere((s) => s.path == mediaId);
      if (sortedIdx != -1) {
        await _nPlayer.playSong(sortedIdx);
      }
    } catch (e) {
      Log.e(LogTag.audioHandler, 'playFromMediaId error: $e');
    }
  }

  Future<void> dispose() async {
    try {
      for (final sub in _subscriptions) {
        sub.cancel();
      }
      _subscriptions.clear();
      _backupCompletionTimer?.cancel();
      _backupCompletionTimer = null;
      _stateDebounceTimer?.cancel();
      _stateDebounceTimer = null;
      _mediaItemDebounce?.cancel();
      _mediaItemDebounce = null;
      _interruptionDebounce?.cancel();
      _interruptionDebounce = null;
      _pendingMediaItem = null;
      if (_hasAudioFocus && Platform.isAndroid) {
        await _audioSession.setActive(false);
        _hasAudioFocus = false;
      }
    } catch (e) {
      Log.w(LogTag.audioHandler, 'Error during dispose: $e');
    }
  }
}
