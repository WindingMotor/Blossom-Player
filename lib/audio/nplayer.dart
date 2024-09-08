import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:blossom/audio/audio_handler.dart';
import 'package:blossom/audio/nplaylist.dart';
import 'package:blossom/tools/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_service/audio_service.dart';
import 'package:http/http.dart' as http;

class Music {
  final String path;
  final String folderName;
  final DateTime lastModified;
  final String title;
  final String album;
  final String artist;
  final int duration; // In milliseconds
  final Uint8List? picture; // Album art
  final String year;
  final String genre;
  final int size;
  List<String> playlists; // Change this to a mutable list

  Music({
    required this.path,
    required this.folderName,
    required this.lastModified,
    required this.title,
    required this.album,
    required this.artist,
    required this.duration,
    this.picture,
    required this.year,
    required this.genre,
    required this.size,
    List<String>? playlists, // Make this parameter optional
  }) : playlists = playlists ?? []; // Initialize with an empty list if null

  // Add a method to create a Music object from JSON
  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      path: json['path'],
      folderName: json['folderName'],
      lastModified: DateTime.parse(json['lastModified']),
      title: json['title'],
      album: json['album'],
      artist: json['artist'],
      duration: json['duration'],
      picture: json['picture'] != null
          ? Uint8List.fromList(List<int>.from(json['picture']))
          : null,
      year: json['year'],
      genre: json['genre'],
      size: json['size'],
      playlists: List<String>.from(json['playlists'] ?? []),
    );
  }

  // Add a method to convert Music object to JSON
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'folderName': folderName,
      'lastModified': lastModified.toIso8601String(),
      'title': title,
      'album': album,
      'artist': artist,
      'duration': duration,
      'picture': picture?.toList(),
      'year': year,
      'genre': genre,
      'size': size,
      'playlists': playlists,
    };
  }

  void updatePlaylists(List<String> newPlaylists) {
    playlists = List.from(newPlaylists);
  }
}

class NPlayer extends ChangeNotifier {
  // SECTION: Properties
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final MyAudioHandler _audioHandler;
  PlaybackState _playbackState = PlaybackState();

  final Random _random = Random();
  final List<Music> _allSongs = [];
  List<Music> _sortedSongs = [];
  List<Music> _playingSongs = [];

  String _searchQuery = '';
  int? _currentSongIndex;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  String _repeatMode = Settings.repeatMode;
  String _sortBy = 'title';
  bool _sortAscending = true;

  bool _isPausing = false;
  bool _isResuming = false;
  bool _isStoppingInProgress = false;

  List<String> get playlists => PlaylistManager.playlistNames;

  final _songChangeController = StreamController<void>.broadcast();
  Stream<void> get songChangeStream => _songChangeController.stream;


  // SECTION: Constructor and Initialization
  NPlayer() {
    _log("Initializing NPlayer");
    _initializeAudioHandler();
    _loadPlaylists(); // This will also load songs
    _setupAudioPlayerListeners();
    _initializeFromSettings();
    listFiles();
    sortSongs(sortBy: 'title', ascending: true);
  }

