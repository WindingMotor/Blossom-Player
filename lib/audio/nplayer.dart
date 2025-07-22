import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart' as ap; // Add prefix 
import 'package:audio_session/audio_session.dart';
import 'package:blossom/audio/nplaylist.dart';
import 'package:blossom/audio/nserver.dart';
import 'package:blossom/binder/ios_binder.dart';
import 'package:blossom/tools/settings.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:headset_connection_event/headset_event.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:blossom/audio/song_data.dart';
import 'package:blossom/audio/nplayer_extensions/nplayer_audio_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audio_service/audio_service.dart' as audio_service;

part 'nplayer_extensions/nplayer_sorting.dart';
part 'nplayer_extensions/nplayer_playback.dart';
part 'nplayer_extensions/nplayer_audio_controls.dart';
part 'nplayer_extensions/nplayer_playlist_management.dart';
part 'nplayer_extensions/nplayer_song_loading.dart';
part 'nplayer_extensions/nplayer_server.dart';
part 'nplayer_extensions/nplayer_song_utils.dart';

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
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  CustomAudioHandler? _audioHandler;
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
  bool _isChangingSong = false;
  bool _isPausedByInterruption = false;

  List<String> get playlists => PlaylistManager.playlistNames;

  NServer? _server;
  NClient? _client;
  bool _isServerOn = false;
  
  Timer? _debounceTimer;
  final Duration _debounceDuration = Duration(milliseconds: 300);

  final HeadsetEvent _headsetPlugin = HeadsetEvent();
  bool _isHeadphonesConnected = false;
  
  Timer? _sleepTimer;
  Timer? _fadeTimer;
  int? _sleepTimerMinutes;
  Duration? _remainingTime;
  double? _originalVolume;
  static const fadeStartSeconds = 10;
  static const fadeUpdateInterval = 50;

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
  String get searchQuery => _searchQuery;
  bool get isPausedByInterruption => _isPausedByInterruption;
  bool get isServerOn => _isServerOn;
  bool get isHeadphonesConnected => _isHeadphonesConnected;
  int? get sleepTimerMinutes => _sleepTimerMinutes;
  Duration? get remainingTime => _remainingTime;

  bool _isInitialized = false;
  Completer<void>? _initializationCompleter;
  late AudioSession _audioSession;
  // Track audio focus state for internal use
  bool _hasAudioFocus = false;

  Duration get duration {
    return getCurrentSong()?.duration != null
        ? Duration(milliseconds: getCurrentSong()!.duration)
        : Duration.zero;
  }
  
  Music? getCurrentSong() {
    if (_currentSongIndex == null ||
        _playingSongs.isEmpty ||
        _currentSongIndex! >= _playingSongs.length) {
      return null;
    }
    return _playingSongs[_currentSongIndex!];
  }
  
  // MARK: Constructor and Initialization
  // Helper to allow extensions to trigger notifyListeners correctly
  void _internalNotifyListeners() {
    notifyListeners();
  }

  NPlayer() {
    _log("Initializing NPlayer...");
    _initialize();
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized && _initializationCompleter != null) {
      await _initializationCompleter!.future;
    }
  }

Future<void> _initializeAudioHandler() async {
  try {
    _audioHandler = await audio_service.AudioService.init(
      builder: () => CustomAudioHandler(_audioPlayer, this),
      config: const audio_service.AudioServiceConfig(
        androidNotificationChannelId: 'com.wmstudios.blossom.audio',
        androidNotificationChannelName: 'Blossom Music Player',
        androidNotificationClickStartsActivity: true,
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
        // Optional: Add custom notification icon
        androidNotificationIcon: 'mipmap/ic_launcher',
        // Optional: Show controls in f notification
        androidShowNotificationBadge: false,
        preloadArtwork: false,
      ),
    );
    
    _log("AudioHandler initialized successfully");
  } catch (e) {
    _log("Error initializing AudioHandler: $e");
    _audioHandler = CustomAudioHandler(_audioPlayer, this);
    _log("Fallback: Created AudioHandler directly");
  }
}

