part of '../nplayer.dart';

extension NPlayerPlayback on NPlayer {
  // MARK: Core Playback Logic

  /// Centralized method to handle starting playback of any song queue.
  /// Centralized method to handle starting playback of any song queue.
  Future<void> _startPlayback(List<Music> queue, int startIndex) async {
    // Ensure AudioHandler is initialized before proceeding
    await _ensureInitialized();

    if (_audioHandler == null) {
      Log.e(LogTag.playback,
          'AudioHandler not initialized, cannot start playback');
      return;
    }

    if (startIndex < 0 || startIndex >= queue.length) {
      Log.w(LogTag.playback,
          'Invalid start index: $startIndex — stopping playback');
      await stopSong();
      return;
    }

    _playingSongs = List.from(queue);
    _currentSongIndex = startIndex;
    _preShuffleQueue = null; // new queue — old un-shuffle snapshot is invalid
    final songToPlay = _playingSongs[startIndex];

    // Ensure media item is updated BEFORE starting playback
    await _audioHandler!.updateMediaItemFromSong(songToPlay);

    try {
      await _audioHandler!.ensureAudioFocus();
      await _audioPlayer.play(ap.DeviceFileSource(songToPlay.path));
      // A short delay and resume check can help on some platforms.
      Future.delayed(Duration(milliseconds: 100), () async {
        try {
          // Skip if the user paused/stopped in the meantime — otherwise this
          // would override their action.
          if (_isPlaying && _audioPlayer.state != ap.PlayerState.playing) {
            await _audioPlayer.resume();
          }
        } catch (e) {
          Log.w(LogTag.playback, 'Error in delayed resume check: $e');
        }
      });
      _isPlaying = true;
      _currentPosition = Duration.zero;
      await Settings.setLastPlayingSong(songToPlay.path);
      await Settings.setLastPlayingPosition(0);

      if (Settings.isPublicSharingEnabled) {
        updatePublicStatus(); // Update Railway server with new song
      }
    } catch (e) {
      Log.e(LogTag.playback, 'Error starting playback: $e');
      _isPlaying = false;
    } finally {
      _internalNotifyListeners();
    }
  }

  /// Restores the last playing song on startup (paused, ready to resume).
  /// Builds the same rotated queue [playSong] would have and preloads the
  /// source so the play button resumes exactly where the user left off.
  Future<void> _restoreLastPlayingSession() async {
    try {
      final lastPath = Settings.lastPlayingSong;
      if (lastPath == null || lastPath.isEmpty) return;

      final index = _sortedSongs.indexWhere((s) => s.path == lastPath);
      if (index == -1) return;
      if (!await File(lastPath).exists()) return;

      _playbackSource = const PlaybackSource(PlaybackSourceType.library);
      _playingSongs = [
        ..._sortedSongs.sublist(index),
        ..._sortedSongs.sublist(0, index)
      ];
      _currentSongIndex = 0;

      // Preload without playing so resumeSong() works immediately.
      await _audioPlayer.setSource(ap.DeviceFileSource(lastPath));

      // Seek to where the user left off (leave a 2s safety margin so we
      // never restore into the completion handler at the very end).
      final song = _playingSongs[0];
      final savedMs = Settings.lastPlayingPosition;
      final maxMs = song.duration > 2000 ? song.duration - 2000 : 0;
      final restoreMs = savedMs.clamp(0, maxMs);
      if (restoreMs > 0) {
        try {
          final restorePosition = Duration(milliseconds: restoreMs);
          await _audioPlayer.seek(restorePosition);
          _currentPosition = restorePosition;
          positionNotifier.value = restorePosition;
        } catch (e) {
          Log.w(LogTag.playback, 'Could not restore position: $e');
        }
      }

      await _audioHandler?.updateMediaItemFromSong(song);

      Log.i(LogTag.playback,
          'Restored last session: ${song.title} at ${restoreMs}ms (paused)');
    } catch (e) {
      Log.w(LogTag.playback, 'Could not restore last playing session: $e');
    }
  }