  Future<void> _initializeAudioHandler() async {
    _log("Initializing AudioHandler");
    _audioHandler = await AudioService.init(
      builder: () => MyAudioHandler(_audioPlayer, this),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.yourdomain.blossom.channel.audio',
        androidNotificationChannelName: 'Blossom Music',
        androidNotificationIcon: 'drawable/ic_notification',
        androidShowNotificationBadge: true,
        notificationColor: Color(0xFF2196F3),
        androidStopForegroundOnPause: false,
      ),
    );
    _log("AudioHandler initialized");
    notifyListeners();
  }

  Future<void> _initializeFromSettings() async {
    _log("Initializing from settings");
    await setVolume(Settings.volume);
    _repeatMode = Settings.repeatMode;
    _log(
        "Initialized from settings: volume=${Settings.volume}, repeatMode=$_repeatMode");
  }

  void _setupAudioPlayerListeners() {
    _log("Setting up AudioPlayer listeners");
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _log("Player state changed: ${state == PlayerState.playing}");
      // Only update if the state is different from the current state
      if (_isPlaying != (state == PlayerState.playing)) {
        _isPlaying = state == PlayerState.playing;
        notifyListeners();
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      _currentPosition = position;
      notifyListeners();
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      _log("Song completed");
      _handleSongCompletion();
    });
  }

  // SECTION: Getters
  List<Music> get allSongs => _allSongs;
  List<Music> get playingSongs => _playingSongs;
  List<Music> get sortedSongs => _sortedSongs;
  int? get currentSongIndex => _currentSongIndex;
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  String get repeatMode => _repeatMode;
  double get volume => _audioPlayer.volume;

  Duration get duration {
    return getCurrentSong()?.duration != null
        ? Duration(milliseconds: getCurrentSong()!.duration)
        : Duration.zero;
  }

  Music? getCurrentSong() {
    if (_currentSongIndex == null || _playingSongs.isEmpty) {
      return null;
    }

    if (_currentSongIndex! >= _playingSongs.length) {
      _currentSongIndex = _playingSongs.length - 1;
    }

    return _playingSongs[_currentSongIndex!];
  }

  // SECTION: Playback Control
  Future<void> playSpecificSong(Music song) async {
    _log("Attempting to play specific song: ${song.title}");
    int index = _sortedSongs.indexOf(song);
    if (index != -1) {
      await playSong(index);
    } else {
      _log("Song not found in the current playlist");
    }
  }

  Future<void> playSong(int sortedIndex) async {
    if (sortedIndex < 0 || sortedIndex >= _sortedSongs.length) {
      _log("Invalid sortedIndex: $sortedIndex");
      throw RangeError('Invalid sortedIndex');
    }

    Music selectedSong = _sortedSongs[sortedIndex];
    _log("Playing song: ${selectedSong.title}");

    _playingSongs = [
      ..._sortedSongs.sublist(sortedIndex),
      ..._sortedSongs.sublist(0, sortedIndex)
    ];

    _currentSongIndex = 0;
    await _audioPlayer.play(DeviceFileSource(selectedSong.path));
    _isPlaying = true;
    _currentPosition = Duration.zero;
    await Settings.setLastPlayingSong(selectedSong.path);
    await _updateMetadata();
    await _updatePlaybackState(playing: true);
    _songChangeController.add(null);
    notifyListeners();
  }

  Future<void> pauseSong() async {
    if (_isPausing || !_isPlaying) return;

    _isPausing = true;
    _log("Pausing song");

    try {
      await _audioPlayer.pause();
      _isPlaying = false;
      await _updatePlaybackState(playing: false);
      notifyListeners();
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
      await _updatePlaybackState(playing: true);
      notifyListeners();
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
      await _audioHandler.stop();
      notifyListeners();
    } catch (e) {
      _log("Error stopping song: $e");
    } finally {
      _isStoppingInProgress = false;
    }
  }

  Future<void> togglePlayPause() async {
    _log("Toggling play/pause");
    if (_isPlaying) {
      await pauseSong();
    } else {
      if (_currentSongIndex != null) {
        await resumeSong();
      } else if (_allSongs.isNotEmpty) {
        await playSong(0);
      }
    }
  }

  Future<void> nextSong() async {
    _log("Moving to next song");
    if (_currentSongIndex != null && _playingSongs.isNotEmpty) {
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
      _currentSongIndex = nextIndex;
      await _audioPlayer.play(DeviceFileSource(_playingSongs[nextIndex].path));
      _isPlaying = true;
      _currentPosition = Duration.zero;
      await Settings.setLastPlayingSong(_playingSongs[nextIndex].path);
      await _updateMetadata();
      await _updatePlaybackState(playing: true);
      await _audioHandler.play();
      _songChangeController.add(null);
      notifyListeners();
    } else {
      _log("No songs to play");
    }
  }

  Future<void> previousSong() async {
    _log("Moving to previous song");
    if (_currentSongIndex != null && _playingSongs.isNotEmpty) {
      if (_currentPosition.inSeconds > 3) {
        await seek(Duration.zero);
      } else {
        int previousIndex = (_currentSongIndex! - 1 + _playingSongs.length) %
            _playingSongs.length;
        _currentSongIndex = previousIndex;
        await _audioPlayer
            .play(DeviceFileSource(_playingSongs[previousIndex].path));
        _isPlaying = true;
        _currentPosition = Duration.zero;
        await Settings.setLastPlayingSong(_playingSongs[previousIndex].path);
        await _updateMetadata();
        await _updatePlaybackState(playing: true);
        await _audioHandler.play();
       _songChangeController.add(null);
        notifyListeners();
      }
    } else {
      _log("No songs to play");
    }
  }

  // SECTION: Album and Artist Playback
  Future<void> playAlbum(List<Music> albumSongs, Music selectedSong) async {
    _log("Playing album: ${selectedSong.album}");
    await _playSelectedSongs(albumSongs, selectedSong);
  }

  Future<void> playArtist(List<Music> artistSongs, Music selectedSong) async {
    _log("Playing artist: ${selectedSong.artist}");
    await _playSelectedSongs(artistSongs, selectedSong);
  }

  Future<void> playPlaylistFromIndex(
      List<Music> playlistSongs, int index) async {
    _log("Playing playlist from index: $index");
    _playingSongs = List.from(playlistSongs);
    _currentSongIndex = index;
    await _audioPlayer.play(DeviceFileSource(_playingSongs[index].path));
    _isPlaying = true;
    _currentPosition = Duration.zero;
    await Settings.setLastPlayingSong(_playingSongs[index].path);
    await _updateMetadata();
    await _updatePlaybackState(playing: true);
    notifyListeners();
    _log("Now playing: ${_playingSongs[index].title} from playlist");
  }

  Future<void> _playSelectedSongs(List<Music> songs, Music selectedSong) async {
    _playingSongs = List.from(songs);
    _currentSongIndex = _playingSongs.indexOf(selectedSong);

    if (_currentSongIndex == -1) {
      _log("Selected song not found in the provided list. Playing first song.");
      _currentSongIndex = 0;
    }

    await _audioPlayer
        .play(DeviceFileSource(_playingSongs[_currentSongIndex!].path));
    _isPlaying = true;
    _currentPosition = Duration.zero;
    await Settings.setLastPlayingSong(_playingSongs[_currentSongIndex!].path);
    await _updateMetadata();
    await _updatePlaybackState(playing: true);
    notifyListeners();
    _log("Now playing: ${_playingSongs[_currentSongIndex!].title}");
  }

  // SECTION: Playlist Management
  Future<void> shuffle() async {
    _log("Shuffling playlist");
    if (_playingSongs.isEmpty) {
      _log("No songs to shuffle");
      return;
    }

    Music? currentSong = getCurrentSong();

    _playingSongs.shuffle(_random);

    if (currentSong != null) {
      _playingSongs.remove(currentSong);
      _playingSongs.insert(0, currentSong);
      _currentSongIndex = 0;
    } else {
      _currentSongIndex = 0;
      currentSong = _playingSongs[0];
    }

    await _audioPlayer.play(DeviceFileSource(currentSong.path));
    _isPlaying = true;
    _currentPosition = Duration.zero;

    notifyListeners();
    _log("Playlist shuffled and playing ${currentSong.title}");
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

    notifyListeners();
  }

  // SECTION: Settings and Controls
  Future<void> setVolume(double newVolume) async {
    _log("Setting volume to $newVolume");
    await _audioPlayer.setVolume(newVolume);
    await Settings.setVolume(newVolume);
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    _log("Seeking to position: $position");
    await _audioPlayer.seek(position);
    _currentPosition = position;
    notifyListeners();
  }

  Future<void> setRepeatMode(String mode) async {
    _log("Setting repeat mode to $mode");
    _repeatMode = mode;
    await Settings.setRepeatMode(mode);
    notifyListeners();
  }

  // SECTION: Song Loading and Management
  Future<void> reloadSongs() async {
    _log("Reloading songs");
    _allSongs.clear();
    _playingSongs.clear();
    await _loadSongs();
    notifyListeners();
  }

  Future<void> _loadSongs() async {
    try {
      final directoryPath = await Settings.getSongDir();
      _log("Starting to load songs from: $directoryPath");
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        _log('Directory does not exist: $directoryPath');
        return;
      }
      if (!await requestStoragePermission()) {
        _log('Storage permission denied');
        return;
      }
      await _processDirectory(directory);
      _log("Finished loading songs. Total songs: ${_allSongs.length}");

      // Load playlist information for each song
      for (var song in _allSongs) {
        song.playlists.clear();
        for (var playlist in playlists) {
          if (PlaylistManager.getPlaylistSongs(playlist).contains(song.title)) {
            song.playlists.add(playlist);
            _log("Song ${song.title} added to playlist");
          }
        }
      }

      _playingSongs = List.from(_allSongs);
      notifyListeners();
    } catch (e) {
      _log("Error while loading songs: $e");
    }
  }

  Future _processDirectory(Directory directory) async {
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File &&
          (path.extension(entity.path).toLowerCase() == '.mp3' ||
              path.extension(entity.path).toLowerCase() == '.flac')) {
        await _processAudioFile(entity);
      } else if (entity is Directory) {
        await _processDirectory(entity);
      }
    }
  }

  Future<void> _processAudioFile(File file) async {
    _log("Processing file: ${file.path}");
    try {
      final metadata = await MetadataGod.readMetadata(file: file.path);
      String title = metadata.title ?? path.basenameWithoutExtension(file.path);
      String album = metadata.album ?? 'Unknown Album';
      String artist = metadata.artist ?? 'Unknown Artist';
      Uint8List? picture = metadata.picture?.data;
      String year = metadata.year?.toString() ?? '';
      String genre = metadata.genre ?? 'Unknown Genre';
      DateTime lastModified = await file.lastModified();

      final music = Music(
        path: file.path,
        folderName: path.basename(path.dirname(file.path)),
        title: title,
        album: album,
        artist: artist,
        duration: metadata.durationMs?.round() ?? 0,
        picture: picture,
        year: year,
        genre: genre,
        size: await file.length(),
        lastModified: lastModified,
        // playlists is not provided here, so it will use the default empty list
      );

      _allSongs.add(music);
      _log("Added song: $title by $artist");
    } catch (e) {
      _log('Error parsing file ${file.path}: $e');
    }
  }