Future<void> _initialize() async {
  if (_isInitialized) return;
  _isInitialized = true;

  try {
    // Configure AudioPlayer to NOT handle audio focus automatically
    // This prevents conflicts with our AudioHandler
    try {
      await _audioPlayer.setAudioContext(ap.AudioContext(
        android: ap.AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: ap.AndroidContentType.music,
          usageType: ap.AndroidUsageType.media,
          audioFocus: ap.AndroidAudioFocus.none, // Disable audioplayers focus management
        ),
        iOS: ap.AudioContextIOS(
          category: ap.AVAudioSessionCategory.playback,
          options: {}, // Use empty set to avoid potential option conflicts
        ),
      ));
      _log("AudioContext configured successfully");
    } catch (e) {
      _log("Error configuring AudioContext (continuing anyway): $e");
      // Continue without audio context configuration - this is not critical
    }

    // Initialize AudioSession (this will be managed by AudioHandler only)
    _audioSession = await AudioSession.instance;
      
    // OneUI 7 specific configuration
    if (Platform.isAndroid) {
      try {
        await _audioSession.configure(AudioSessionConfiguration.music().copyWith(
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
            flags: AndroidAudioFlags.none,
          ),
          // Use GAIN_TRANSIENT instead of GAIN to be less aggressive
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
          androidWillPauseWhenDucked: true, // Changed to true for OneUI 7
        ));
        
        // Delayed activation to prevent lock screen trigger
        await Future.delayed(const Duration(milliseconds: 500));
        
        try {
          final focusGranted = await _audioSession.setActive(true);
          if (focusGranted) {
            _hasAudioFocus = true;
            _log("Audio session activated successfully");
          }
        } catch (e) {
          _log("Error activating audio session: $e");
          // Don't throw error, continue without focus initially
        }
      } catch (e) {
        _log("Error configuring audio session: $e");
        // Continue without audio session configuration
      }
    } else {
      try {
        await _audioSession.configure(AudioSessionConfiguration.music());
        _log("iOS audio session configured");
      } catch (e) {
        _log("Error configuring iOS audio session: $e");
        // Continue without iOS audio session configuration
      }
    }

    // Initialize AudioHandler
    await _initializeAudioHandler();
      
      // Initialize synchronous components
      _setupAudioPlayerListeners();
      _initHeadsetDetection();
      _server = NServer(this);
      _client = NClient(this);

      // Initialize asynchronous components
      await _initializeFromSettings();
      await PlaylistManager.load();
      await _loadSongs();
      await loadSortSettings();
      
      // Apply initial sort based on loaded settings
      sortSongs(sortBy: _sortBy, ascending: _sortAscending);

      _log("NPlayer initialization complete.");
      notifyListeners(); // Notify UI that everything is ready
    } catch (e) {
      _log('Error during initialization: $e');
      rethrow;
    }
  }

  Future<void> _initializeFromSettings() async {
    _log("Initializing from settings");
    await setVolume(Settings.volume);
    _repeatMode = Settings.repeatMode;
    await _loadFavorites();
    _log("Initialized from settings: volume=${Settings.volume}, repeatMode=$_repeatMode");
  }

  void _setupAudioPlayerListeners() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      final isNowPlaying = state == ap.PlayerState.playing;
      if (_isPlaying != isNowPlaying) {
        _isPlaying = isNowPlaying;
        notifyListeners();
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      _currentPosition = position;
      
      // Sync position with AudioHandler if it exists
      if (_audioHandler != null) {
        _audioHandler!.playbackState.add(_audioHandler!.playbackState.value.copyWith(
          updatePosition: position,
        ));
      }
      
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

      if (wasConnected && !_isHeadphonesConnected && _isPlaying) {
        pauseSong();
      }
      notifyListeners();
    });
  }

  // MARK: Utility Methods
  void _log(String message) {
    if (kDebugMode) {
      print("[NPlayer] $message");
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
