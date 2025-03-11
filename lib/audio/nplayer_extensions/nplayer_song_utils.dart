part of '../nplayer.dart';

extension NPlayerSongUtils on NPlayer {
  // MARK: Song Utility Methods
  Future<void> toggleFavorite() async {
  final currentSong = getCurrentSong();
  if (currentSong != null) {
    currentSong.isFavorite = !currentSong.isFavorite;
    await SongData.setFavorite(currentSong.path, currentSong.isFavorite);
    _internalNotifyListeners();
  }
}

Future<void> _loadFavorites() async {
  for (var song in _allSongs) {
    song.isFavorite = SongData.isFavorite(song.path);
  }
}

/// Updates a song's metadata
Future<void> updateSongMetadata(Music song, Map<String, String> metadata) async {
  _log("Updating metadata for ${song.title}");
  try {
    final songFile = File(song.path);
    if (!await songFile.exists()) {
      throw Exception('Song file not found');
    }

    await MetadataGod.writeMetadata(
      file: song.path,
      metadata: Metadata(
        title: metadata['title'],
        artist: metadata['artist'],
        album: metadata['album'],
        year: int.tryParse(metadata['year'] ?? ''),
        genre: metadata['genre'],
      ),
    );

    // Update the song object
    final index = _allSongs.indexOf(song);
    if (index != -1) {
      _allSongs[index] = Music(
        path: song.path,
        title: metadata['title'] ?? song.title,
        artist: metadata['artist'] ?? song.artist,
        album: metadata['album'] ?? song.album,
        year: metadata['year'] ?? song.year,
        genre: metadata['genre'] ?? song.genre,
        duration: song.duration,
        folderName: song.folderName,
        lastModified: song.lastModified,
        picture: song.picture,  // Preserve existing album art
        size: song.size,
        playlists: song.playlists, // Preserve existing playlists
        isFavorite: song.isFavorite, // Preserve favorite status
      );
    }
    // Re-filter and sort if the current sort depends on metadata
    if (['title', 'artist', 'album', 'year', 'genre'].contains(_sortBy)) {
      _filterAndSortSongs();
    }
    _internalNotifyListeners();
  } catch (e) {
    _log("Error updating metadata: $e");
  }
}

/// Deletes a song from the library
Future<void> deleteSong(Music song) async {
  _log("Deleting song: ${song.title}");
  try {
    // 1. Remove from all songs list
    _allSongs.removeWhere((s) => s.path == song.path);

    // 2. Remove from sorted songs list (if present)
    _sortedSongs.removeWhere((s) => s.path == song.path);

    // 3. Remove from playing songs list and update index if necessary
    int playingIndex = _playingSongs.indexWhere((s) => s.path == song.path);
    if (playingIndex != -1) {
      _playingSongs.removeAt(playingIndex);
      if (_currentSongIndex != null) {
        if (playingIndex < _currentSongIndex!) {
          _currentSongIndex = _currentSongIndex! - 1;
        } else if (playingIndex == _currentSongIndex!) {
          // If the deleted song was the current one, stop playback or play next
          if (_playingSongs.isNotEmpty) {
            // Play the song that is now at the current index, or the previous one if it was the last
            _currentSongIndex = playingIndex.clamp(0, _playingSongs.length - 1);
            await _startPlayback(_playingSongs, _currentSongIndex!);
          } else {
            await stopSong();
            _currentSongIndex = null;
          }
        }
      }
    }

    // 4. Remove from all playlists
    for (var playlistName in List.from(song.playlists)) { // Iterate over a copy
      await PlaylistManager.removeSongFromPlaylist(playlistName, song.title);
    }

    // 5. Delete the actual file
    final file = File(song.path);
    if (await file.exists()) {
      await file.delete();
    }

    // 6. Remove from favorites and other song data
    await SongData.removeSongEntry(song.path);

    _internalNotifyListeners();
  } catch (e) {
    _log("Error deleting song: $e");
  }
}

Future<void> shareSong(Music song) async {
  _log("Sharing song: ${song.title}");
  try {
    final List<XFile> filesToShare = [XFile(song.path)];
    await Share.shareXFiles(
      filesToShare,
      text: 'Check out this song: ${song.title} by ${song.artist}',
      subject: 'Song Share: ${song.title}',
    );
  } catch (e) {
    _log("Error sharing song: $e");
  }
}

// MARK: Sleep Timer methods
double _easeOutVolume(double progress) {
  // Use ease-out cubic curve for more natural volume fade
  return (1 - progress) * (1 - progress) * (1 - progress);
}

void _handleFadeOut() {
  if (_fadeTimer == null && _remainingTime != null) {
    // Store original volume when fade starts
    _originalVolume ??= _audioPlayer.volume;
    
    _fadeTimer = Timer.periodic(Duration(milliseconds: NPlayer.fadeUpdateInterval), (timer) {
      if (_remainingTime == null || _remainingTime!.inSeconds <= 0) {
        _fadeTimer?.cancel();
        _fadeTimer = null;
        return;
      }

      // Calculate progress (0.0 to 1.0) where 1.0 is start of fade and 0.0 is end
      final progress = _remainingTime!.inMilliseconds / (NPlayer.fadeStartSeconds * 1000);
      
      // Apply ease-out curve to the volume
      final volumeMultiplier = _easeOutVolume(1 - progress);
      final targetVolume = _originalVolume! * volumeMultiplier;
      
      _audioPlayer.setVolume(targetVolume.clamp(0.0, 1.0));
    });
  }
}

void startSleepTimer(int minutes) {
  _sleepTimerMinutes = minutes;
  _remainingTime = Duration(minutes: minutes);
  _sleepTimer?.cancel();
  _fadeTimer?.cancel();
  
  _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (_remainingTime != null && _remainingTime!.inSeconds > 0) {
      _remainingTime = _remainingTime! - const Duration(seconds: 1);
      
      // Start fade out when 10 seconds remaining
      if (_remainingTime!.inSeconds <= NPlayer.fadeStartSeconds && _remainingTime!.inSeconds > 0) {
        _handleFadeOut();
      }
      
      // When timer hits zero
      if (_remainingTime!.inSeconds <= 0) {
        cancelSleepTimer();
        pauseSong();
        // Restore original volume after a brief pause
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_originalVolume != null) {
            _audioPlayer.setVolume(_originalVolume!); // Error: The getter '_audioPlayer' isn't defined for the type 'NPlayer'.
            _originalVolume = null;
          }
        });
      }
    }
  });
  _internalNotifyListeners(); // Notify for sleep timer start
}

void cancelSleepTimer() {
  _sleepTimer?.cancel();
  _sleepTimer = null;
  _fadeTimer?.cancel();
  _fadeTimer = null;
  // Only reset the minutes if we're not in the middle of the sleep animation
  if (_sleepTimerMinutes != 0) {
    _sleepTimerMinutes = null;
  }
  _originalVolume = null; // Reset original volume if timer is cancelled
  _internalNotifyListeners();
  }
}
