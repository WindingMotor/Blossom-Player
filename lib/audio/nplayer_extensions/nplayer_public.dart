part of '../nplayer.dart';

/// UUID Validator - matches server-side validation
class Validator {
  static bool isValidUuid(String? uuid) {
    if (uuid == null || uuid.isEmpty) {
      Log.w(LogTag.social, 'UUID is null or empty');
      return false;
    }
    if (!uuid.startsWith('user-')) {
      Log.w(LogTag.social, 'UUID does not start with "user-": $uuid');
      return false;
    }
    if (uuid.length < 15 || uuid.length > 50) {
      Log.w(LogTag.social, 'UUID length invalid (${uuid.length}): $uuid');
      return false;
    }
    final isValid = RegExp(r'^user-[a-zA-Z0-9\-]+$').hasMatch(uuid);
    if (!isValid) {
      Log.w(LogTag.social, 'UUID contains invalid characters: $uuid');
    }
    return isValid;
  }
}


/// Extension for public music sharing features
extension NPlayerPublic on NPlayer {
  static const String _serverUrl = 'https://blossom-server-production.up.railway.app';
  
  // Public getters
  String get userUuid => Settings.uuid;
  String? get publicUsername => Settings.publicUsername;
  bool get isSharingEnabled => Settings.isPublicSharingEnabled;
  
  /// Initialize public sharing (call this in NPlayer._initialize)
  Future<void> _initializePublicSharing() async {
    Log.d(LogTag.social, 'Initializing public sharing...');

    if (Settings.uuid.isEmpty) {
      await Settings.generateAndSaveUuid();
      Log.d(LogTag.social, 'Generated UUID: ${Settings.uuid}');
    }

    if (Settings.publicUsername == null || Settings.publicUsername!.isEmpty) {
      await Settings.initializeUsername();
      Log.d(LogTag.social, 'Username set to: ${Settings.publicUsername}');
    }

    _startHeartbeatTimer();
    Log.i(LogTag.social, 'Public sharing initialized — enabled: ${Settings.isPublicSharingEnabled}');
  }
  
