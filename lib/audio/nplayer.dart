import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:blossom/audio/audio_handler.dart';
import 'package:blossom/audio/nplaylist.dart';
import 'package:blossom/audio/nserver.dart';
import 'package:blossom/binder/ios_binder.dart';
import 'package:blossom/tools/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:headset_connection_event/headset_event.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_service/audio_service.dart';
import 'package:blossom/audio/song_data.dart';
import 'package:share_plus/share_plus.dart';

/// Represents a music file with its metadata and associated playlists.
class Music {
  final String path;
  final String folderName;
  final DateTime lastModified;
  final String title;
  final String album;
  final String artist;
  final int duration;
  final Uint8List? picture;
  final String year;
  final String genre;
  final int size;
  List<String> playlists;
  bool isFavorite;

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
    List<String>? playlists,
    this.isFavorite = false,
  }) : playlists = playlists ?? [];

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
      isFavorite: json['isFavorite'] ?? false,
    );
  }

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
      'isFavorite': isFavorite,
    };
  }

  void updatePlaylists(List<String> newPlaylists) {
    playlists = List.from(newPlaylists);
  }
}

/// Main class for managing music playback and related functionality.
class NPlayer extends ChangeNotifier {
  // MARK: Properties
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

  bool _isPausedByInterruption = false;
  bool get isPausedByInterruption => _isPausedByInterruption;

  List<String> get playlists => PlaylistManager.playlistNames;

  NServer? _server;
  NClient? _client;

  // Server streaming state
  bool _isServerOn = false;
  bool get isServerOn => _isServerOn;

  // Search debounce
  Timer? _debounceTimer;
  final Duration _debounceDuration = Duration(milliseconds: 300);

  // Headset
  final HeadsetEvent _headsetPlugin = HeadsetEvent();
  bool _isHeadphonesConnected = false;
  bool get isHeadphonesConnected => _isHeadphonesConnected;

  // Sleep Timer properties
  Timer? _sleepTimer;
  Timer? _fadeTimer;
  int? _sleepTimerMinutes;
  Duration? _remainingTime;
  double? _originalVolume;
  static const fadeStartSeconds = 10;
  static const fadeUpdateInterval = 50; // Update every 50ms for smoother transition

  // Sleep Timer getters and setters
  int? get sleepTimerMinutes => _sleepTimerMinutes;
  set _setSleepTimerMinutes(int? value) {
    _sleepTimerMinutes = value;
    notifyListeners();
  }

  Duration? get remainingTime => _remainingTime;
  set _setRemainingTime(Duration? value) {
    _remainingTime = value;
    notifyListeners();
  }

  // MARK: Constructor and Initialization
  NPlayer() {
    _log("Initializing NPlayer");
    _initializeAudioHandler();
    _setupAudioPlayerListeners();
    _initializeFromSettings();
    _initHeadsetDetection();

    // Load playlists and songs, then apply sorting
    _loadPlaylists().then((_) {
      _loadSongs().then((_) {
        loadSortSettings().then((_) {
          sortSongs(sortBy: Settings.songSortBy, ascending: Settings.songSortAscending);
          notifyListeners();
        });
      });
    });

    _log("Initializing client and server");
    _server = NServer(this);
    _client = NClient(this);
  }