// SECTION: Playlist

  Future<void> _loadPlaylists() async {
    await PlaylistManager.load();
    await _loadSongs();
    notifyListeners();
  }

  Future<void> createPlaylist(String name) async {
    await PlaylistManager.createPlaylist(name);
    notifyListeners();
  }

  Future<void> deletePlaylist(String name) async {
    await PlaylistManager.deletePlaylist(name);
    notifyListeners();
  }

  Future<void> addSongToPlaylist(String playlistName, Music song) async {
    if (!PlaylistManager.getPlaylistSongs(playlistName).contains(song.title)) {
      await PlaylistManager.addSongToPlaylist(playlistName, song.title);
      if (!song.playlists.contains(playlistName)) {
        song.playlists.add(playlistName);
      }
      notifyListeners();
    }
  }

  Future<void> removeSongFromPlaylist(String playlistName, Music song) async {
    await PlaylistManager.removeSongFromPlaylist(playlistName, song.title);
    song.playlists.remove(playlistName);
    notifyListeners();
  }

  List<Music> getPlaylistSongs(String playlistName) {
    List<String> songNames = PlaylistManager.getPlaylistSongs(playlistName);
    return _allSongs.where((song) => songNames.contains(song.title)).toList();
  }

  // SECTION: Search and Sort
  void setSearchQuery(String query) {
    _log("Setting search query: $query");
    _searchQuery = query.toLowerCase();
    _filterAndSortSongs();
  }

  void _filterAndSortSongs() {
    _log("Filtering and sorting songs");
    if (_searchQuery.isEmpty) {
      _sortedSongs = List.from(_allSongs);
    } else {
      final fuse = Fuzzy(
        _allSongs,
        options: FuzzyOptions(
          keys: [
            WeightedKey(
                name: 'title',
                getter: (Music song) => song.title.toLowerCase(),
                weight: 8),
            WeightedKey(
                name: 'artist',
                getter: (Music song) => song.artist.toLowerCase(),
                weight: 4),
            WeightedKey(
                name: 'album',
                getter: (Music song) => song.album.toLowerCase(),
                weight: 5),
            WeightedKey(
                name: 'genre',
                getter: (Music song) => song.genre.toLowerCase(),
                weight: 1),
          ],
        ),
      );

      final result = fuse.search(_searchQuery);
      _sortedSongs = result.map((r) => r.item).toList();
    }

    _applySorting();

    notifyListeners();
  }

  void _applySorting() {
    _log("Applying sorting: by $_sortBy, ascending: $_sortAscending");
    _sortedSongs.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'title':
          comparison = a.title.compareTo(b.title);
          break;
        case 'artist':
          comparison = a.artist.compareTo(b.artist);
          break;
        case 'album':
          comparison = a.album.compareTo(b.album);
          break;
        case 'duration':
          comparison = a.duration.compareTo(b.duration);
          break;
        case 'folder':
          comparison = a.folderName.compareTo(b.folderName);
          break;
        case 'lastModified':
          comparison = a.lastModified.compareTo(b.lastModified);
          break;
        default:
          comparison = a.title.compareTo(b.title);
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  void sortSongs({String? sortBy, bool? ascending}) {
    _log(
        "Sorting songs: by ${sortBy ?? _sortBy}, ascending: ${ascending ?? _sortAscending}");
    _sortBy = sortBy ?? _sortBy;
    _sortAscending = ascending ?? _sortAscending;
    _filterAndSortSongs();
  }

  // SECTION: Metadata and Playback State
  Future<void> _updateMetadata() async {
    _log("Updating metadata");
    final currentSong = getCurrentSong();
    if (currentSong != null) {
      Uri? artUri;
      if (currentSong.picture != null) {
        try {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/album_art.jpg');
          await file.writeAsBytes(currentSong.picture!);
          artUri = Uri.file(file.path);
        } catch (e) {
          _log('Error creating temporary file for album art: $e');
        }
      }

      final mediaItem = MediaItem(
        id: currentSong.path,
        album: currentSong.album,
        title: currentSong.title,
        artist: currentSong.artist,
        duration: Duration(milliseconds: currentSong.duration),
        artUri: artUri,
      );
      await _audioHandler.updateMediaItem(mediaItem);
      _log("Metadata updated for ${currentSong.title}");
    }
  }

  Future<void> _updatePlaybackState({required bool playing}) async {
    _log("Updating playback state: playing=$playing");
    _playbackState = PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: [0, 1, 2],
      processingState: AudioProcessingState.ready,
      playing: playing,
      updatePosition: _currentPosition,
      bufferedPosition: Duration.zero,
      speed: 1.0,
    );
    _audioHandler.playbackState.add(_playbackState);
  }

  // SECTION: Utility Methods
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      _log("Requesting storage permission");
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      _log("Storage permission ${status.isGranted ? 'granted' : 'denied'}");
      return status.isGranted;
    }
    return true; // Always return true for desktop platforms
  }

  Future<List<FileSystemEntity>> listFiles() async {
    try {
      final directoryPath = await Settings.getSongDir();
      _log("Listing files from: $directoryPath");
      final directory = Directory(directoryPath);

      if (!await directory.exists()) {
        _log('Directory does not exist: $directoryPath');
        return [];
      }

      if (!await requestStoragePermission()) {
        _log('Storage permission denied');
        return [];
      }

      List<FileSystemEntity> files =
          await directory.list(recursive: true, followLinks: false).toList();

      // Filter to include only .mp3 and .flac files
      files = files
          .where((file) =>
              file is File &&
              (path.extension(file.path).toLowerCase() == '.mp3' ||
                  path.extension(file.path).toLowerCase() == '.flac'))
          .toList();

      _log("Found ${files.length} .mp3 and .flac files");
      return files;
    } catch (e) {
      _log("Error while listing files: $e");
      return [];
    }
  }

  Future<void> _handleSongCompletion() async {
    _log("Handling song completion");
    switch (_repeatMode) {
      case 'off':
        await nextSong();
        break;
      case 'one':
        if (_currentSongIndex != null && _playingSongs.isNotEmpty) {
          await _audioPlayer
              .play(DeviceFileSource(_playingSongs[_currentSongIndex!].path));
        }
        break;
      case 'all':
        await nextSong();
        break;
    }
  }

  void _log(String message) {
    print("NPlayer: $message");
  }

  @override
  void dispose() {
    _log("Disposing NPlayer");
    _audioPlayer.dispose();
    _songChangeController.close();
    super.dispose();
  }