  /// Start periodic heartbeat when enabled
  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (Settings.isPublicSharingEnabled && _isPlaying) {
        _sendHeartbeat();
      }
    });
  }


  /// Update public status on server
  Future<void> updatePublicStatus() async {
    if (!Settings.isPublicSharingEnabled) return;

    final currentSong = getCurrentSong();
    if (currentSong == null) return;

    Log.d(LogTag.social, 'Updating status: ${currentSong.title} — ${currentSong.artist}');

    try {
      String? albumArtBase64;
      if (currentSong.picture != null && currentSong.picture!.isNotEmpty) {
        try {
          img.Image? image = img.decodeImage(currentSong.picture!);
          if (image != null) {
            img.Image resized = img.copyResize(image, width: 300, height: 300);
            int quality = 85;
            List<int> compressed = img.encodeJpg(resized, quality: quality);
            while (compressed.length > 100000 && quality > 30) {
              quality -= 10;
              compressed = img.encodeJpg(resized, quality: quality);
            }
            albumArtBase64 = base64Encode(compressed);
            Log.v(LogTag.social, 'Album art compressed: ${compressed.length}B (q$quality)');
          }
        } catch (e) {
          Log.w(LogTag.social, 'Failed to compress album art: $e');
        }
      }

      final response = await http.post(
        Uri.parse('$_serverUrl/user/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uuid': Settings.uuid,
          'username': Settings.publicUsername ?? 'Music Lover',
          'currentSong': currentSong.title,
          'currentArtist': currentSong.artist,
          'albumArt': albumArtBase64,
        }),
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Server request timed out'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse is Map<String, dynamic> && jsonResponse['success'] != true) {
          Log.w(LogTag.social, 'Server returned success=false: ${jsonResponse['error']}');
        }
      } else {
        Log.w(LogTag.social, 'Server error ${response.statusCode}: ${response.body}');
      }
    } catch (e, stackTrace) {
      Log.e(LogTag.social, 'Exception during status update: $e', stackTrace);
    }
  }
  
  /// Fetch another user's current status
  Future<PublicUserStatus?> fetchUserStatus(String uuid) async {
    if (!Validator.isValidUuid(uuid)) return null;

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/user/$uuid'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Fetch timed out'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse is! Map<String, dynamic>) {
          Log.w(LogTag.social, 'Unexpected response type for $uuid');
          return null;
        }

        if (jsonResponse.containsKey('success') && jsonResponse['success'] == true) {
          final data = jsonResponse['data'];
          if (data == null) return null;
          return PublicUserStatus.fromJson(data);
        } else if (jsonResponse.containsKey('uuid')) {
          return PublicUserStatus.fromJson(jsonResponse);
        }

        Log.w(LogTag.social, 'Invalid response format for $uuid');
        return null;
      } else if (response.statusCode == 404 || response.statusCode == 422) {
        return null;
      } else {
        Log.w(LogTag.social, 'Server error ${response.statusCode} for $uuid');
        return null;
      }
    } catch (e, stackTrace) {
      Log.e(LogTag.social, 'Exception fetching user $uuid: $e', stackTrace);
      return null;
    }
  }
  
  /// Send heartbeat to keep status alive
  Future<void> _sendHeartbeat() async {
    if (!Settings.isPublicSharingEnabled) return;
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/user/heartbeat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uuid': Settings.uuid}),
      ).timeout(Duration(seconds: 5));
      if (response.statusCode != 200) {
        Log.w(LogTag.social, 'Heartbeat failed: ${response.statusCode}');
      }
    } catch (e) {
      Log.w(LogTag.social, 'Heartbeat error: $e');
    }
  }
  
  /// Toggle public sharing on/off
  Future<void> togglePublicSharing(bool enabled) async {
    await Settings.setPublicSharingEnabled(enabled);
    Log.i(LogTag.social, 'Public sharing ${enabled ? 'ENABLED' : 'DISABLED'}');

    if (enabled) {
      _startHeartbeatTimer();
      if (_isPlaying) await updatePublicStatus();
    } else {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
    _internalNotifyListeners();
  }

  /// Set public username
  Future<void> setPublicUsername(String username) async {
    await Settings.setPublicUsername(username);
    Log.d(LogTag.social, 'Username saved: ${Settings.publicUsername}');
    if (Settings.isPublicSharingEnabled && _isPlaying) await updatePublicStatus();
    _internalNotifyListeners();
  }

  /// Get shareable UUID for friends
  String getShareableId() => Settings.uuid;
}


/// Public user status data class
class PublicUserStatus {
  final String uuid;
  final String username;
  final String? currentSong;
  final String? currentArtist;
  final String? albumArt;
  final DateTime lastSeen;
  final bool isOnline;

  PublicUserStatus({
    required this.uuid,
    required this.username,
    this.currentSong,
    this.currentArtist,
    this.albumArt,
    required this.lastSeen,
    required this.isOnline,
  });

  factory PublicUserStatus.fromJson(Map<String, dynamic> json) {
    try {
      return PublicUserStatus(
        uuid: json['uuid'] as String? ?? '',
        username: json['username'] as String? ?? 'Unknown User',
        currentSong: json['currentSong'] as String?,
        currentArtist: json['currentArtist'] as String?,
        albumArt: json['albumArt'] as String?,
        lastSeen: json['lastSeen'] != null
            ? DateTime.parse(json['lastSeen'] as String)
            : DateTime.now(),
        isOnline: json['isOnline'] as bool? ?? false,
      );
    } catch (e, stackTrace) {
      Log.e(LogTag.social, 'Error parsing PublicUserStatus: $e', stackTrace);
      return PublicUserStatus(
        uuid: json['uuid'] as String? ?? '',
        username: 'Unknown User',
        lastSeen: DateTime.now(),
        isOnline: false,
      );
    }
  }

  String get displayText {
    if (!isOnline) return 'Offline';
    if (currentSong == null || currentSong!.isEmpty) return 'Online';
    return 'Listening to $currentSong';
  }
  
  String get lastSeenAgo {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}