  // MARK: Initialization Methods
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
    await _loadFavorites();
    _log(
        "Initialized from settings: volume=${Settings.volume}, repeatMode=$_repeatMode");
  }

  void _setupAudioPlayerListeners() {
    _log("Setting up AudioPlayer listeners");
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _log("Player state changed: ${state == PlayerState.playing}");
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

  void _initHeadsetDetection() {
    _headsetPlugin.getCurrentState.then((val) {
      _isHeadphonesConnected = val == HeadsetState.CONNECT;
      notifyListeners();
    });

    _headsetPlugin.setListener((val) {
      bool wasConnected = _isHeadphonesConnected;
      _isHeadphonesConnected = val == HeadsetState.CONNECT;

      // If headphones were connected and are now disconnected, pause the music
      if (wasConnected && !_isHeadphonesConnected && _isPlaying) {
        pauseSong();
      }

      notifyListeners();
    });
  }

  // MARK: Getters
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

  get searchQuery => null;

  Music? getCurrentSong() {
    if (_currentSongIndex == null || _playingSongs.isEmpty) {
      return null;
    }

    if (_currentSongIndex! >= _playingSongs.length) {
      _currentSongIndex = _playingSongs.length - 1;
    }

    return _playingSongs[_currentSongIndex!];
  }

  // MARK: Playback Control
  Future<void> playSpecificSong(Music song) async {
    _log("Attempting to play specific song: ${song.title}");
    int index = _playingSongs.indexOf(song);
    if (index != -1) {
      await _playSongFromQueue(index);
    } else {
      _log("Song not found in the current queue");
    }
  }

  Future<void> _playSongFromQueue(int queueIndex) async {
    if (queueIndex < 0 || queueIndex >= _playingSongs.length) {
      _log("Invalid queueIndex: $queueIndex");
      throw RangeError('Invalid queueIndex');
    }

    Music selectedSong = _playingSongs[queueIndex];
    _log("Playing song from queue: ${selectedSong.title}");

    _currentSongIndex = queueIndex;
    await _audioPlayer.play(DeviceFileSource(selectedSong.path));
    _isPlaying = true;
    _currentPosition = Duration.zero;
    await Settings.setLastPlayingSong(selectedSong.path);
    await _updateMetadata();
    await _updatePlaybackState(playing: true);
    notifyListeners();
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
    notifyListeners();
  }

  Future<void> pauseSong({bool isInterruption = false}) async {
    if (_isPausing || !_isPlaying) return;

    _isPausing = true;
    _log("Pausing song");

    try {
      await _audioPlayer.pause();
      _isPlaying = false;
      _isPausedByInterruption = isInterruption;
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
      _isPausedByInterruption = false;
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
      try {
        await _audioPlayer
            .play(DeviceFileSource(_playingSongs[nextIndex].path));
        _isPlaying = true;
        _currentPosition = Duration.zero;
        await Settings.setLastPlayingSong(_playingSongs[nextIndex].path);
        await _updateMetadata();
        await _updatePlaybackState(playing: true);
        await _audioHandler.play();
        notifyListeners();
      } catch (e) {
        _log("Error playing next song: $e");
      }
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
        try {
          await _audioPlayer
              .play(DeviceFileSource(_playingSongs[previousIndex].path));
          _isPlaying = true;
          _currentPosition = Duration.zero;
          await Settings.setLastPlayingSong(
              _playingSongs[previousIndex].path);
          await _updateMetadata();
          await _updatePlaybackState(playing: true);
          await _audioHandler.play();
          notifyListeners();
        } catch (e) {
          _log("Error playing previous song: $e");
        }
      }
    } else {
      _log("No songs to play");
    }
  }

  // MARK: Album and Artist Playback
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

  // MARK: Playlist Management
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

  // MARK: Settings and Controls
  Future<void> setVolume(double newVolume) async {
    _log("Setting volume to $newVolume");
    await _audioPlayer.setVolume(newVolume);
    await Settings.setVolume(newVolume);
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    _log("Seeking to position: $position");
    try {
      await _audioPlayer.seek(position);
      _currentPosition = position;
      notifyListeners();
    } catch (e) {
      _log("Error seeking song: $e");
    }
  }

  Future<void> setRepeatMode(String mode) async {
    _log("Setting repeat mode to $mode");
    _repeatMode = mode;
    await Settings.setRepeatMode(mode);
    notifyListeners();
  }

  // MARK: Song Loading and Management
  Future<void> setPlaylistImage(String playlistName, File imageFile) async {
    await PlaylistManager.setPlaylistImage(playlistName, imageFile);
    notifyListeners();
  }

  String? getPlaylistImagePath(String playlistName) {
    return PlaylistManager.getPlaylistImagePath(playlistName);
  }

  Future<void> reloadSongs() async {
    _log("Reloading songs");
    _allSongs.clear();
    _playingSongs.clear();
    await _loadSongs();
    notifyListeners();
  }

