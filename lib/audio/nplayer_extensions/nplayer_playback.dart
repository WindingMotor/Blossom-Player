part of '../nplayer.dart';

extension NPlayerPlayback on NPlayer {
  // MARK: Core Playback Logic
    
    /// Centralized method to handle starting playback of any song queue.
  Future<void> _startPlayback(List<Music> queue, int startIndex) async {
    // Ensure AudioHandler is initialized before proceeding
    await _ensureInitialized();
    
    if (_audioHandler == null) {
      _log("AudioHandler not initialized, cannot start playback");
      return;
    }

    if (startIndex < 0 || startIndex >= queue.length) {
      _log("Invalid start index for playback: $startIndex. Stopping playback.");
      await stopSong();
      return;
    }

    _playingSongs = List.from(queue);
    _currentSongIndex = startIndex;
    final songToPlay = _playingSongs[startIndex];

    // Ensure media item is updated BEFORE starting playback
    await _audioHandler!.updateMediaItemFromSong(songToPlay);
    
    // Add explicit state update before playing
    await _audioHandler!.stop(); // Clear any previous state

    try {
      await _audioPlayer.play(ap.DeviceFileSource(songToPlay.path));
      // A short delay and resume check can help on some platforms.
      Future.delayed(Duration(milliseconds: 100), () async {
        if (_audioPlayer.state != ap.PlayerState.playing) {
          await _audioPlayer.resume();
        }
      });
      _isPlaying = true;
      _currentPosition = Duration.zero;
      await Settings.setLastPlayingSong(songToPlay.path);
    } catch (e) {
      _log("Error starting playback: $e");
      _isPlaying = false;
    } finally {
      _internalNotifyListeners();
    }
  }

    
  // MARK: Playback Control
  
  /// Plays a song from the main sorted list, creating a new queue.
  Future<void> playSong(int sortedIndex) async {
    if (sortedIndex < 0 || sortedIndex >= _sortedSongs.length) {
      _log("Invalid sortedIndex: $sortedIndex");
      return;
    }
    final newQueue = [
      ..._sortedSongs.sublist(sortedIndex),
      ..._sortedSongs.sublist(0, sortedIndex)
    ];
    await _startPlayback(newQueue, 0);
  }

  /// Plays a specific song if it's in the current queue.
  Future<void> playSpecificSong(Music song) async {
    int index = _playingSongs.indexOf(song);
    if (index != -1) {
      await _startPlayback(_playingSongs, index);
    } else {
      _log("Song not found in the current playing queue.");
    }
  }

  Future<void> pauseSong({bool isInterruption = false}) async {
    if (_isPausing || !_isPlaying) return;
    _isPausing = true;
    _log("Pausing song");
    try {
      await _audioPlayer.pause();
      _isPlaying = false;
      _isPausedByInterruption = isInterruption;
      _internalNotifyListeners();
    } catch (e) {
      _log("Error pausing song: $e");
    } finally {
      _isPausing = false;
    }
  }

  Future<void> resumeSong() async {
    if (_isResuming || _isPlaying) return;
    _isResuming = true;
    _log("Resuming song");
    try {
      await _audioPlayer.resume();
      _isPlaying = true;
      _isPausedByInterruption = false;
      _internalNotifyListeners();
    } catch (e) {
      _log("Error resuming song: $e");
    } finally {
      _isResuming = false;
    }
  }

  Future<void> stopSong() async {
    if (_isStoppingInProgress) return;
    _isStoppingInProgress = true;
    _log("Stopping song");
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      _currentPosition = Duration.zero;
      _internalNotifyListeners();
    } catch (e) {
      _log("Error stopping song: $e");
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
    if (_isChangingSong || _currentSongIndex == null || _playingSongs.isEmpty) return;
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
      Future.delayed(Duration(milliseconds: 200), () => _isChangingSong = false);
    }
  }

  Future<void> previousSong() async {
    if (_isChangingSong || _currentSongIndex == null || _playingSongs.isEmpty) return;
    _isChangingSong = true;
    try {
      if (_currentPosition.inSeconds > 3) {
        await seek(Duration.zero);
      } else {
        int prevIndex = (_currentSongIndex! - 1 + _playingSongs.length) % _playingSongs.length;
        await _startPlayback(_playingSongs, prevIndex);
      }
    } finally {
      Future.delayed(Duration(milliseconds: 200), () => _isChangingSong = false);
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
    _log("Playing album: ${selectedSong.album}");
    int startIndex = albumSongs.indexOf(selectedSong);
    await _startPlayback(albumSongs, max(0, startIndex));
  }

  Future<void> playArtist(List<Music> artistSongs, Music selectedSong) async {
    _log("Playing artist: ${selectedSong.artist}");
    int startIndex = artistSongs.indexOf(selectedSong);
    await _startPlayback(artistSongs, max(0, startIndex));
  }

  Future<void> playPlaylistFromIndex(List<Music> playlistSongs, int index) async {
    _log("Playing playlist from index: $index");
    await _startPlayback(playlistSongs, index);
  }
  
  // MARK: Queue Management
  
  Future<void> shuffle() async {
    if (_playingSongs.isEmpty) return;
    _log("Shuffling playlist");
    
    Music? currentSong = getCurrentSong();
    bool wasPlaying = _isPlaying;
    
    // Create a copy of the playlist without the current song
    List<Music> songsToShuffle = List.from(_playingSongs);
    if (currentSong != null) {
      songsToShuffle.remove(currentSong);
    }
    
    // Shuffle the remaining songs
    songsToShuffle.shuffle(_random);
    
    // Reconstruct the playlist with current song at the beginning
    if (currentSong != null) {
      _playingSongs = [currentSong, ...songsToShuffle];
      _currentSongIndex = 0;
    } else {
      _playingSongs = songsToShuffle;
      _currentSongIndex = 0;
    }
    
    // Only restart playback if nothing was playing
    if (!wasPlaying && currentSong != null) {
      await _startPlayback(_playingSongs, 0);
    } else {
      // Just notify listeners of the queue change without interrupting playback
      _internalNotifyListeners();
    }
  }

  void reorderPlayingSongs(List<Music> newOrder) {
    _log("Reordering playing songs");
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