  // MARK: Playback Control

  /// Plays a song from the main sorted list, creating a new queue.
  Future<void> playSong(int sortedIndex) async {
    if (sortedIndex < 0 || sortedIndex >= _sortedSongs.length) {
      Log.w(LogTag.playback, 'Invalid sortedIndex: $sortedIndex');
      return;
    }
    _playbackSource = const PlaybackSource(PlaybackSourceType.library);
    final newQueue = [
      ..._sortedSongs.sublist(sortedIndex),
      ..._sortedSongs.sublist(0, sortedIndex)
    ];
    await _startPlayback(newQueue, 0);
  }

  /// Builds a shuffled queue from the whole (sorted/filtered) library and
  /// starts playing it. Used by the Home page "Shuffle All" action.
  Future<void> shuffleAll() async {
    if (_sortedSongs.isEmpty) return;
    _playbackSource = const PlaybackSource(PlaybackSourceType.library);
    final queue = List<Music>.from(_sortedSongs)..shuffle(_random);
    await _startPlayback(queue, 0);
  }

  /// Plays a specific song if it's in the current queue.
  Future<void> playSpecificSong(Music song) async {
    int index = _playingSongs.indexWhere((queued) => queued.path == song.path);
    if (index != -1) {
      await _startPlayback(_playingSongs, index);
    } else {
      Log.d(LogTag.playback, 'Song not found in current queue');
    }
  }

  Future<void> pauseSong({bool isInterruption = false}) async {
    if (_isPausing || !_isPlaying) return;
    _isPausing = true;
    Log.d(LogTag.playback, 'Pausing song');
    try {
      await _audioPlayer.pause();
      _isPlaying = false;
      _isPausedByInterruption = isInterruption;
      // Save the exact position so a restart resumes right here.
      Settings.setLastPlayingPosition(_currentPosition.inMilliseconds);
      _internalNotifyListeners();
    } catch (e) {
      Log.w(LogTag.playback, 'Error pausing song: $e');
    } finally {
      _isPausing = false;
    }
  }

  Future<void> resumeSong() async {
    if (_isResuming || _isPlaying) return;
    _isResuming = true;
    Log.d(LogTag.playback, 'Resuming song');
    try {
      await _audioHandler?.ensureAudioFocus();
      await _audioPlayer.resume();
      _isPlaying = true;
      _isPausedByInterruption = false;
      _internalNotifyListeners();
    } catch (e) {
      Log.w(LogTag.playback, 'Error resuming song: $e');
    } finally {
      _isResuming = false;
    }
  }