Future<void> _loadSongs() async {
  try {
    _log("Starting to load songs...");
    
    // On desktop, wait for initial iOS device check
    if (!Platform.isAndroid && !Platform.isIOS) {
      _log("Waiting for iOS device check...");
      await iOS_Binder.getInitialCheck();
      _log("iOS device check completed");
    }

    // Get all possible song directories
    final List<Directory> directories = await Settings.getAllSongDirs();
    
    if (directories.isEmpty) {
      _log('No valid directories found');
      return;
    }

    if (Platform.isAndroid) {
      // Special handling for Android
      if (await _testDirectAccess()) {
        _log("Direct file access test passed");
      } else {
        _log("Direct file access test failed - permission issues or file not found");
      }
    }
    
    // Log all directories being scanned
    _log("Starting to scan ${directories.length} directories for music files");
    for (var dir in directories) {
      _log("Scanning directory: ${dir.path}");
      
      // Try to print first few items in the directory for debugging
      try {
        final items = await dir.list().take(5).toList();
        _log("Directory contains ${items.length} items (showing first 5):");
        for (var item in items) {
          _log(" - ${item.path}");
        }
      } catch (e) {
        _log("Error listing directory contents: $e");
      }
    }
    
    // Process all directories with a timeout
    bool timedOut = false;
    await Future.any([
      _processAllDirectories(directories),
      Future.delayed(const Duration(seconds: 30), () {
        timedOut = true;
        _log("Directory scanning timed out after 30 seconds");
      })
    ]);
    
    if (timedOut) {
      _log("Warning: Scan timed out. Some directories may not have been fully processed.");
    }
    
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

    // Load favorites and sort songs
    await _loadFavorites();
    _filterAndSortSongs();
    notifyListeners();
  } catch (e) {
    _log("Error loading songs: $e");
  }
}

Future<void> _processAllDirectories(List<Directory> directories) async {
  for (var dir in directories) {
    _log("Processing directory: ${dir.path}");
    await _processDirectory(dir);
  }
}

Future<bool> _testDirectAccess() async {
  // Get the custom directory path
  final String? customDir = Settings.customMusicDirectory;
  if (customDir == null || customDir.isEmpty) return false;
  
  try {
    final String testFilePath = path.join(customDir, 'Song.m4a');
    _log("Testing direct file access to: $testFilePath");
    
    final File testFile = File(testFilePath);
    if (await testFile.exists()) {
      _log("Test file exists: $testFilePath");
      
      // Try to read the file
      final int length = await testFile.length();
      _log("Test file size: $length bytes");
      
      // If we can read the size, try to read some data
      final RandomAccessFile reader = await testFile.open(mode: FileMode.read);
      final Uint8List bytes = await reader.read(1024);
      await reader.close();
      
      _log("Successfully read ${bytes.length} bytes from test file");
      
      // Process this specific test file
      await _processAudioFile(testFile);
      
      return true;
    } else {
      _log("Test file does not exist: $testFilePath");
      return false;
    }
  } catch (e) {
    _log("Error in direct file access test: $e");
    return false;
  }
}

Future<void> _processDirectory(Directory directory) async {
  try {
    _log("Listing files in: ${directory.path}");
    
    List<FileSystemEntity> entities = [];
    try {
      entities = await directory.list(recursive: false).toList();
      _log("Found ${entities.length} entries in ${directory.path}");
    } catch (e) {
      _log("Error listing directory ${directory.path}: $e");
      return;
    }
    
    for (final entity in entities) {
      if (entity is File) {
        final extension = path.extension(entity.path).toLowerCase();
        if (extension == '.mp3' || extension == '.flac' || extension == '.m4a') {
          await _processAudioFile(entity);
        }
      } else if (entity is Directory) {
        await _processDirectory(entity);
      }
    }
  } catch (e) {
    _log("Error processing directory ${directory.path}: $e");
  }
}