Future<Map<String, dynamic>> _fetchMetadata(String serverIP) async {
  final url = 'http://$serverIP:8080/metadata';
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to load metadata');
  }
}

Future<void> playFromServer(String serverIP) async {
  if (serverIP.isEmpty) {
    print('Error: Server IP is empty');
    return;
  }

  final streamUrl = 'http://$serverIP:8080/stream';
  final metadataUrl = 'http://$serverIP:8080/metadata';
  print('Attempting to play from URL: $streamUrl');
  
  try {
    // Fetch metadata first
    final response = await http.get(Uri.parse(metadataUrl));
    if (response.statusCode == 200) {
      final metadata = json.decode(response.body);
      
      // Create a Music object with the fetched metadata
      final serverSong = Music(
        path: streamUrl,
        folderName: 'Server',
        lastModified: DateTime.now(),
        title: metadata['title'] ?? 'Unknown Title',
        album: metadata['album'] ?? 'Unknown Album',
        artist: metadata['artist'] ?? 'Unknown Artist',
        duration: (metadata['duration'] as num?)?.toInt() ?? 0, // Convert to int
        picture: metadata['picture'] != null ? base64Decode(metadata['picture']) : null,
        year: metadata['year']?.toString() ?? '',
        genre: metadata['genre'] ?? 'Unknown Genre',
        size: 0, // We don't have this information from the server
      );

      // Add the server song to the playing list
      _playingSongs = [serverSong];
      _currentSongIndex = 0;

      // Play the stream
      await _audioPlayer.play(UrlSource(streamUrl));
      _isPlaying = true;
      _currentPosition = Duration.zero;

      // Update metadata and playback state
      await _updateMetadata();
      await _updatePlaybackState(playing: true);

      notifyListeners();
      print('Successfully started playing from server');
    } else {
      throw Exception('Failed to load metadata: ${response.statusCode}');
    }
  } catch (e) {
    print('Error playing from server: $e');
    // Handle the error (e.g., show an error message to the user)
  }
}

}
