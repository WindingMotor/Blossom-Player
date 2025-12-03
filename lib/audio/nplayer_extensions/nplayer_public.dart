part of '../nplayer.dart';

/// UUID Validator - matches server-side validation
class Validator {
  static bool isValidUuid(String? uuid) {
    if (uuid == null || uuid.isEmpty) {
      print('[Validator] UUID is null or empty');
      return false;
    }
    if (!uuid.startsWith('user-')) {
      print('[Validator] UUID does not start with "user-": $uuid');
      return false;
    }
    if (uuid.length < 15 || uuid.length > 50) {
      print('[Validator] UUID length invalid (${uuid.length}): $uuid');
      return false;
    }
    final isValid = RegExp(r'^user-[a-zA-Z0-9\-]+$').hasMatch(uuid);
    if (!isValid) {
      print('[Validator] UUID contains invalid characters: $uuid');
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
    print('[NPlayerPublic] Initializing public sharing...');
    
    // Ensure UUID exists
    if (Settings.uuid.isEmpty) {
      print('[NPlayerPublic] UUID is empty, generating new one...');
      await Settings.generateAndSaveUuid();
      print('[NPlayerPublic] Generated UUID: ${Settings.uuid}');
    } else {
      print('[NPlayerPublic] Existing UUID: ${Settings.uuid}');
    }
    
    // Ensure username exists
    if (Settings.publicUsername == null || Settings.publicUsername!.isEmpty) {
      print('[NPlayerPublic] Username is empty, initializing...');
      await Settings.initializeUsername();
      print('[NPlayerPublic] Username set to: ${Settings.publicUsername}');
    } else {
      print('[NPlayerPublic] Existing username: ${Settings.publicUsername}');
    }
    
    // Start heartbeat timer
    _startHeartbeatTimer();
    
    print('[NPlayerPublic] Public sharing initialized successfully');
    print('[NPlayerPublic] Sharing enabled: ${Settings.isPublicSharingEnabled}');
  }
  
  /// Start periodic heartbeat when enabled
  void _startHeartbeatTimer() {
    print('[NPlayerPublic] Starting heartbeat timer (30s interval)');
    
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (Settings.isPublicSharingEnabled && _isPlaying) {
        print('[NPlayerPublic] Sending heartbeat...');
        _sendHeartbeat();
      }
    });
  }


  /// Update public status on server
  Future<void> updatePublicStatus() async {
    print('[NPlayerPublic] updatePublicStatus called');
    print('[NPlayerPublic] Sharing enabled: ${Settings.isPublicSharingEnabled}');
    
    if (!Settings.isPublicSharingEnabled) {
      print('[NPlayerPublic] Sharing disabled, skipping update');
      return;
    }
    
    final currentSong = getCurrentSong();
    if (currentSong == null) {
      print('[NPlayerPublic] No current song, skipping update');
      return;
    }
    
    print('[NPlayerPublic] Updating status for: ${currentSong.title} - ${currentSong.artist}');
    
    try {
      // Convert album art to base64 (if available)
      String? albumArtBase64;
      if (currentSong.picture != null && currentSong.picture!.isNotEmpty) {
        final pictureSize = currentSong.picture!.length;
        print('[NPlayerPublic] Original album art size: ${pictureSize} bytes');
        
        // Decode and compress the image to keep under 100KB
        try {
          img.Image? image = img.decodeImage(currentSong.picture!);
          if (image != null) {
            // Resize to 300x300 max and compress with quality adjustment
            img.Image resized = img.copyResize(image, width: 300, height: 300);
            
            // Start with quality 85 and reduce if needed to stay under 100KB
            int quality = 85;
            List<int> compressed = img.encodeJpg(resized, quality: quality);
            
            // Keep reducing quality until under 100KB
            while (compressed.length > 100000 && quality > 30) {
              quality -= 10;
              compressed = img.encodeJpg(resized, quality: quality);
            }
            
            albumArtBase64 = base64Encode(compressed);
            print('[NPlayerPublic] Compressed album art: ${compressed.length} bytes (quality: $quality)');
          }
        } catch (e) {
          print('[NPlayerPublic] Failed to compress album art: $e');
        }
      } else {
        print('[NPlayerPublic] No album art available');
      }
          
      final requestBody = {
        'uuid': Settings.uuid,
        'username': Settings.publicUsername ?? 'Music Lover',
        'currentSong': currentSong.title,
        'currentArtist': currentSong.artist,
        'albumArt': albumArtBase64,
      };
      
      print('[NPlayerPublic] Sending POST to $_serverUrl/user/update');
      
      final response = await http.post(
        Uri.parse('$_serverUrl/user/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          print('[NPlayerPublic] Request timed out after 10 seconds');
          throw TimeoutException('Server request timed out');
        },
      );
      
      print('[NPlayerPublic] Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        
        if (jsonResponse is Map<String, dynamic>) {
          if (jsonResponse['success'] == true) {
            print('[NPlayerPublic] ✅ Server update successful!');
          } else {
            print('[NPlayerPublic] ❌ Server returned success=false');
            print('[NPlayerPublic] Error: ${jsonResponse['error']}');
          }
        } else {
          print('[NPlayerPublic] ⚠️ Unexpected response format');
        }
      } else {
        print('[NPlayerPublic] ❌ Server returned error ${response.statusCode}');
        print('[NPlayerPublic] Error: ${response.body}');
      }
      
    } catch (e, stackTrace) {
      print('[NPlayerPublic] 💥 Exception during update: $e');
      print('[NPlayerPublic] Stack trace: $stackTrace');
    }
  }
  
  /// Fetch another user's current status
  Future<PublicUserStatus?> fetchUserStatus(String uuid) async {
    print('[NPlayerPublic] fetchUserStatus called for: $uuid');
    
    if (!Validator.isValidUuid(uuid)) {
      print('[NPlayerPublic] ❌ Invalid UUID format: $uuid');
      return null;
    }
    
    print('[NPlayerPublic] UUID validation passed');

    try {
      final url = '$_serverUrl/user/$uuid';
      print('[NPlayerPublic] Fetching from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('[NPlayerPublic] Fetch request timed out');
          throw TimeoutException('Fetch timed out');
        },
      );

      print('[NPlayerPublic] Fetch response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        
        if (jsonResponse is Map<String, dynamic>) {
          // New API format: {"success": true, "data": {...}}
          if (jsonResponse.containsKey('success') && jsonResponse['success'] == true) {
            print('[NPlayerPublic] Using new API format (success/data wrapper)');
            final data = jsonResponse['data'];
          
            if (data != null) {
              print('[NPlayerPublic] Data found (album art: ${data['albumArt'] != null ? '${(data['albumArt'] as String).length} chars' : 'none'})');
              final status = PublicUserStatus.fromJson(data);
              print('[NPlayerPublic] ✅ Status parsed: ${status.username} - ${status.displayText}');
              return status;
            } else {
              print('[NPlayerPublic] ❌ Data field is null');
            }
          }
          // Old format (backward compatibility): {...}
          else if (jsonResponse.containsKey('uuid')) {
            print('[NPlayerPublic] Using old API format (direct data)');
            final status = PublicUserStatus.fromJson(jsonResponse);
            print('[NPlayerPublic] ✅ Status parsed: ${status.username} - ${status.displayText}');
            return status;
          } else {
            print('[NPlayerPublic] ❌ Response missing both success and uuid fields');
          }
        } else {
          print('[NPlayerPublic] ❌ Response is not a Map<String, dynamic>');
        }
        
        print('[NPlayerPublic] Invalid response format from server');
        return null;
        
      } else if (response.statusCode == 404) {
        print('[NPlayerPublic] ❌ User $uuid not found on server (404)');
        return null;
        
      } else if (response.statusCode == 422) {
        print('[NPlayerPublic] ❌ Validation error (422)');
        return null;
        
      } else {
        print('[NPlayerPublic] ❌ Server error ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      print('[NPlayerPublic] 💥 Exception fetching user $uuid: $e');
      print('[NPlayerPublic] Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Send heartbeat to keep status alive
  Future<void> _sendHeartbeat() async {
    if (!Settings.isPublicSharingEnabled) return;
    
    print('[NPlayerPublic] Sending heartbeat for ${Settings.uuid}');
    
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/user/heartbeat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uuid': Settings.uuid}),
      ).timeout(Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        print('[NPlayerPublic] Heartbeat sent successfully');
      } else {
        print('[NPlayerPublic] Heartbeat failed: ${response.statusCode}');
      }
    } catch (e) {
      print('[NPlayerPublic] Heartbeat error: $e');
    }
  }
  
  /// Toggle public sharing on/off
  Future<void> togglePublicSharing(bool enabled) async {
    print('[NPlayerPublic] togglePublicSharing called: $enabled');
    
    await Settings.setPublicSharingEnabled(enabled);
    print('[NPlayerPublic] Setting saved: ${Settings.isPublicSharingEnabled}');
    
    if (enabled && _isPlaying) {
      print('[NPlayerPublic] Sharing enabled and playing, updating status...');
      await updatePublicStatus();
    }
    
    print('[NPlayerPublic] Public sharing ${enabled ? 'ENABLED' : 'DISABLED'}');
    notifyListeners();
  }
  
  /// Set public username
  Future<void> setPublicUsername(String username) async {
    print('[NPlayerPublic] setPublicUsername called: $username');
    
    await Settings.setPublicUsername(username);
    print('[NPlayerPublic] Username saved: ${Settings.publicUsername}');
    
    // Update server if currently sharing
    if (Settings.isPublicSharingEnabled && _isPlaying) {
      print('[NPlayerPublic] Updating server with new username...');
      await updatePublicStatus();
    }
    
    notifyListeners();
  }
  
  /// Get shareable UUID for friends
  String getShareableId() {
    print('[NPlayerPublic] getShareableId called: ${Settings.uuid}');
    return Settings.uuid;
  }
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
    print('[PublicUserStatus] Parsing JSON...');
    
    try {
      final status = PublicUserStatus(
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
      
      print('[PublicUserStatus] Parsed: ${status.username} - Song: ${status.currentSong}, Has art: ${status.albumArt != null}');
      return status;
      
    } catch (e, stackTrace) {
      print('[PublicUserStatus] ❌ Error parsing: $e');
      print('[PublicUserStatus] Stack trace: $stackTrace');
      
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