  Future<void> stopSong() async {
    if (_isStoppingInProgress) return;
    _isStoppingInProgress = true;
    Log.d(LogTag.playback, 'Stopping song');
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      _currentPosition = Duration.zero;
      _internalNotifyListeners();
    } catch (e) {
      Log.w(LogTag.playback, 'Error stopping song: $e');
    } finally {
      _isStoppingInProgress = false;
    }
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pauseSong();
    } else {
      if (_currentSongIndex != null) {
        await resumeSong();
      } else if (_sortedSongs.isNotEmpty) {
        await playSong(0);
      }
    }
  }

  Future<void> nextSong() async {
    if (_isChangingSong || _currentSongIndex == null || _playingSongs.isEmpty)
      return;
    _isChangingSong = true;
    try {
      int nextIndex;
      if (_repeatMode == 'all') {
        nextIndex = (_currentSongIndex! + 1) % _playingSongs.length;
      } else {
        nextIndex = _currentSongIndex! + 1;
        if (nextIndex >= _playingSongs.length) {
          await stopSong();
          return;
        }
      }
      await _startPlayback(_playingSongs, nextIndex);
    } finally {
      _isChangingSong = false;
    }
  }

  Future<void> previousSong() async {
    if (_isChangingSong || _currentSongIndex == null || _playingSongs.isEmpty)
      return;
    _isChangingSong = true;
    try {
      if (_currentPosition.inSeconds > 3) {
        await seek(Duration.zero);
      } else {
        int prevIndex = (_currentSongIndex! - 1 + _playingSongs.length) %
            _playingSongs.length;
        await _startPlayback(_playingSongs, prevIndex);
      }
    } finally {
      _isChangingSong = false;
    }
  }

  Future<void> handleSongCompletion() async {
    await _handleSongCompletion();
    _internalNotifyListeners();
  }

  Future<void> _handleSongCompletion() async {
    final Music? currentSong = getCurrentSong();
    if (currentSong != null) {
      await SongData.incrementPlayCount(currentSong.path);
    }

    if (_repeatMode == 'one' && _currentSongIndex != null) {
      await _startPlayback(_playingSongs, _currentSongIndex!);
    } else {
      await nextSong();
    }
  }

  // MARK: Group Playback

  Future<void> playAlbum(List<Music> albumSongs, Music selectedSong) async {
    Log.i(LogTag.playback, 'Playing album: ${selectedSong.album}');
    _playbackSource =
        PlaybackSource(PlaybackSourceType.album, name: selectedSong.album);
    int startIndex = albumSongs.indexOf(selectedSong);
    await _startPlayback(albumSongs, max(0, startIndex));
  }

  Future<void> playArtist(List<Music> artistSongs, Music selectedSong) async {
    Log.i(LogTag.playback, 'Playing artist: ${selectedSong.artist}');
    _playbackSource =
        PlaybackSource(PlaybackSourceType.artist, name: selectedSong.artist);
    int startIndex = artistSongs.indexOf(selectedSong);
    await _startPlayback(artistSongs, max(0, startIndex));
  }

  Future<void> playPlaylistFromIndex(
    List<Music> playlistSongs,
    int index, {
    String? playlistName,
  }) async {
    Log.i(LogTag.playback, 'Playing playlist from index: $index');
    _playbackSource =
        PlaybackSource(PlaybackSourceType.playlist, name: playlistName);
    await _startPlayback(playlistSongs, index);
  }

  // MARK: Queue Management

  /// Inserts [song] immediately after the current song.
  /// If nothing is queued, starts playing it as a new queue of one.
  Future<void> playNext(Music song) async {
    if (_playingSongs.isEmpty || _currentSongIndex == null) {
      _playbackSource = const PlaybackSource(PlaybackSourceType.library);
      await _startPlayback([song], 0);
      return;
    }

    final existing = _playingSongs.indexWhere((s) => s.path == song.path);
    if (existing == _currentSongIndex) return; // already playing

    // Move rather than duplicate — the queue UI keys tiles by path.
    if (existing != -1) {
      _playingSongs.removeAt(existing);
      if (existing < _currentSongIndex!) {
        _currentSongIndex = _currentSongIndex! - 1;
      }
    }

    final insertAt = (_currentSongIndex! + 1).clamp(0, _playingSongs.length);
    _playingSongs.insert(insertAt, song);
    _mirrorQueueAdd(song);
    Log.d(LogTag.playback, 'Play next: ${song.title}');
    _internalNotifyListeners();
  }

  // Keep the reversible-shuffle snapshot consistent with queue edits so
  // un-shuffling doesn't drop songs added (or resurrect songs removed)
  // while shuffled.
  void _mirrorQueueAdd(Music song) {
    final snapshot = _preShuffleQueue;
    if (snapshot != null && !snapshot.any((s) => s.path == song.path)) {
      snapshot.add(song);
    }
  }

  /// Appends [song] to the end of the queue.
  /// If nothing is queued, starts playing it as a new queue of one.
  Future<void> addToQueue(Music song) async {
    if (_playingSongs.isEmpty || _currentSongIndex == null) {
      _playbackSource = const PlaybackSource(PlaybackSourceType.library);
      await _startPlayback([song], 0);
      return;
    }

    final existing = _playingSongs.indexWhere((s) => s.path == song.path);
    if (existing == _currentSongIndex) return; // already playing

    // Move rather than duplicate — the queue UI keys tiles by path.
    if (existing != -1) {
      _playingSongs.removeAt(existing);
      if (existing < _currentSongIndex!) {
        _currentSongIndex = _currentSongIndex! - 1;
      }
    }

    _playingSongs.add(song);
    _mirrorQueueAdd(song);
    Log.d(LogTag.playback, 'Added to queue: ${song.title}');
    _internalNotifyListeners();
  }

  /// Removes [song] from the queue. The currently playing song can't be
  /// removed this way — skip or stop instead.
  void removeFromQueue(Music song) {
    final index = _playingSongs.indexWhere((s) => s.path == song.path);
    if (index == -1 || index == _currentSongIndex) return;

    _playingSongs.removeAt(index);
    if (_currentSongIndex != null && index < _currentSongIndex!) {
      _currentSongIndex = _currentSongIndex! - 1;
    }
    _preShuffleQueue?.removeWhere((s) => s.path == song.path);
    Log.d(LogTag.playback, 'Removed from queue: ${song.title}');
    _internalNotifyListeners();
  }

  /// Whether [song] is somewhere in the queue.
  bool isInQueue(Music song) =>
      _playingSongs.any((s) => s.path == song.path);

  Future<void> shuffle() async {
    if (_playingSongs.isEmpty) return;

    final behavior = Settings.shuffleBehavior;

    // Reversible mode: a second tap restores the pre-shuffle order.
    if (behavior == 'reversible' && _preShuffleQueue != null) {
      Log.d(LogTag.playback, 'Un-shuffling queue (reversible)');
      final original = _preShuffleQueue!;
      _preShuffleQueue = null;

      final currentSong = getCurrentSong();
      _playingSongs = List.from(original);
      _currentSongIndex = currentSong == null
          ? 0
          : _playingSongs
              .indexWhere((s) => s.path == currentSong.path)
              .clamp(0, _playingSongs.length - 1);
      _internalNotifyListeners();
      return;
    }

    Log.d(LogTag.playback, 'Shuffling queue ($behavior)');
    if (behavior == 'reversible') {
      _preShuffleQueue = List.from(_playingSongs);
    }

    Music? currentSong = getCurrentSong();

    // Create a copy of the playlist without the current song
    List<Music> songsToShuffle = List.from(_playingSongs);
    if (currentSong != null) {
      songsToShuffle.remove(currentSong);
    }

    if (behavior == 'smart') {
      _smartShuffle(songsToShuffle);
    } else {
      songsToShuffle.shuffle(_random);
    }

    // Reconstruct the playlist with current song at the beginning
    if (currentSong != null) {
      _playingSongs = [currentSong, ...songsToShuffle];
    } else {
      _playingSongs = songsToShuffle;
    }
    _currentSongIndex = 0;

    // Only reorder the queue — never start (or restart) playback here.
    // Shuffling while paused must not unpause or rewind the current song.
    _internalNotifyListeners();
  }

  /// Weighted shuffle: still random, but favorites and frequently played
  /// songs tend to land earlier in the queue.
  void _smartShuffle(List<Music> songs) {
    final keys = <String, double>{};
    for (final song in songs) {
      final playBonus =
          (SongData.getPlayCount(song.path).clamp(0, 20)) / 20.0; // 0..1
      final favoriteBonus = song.isFavorite ? 0.75 : 0.0;
      final weight = 1.0 + playBonus + favoriteBonus; // 1.0 .. 2.75
      // Smaller key → earlier position; higher weight shrinks the key.
      keys[song.path] = _random.nextDouble() / weight;
    }
    songs.sort((a, b) => keys[a.path]!.compareTo(keys[b.path]!));
  }

  void reorderPlayingSongs(List<Music> newOrder) {
    Log.d(LogTag.playback, 'Reordering queue');
    _preShuffleQueue = null; // manual reorder supersedes un-shuffle
    final currentSong = getCurrentSong();
    _playingSongs = newOrder;

    if (currentSong != null) {
      _currentSongIndex = _playingSongs.indexOf(currentSong);
    } else {
      _currentSongIndex = 0;
    }
    _internalNotifyListeners();
  }
}