Future<void> _processAudioFile(File file) async {
  _log("Processing file: ${file.path}");
  try {
    // First check if file is readable
    try {
      final int fileSize = await file.length();
      _log("File size: $fileSize bytes");
      
      if (fileSize <= 0) {
        _log("File is empty or inaccessible: ${file.path}");
        return;
      }
    } catch (e) {
      _log("Cannot read file (permission issue): ${file.path} - $e");
      return;
    }
    
    final metadata = await MetadataGod.readMetadata(file: file.path);
    String title = metadata.title ?? path.basenameWithoutExtension(file.path);

    // Check if a song with the same title already exists
    if (_allSongs.any((song) => song.title == title)) {
      _log("Song with title '$title' already exists. Skipping.");
      return;
    }

    String album = metadata.album ?? 'Unknown Album';
    String artist = metadata.artist ?? 'Unknown Artist';
    Uint8List? picture = metadata.picture?.data;
    String year = metadata.year?.toString() ?? '';
    String genre = metadata.genre ?? 'Unknown Genre';

    // Get last modified date using FileStat
    FileStat fileStat = await file.stat();
    DateTime lastModifiedDate = fileStat.modified;

    final music = Music(
      path: file.path,
      folderName: path.basename(path.dirname(file.path)),
      lastModified: lastModifiedDate,
      title: title,
      album: album,
      artist: artist,
      duration: metadata.durationMs?.round() ?? 0,
      picture: picture,
      year: year,
      genre: genre,
      size: fileStat.size,
      isFavorite: SongData.isFavorite(file.path),  // Initialize favorite state
    );

    _allSongs.add(music);
    _log("Added song: $title by $artist");
  } catch (e) {
    _log('Error parsing file ${file.path}: $e');
  }
}

  // MARK: Playlist Management
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

  Future<void> refreshPlaylists() async {
    await PlaylistManager.load();
    notifyListeners();
  }

  // MARK: Search and Sort

  void setSearchQuery(String query) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _searchQuery = query.toLowerCase();

    _debounceTimer = Timer(_debounceDuration, () {
      _filterAndSortSongs();
    });

    notifyListeners();
  }

  void _filterAndSortSongs() {
    _log("Filtering and sorting songs");
    if (_searchQuery.isEmpty) {
      _sortedSongs = List.from(_allSongs);
      // Filter to only show favorite songs when sorting by favorites
      if (_sortBy == 'favorite') {
        _sortedSongs = _sortedSongs.where((song) => song.isFavorite).toList();
      }
      _applySorting();
    } else {
      final fuse = Fuzzy(
        _allSongs,
        options: FuzzyOptions(
          keys: [
            WeightedKey(
              name: 'title',
              getter: (Music song) => song.title.toLowerCase(),
              weight: 80,
            ),
            WeightedKey(
              name: 'artist',
              getter: (Music song) => song.artist.toLowerCase(),
              weight: 40,
            ),
            WeightedKey(
              name: 'album',
              getter: (Music song) => song.album.toLowerCase(),
              weight: 20,
            ),
          ],
          threshold: 0.4, // Lower threshold for more results
          distance: 100, // Increased distance for better fuzzy matching
        ),
      );

      final results = fuse.search(_searchQuery);

      // Sort by score (higher score = better match)
      results.sort((a, b) => a.score.compareTo(b.score));

      _sortedSongs = results.map((r) => r.item).toList();
    }

    notifyListeners();
  }

  void _applySorting() {
    _log("Applying sorting: by $_sortBy, ascending: $_sortAscending");
    if (_sortBy == 'favorite') {
      _sortedSongs.sort((a, b) {
        if (a.isFavorite == b.isFavorite) {
          return a.title.compareTo(b.title);
        }
        return b.isFavorite ? 1 : -1;
      });
    } else {
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
          case 'modified':
            comparison = b.lastModified.compareTo(a.lastModified);
            break;
          case 'year':
            // Parse years to integers for proper numerical comparison
            int yearA = int.tryParse(a.year) ?? 0;
            int yearB = int.tryParse(b.year) ?? 0;
            comparison = yearA.compareTo(yearB);
            break;
          case 'plays':
            comparison = SongData.getPlayCount(b.path).compareTo(SongData.getPlayCount(a.path));
            break;
          default:
            comparison = a.title.compareTo(b.title);
        }
        return _sortAscending ? comparison : -comparison;
      });
    }

    notifyListeners();
  }

  void sortSongs({String? sortBy, bool? ascending}) {
    _log(
        "Sorting songs: by ${sortBy ?? _sortBy}, ascending: ${ascending ?? _sortAscending}");
    _sortBy = sortBy ?? _sortBy;
    _sortAscending = ascending ?? _sortAscending;
    _filterAndSortSongs();
    Settings.setLibrarySongSort(_sortBy, _sortAscending);
  }

  Future<void> loadSortSettings() async {
    _sortBy = Settings.songSortBy;
    _sortAscending = Settings.songSortAscending;
  }

  // MARK: Metadata and Playback State
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

  // MARK: Utility Methods
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
                  path.extension(file.path).toLowerCase() == '.flac' ||
                  path.extension(file.path).toLowerCase() == '.m4a'))
          .toList();

      _log("Found ${files.length} .mp3, .flac and .m4a files");
      return files;
    } catch (e) {
      _log("Error while listing files: $e");
      return [];
    }
  }

  Future<void> _handleSongCompletion() async {
    _log("Handling song completion");
    
    // Increment play count for the current song
    if (_currentSongIndex != null && _playingSongs.isNotEmpty) {
      await SongData.incrementPlayCount(_playingSongs[_currentSongIndex!].path);
    }
    
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

  double _easeOutVolume(double progress) {
    // Use ease-out cubic curve for more natural volume fade
    return (1 - progress) * (1 - progress) * (1 - progress);
  }

  void _handleFadeOut() {
    if (_fadeTimer == null && _remainingTime != null) {
      // Store original volume when fade starts
      _originalVolume ??= _audioPlayer.volume;
      
      _fadeTimer = Timer.periodic(Duration(milliseconds: fadeUpdateInterval), (timer) {
        if (_remainingTime == null || _remainingTime!.inSeconds <= 0) {
          _fadeTimer?.cancel();
          _fadeTimer = null;
          return;
        }

        // Calculate progress (0.0 to 1.0) where 1.0 is start of fade and 0.0 is end
        final progress = _remainingTime!.inMilliseconds / (fadeStartSeconds * 1000);
        
        // Apply ease-out curve to the volume
        final volumeMultiplier = _easeOutVolume(1 - progress);
        final targetVolume = _originalVolume! * volumeMultiplier;
        
        _audioPlayer.setVolume(targetVolume.clamp(0.0, 1.0));
      });
    }
  }

  // MARK: Sleep Timer methods
  void startSleepTimer(int minutes) {
    _setSleepTimerMinutes = minutes;
    _setRemainingTime = Duration(minutes: minutes);
    _sleepTimer?.cancel();
    _fadeTimer?.cancel();
    
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime != null && _remainingTime!.inSeconds > 0) {
        _setRemainingTime = _remainingTime! - const Duration(seconds: 1);
        
        // Start fade out when 10 seconds remaining
        if (_remainingTime!.inSeconds <= fadeStartSeconds && _remainingTime!.inSeconds > 0) {
          _handleFadeOut();
        }
        
        // When timer hits zero
        if (_remainingTime!.inSeconds <= 0) {
          cancelSleepTimer();
          pauseSong();
          // Restore original volume after a brief pause
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_originalVolume != null) {
              _audioPlayer.setVolume(_originalVolume!);
              _originalVolume = null;
            }
          });
        }
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    // Only reset the minutes if we're not in the middle of the sleep animation
    if (_sleepTimerMinutes != 0) {
      _setSleepTimerMinutes = null;
    }
    notifyListeners();
  }

  void _log(String message) {
    //print("NPlayer: $message");
  }

  @override
  void dispose() {
    _log("Disposing NPlayer");
    _audioPlayer.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // MARK: Server-related methods

  Future<void> startServer({int port = 8080}) async {
    _log("Starting server on port $port");
    _server = NServer(this);
    await _server!.start(port: port);
    _isServerOn = true;
    notifyListeners();
  }

  Future<void> stopServer() async {
    _log("Stopping server");
    if (_server != null) {
      await _server!.stop();
      _server = null;
      _isServerOn = false;
      notifyListeners();
    }
  }

  Future<void> connectToServer(String host, int port) async {
    if (_client == null) {
      _client = NClient(this);
    }
    await _client!.connectAndPlay(host, port);
  }

  Future<void> toggleFavorite() async {
    final currentSong = getCurrentSong();
    if (currentSong != null) {
      currentSong.isFavorite = !currentSong.isFavorite;
      await SongData.setFavorite(currentSong.path, currentSong.isFavorite);
      notifyListeners();
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
          playlists: song.playlists,
          isFavorite: song.isFavorite,
        );
      }

      _filterAndSortSongs();
      notifyListeners();
    } catch (e) {
      _log("Error updating metadata: $e");
      rethrow;
    }
  }

  /// Deletes a song from the library
  Future<void> deleteSong(Music song) async {
    _log("Deleting song ${song.title}");
    try {
      final songFile = File(song.path);
      if (await songFile.exists()) {
        await songFile.delete();
      }

      // Remove from all lists
      _allSongs.remove(song);
      _playingSongs.remove(song);
      _sortedSongs.remove(song);

      // Update current song index if needed
      if (_currentSongIndex != null && _playingSongs.isNotEmpty) {
        if (_currentSongIndex! >= _playingSongs.length) {
          _currentSongIndex = _playingSongs.length - 1;
        }
      } else if (_playingSongs.isEmpty) {
        _currentSongIndex = null;
      }

      notifyListeners();
    } catch (e) {
      _log("Error deleting song: $e");
      rethrow;
    }
  }

  // Share the current song file
  Future<void> shareSong(Music song) async {
    try {
      final file = File(song.path);
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(song.path)],
          subject: '${song.title} by ${song.artist}',
        );
      } else {
        throw Exception('File not found');
      }
    } catch (e) {
      _log('Error sharing song: $e');
      rethrow;
    }
  }
}
