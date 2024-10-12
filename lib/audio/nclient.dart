import 'dart:async';
import 'dart:convert';
import 'package:blossom/audio/nplayer.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

class NClient {
  final NPlayer _nplayer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _serverIp;
  Timer? _metadataCheckTimer;
  String? _currentSongTitle;

  NClient(this._nplayer);

  Future<void> connectToServer(String ip) async {
    if (!await _isValidServer(ip)) {
      throw Exception('Invalid server');
    }

    _serverIp = ip;
    _nplayer._isPlayingFromServer = true;
    await _initializePlayback();
  }

  Future<void> _initializePlayback() async {
    await _startStreamPlayback();
    await _syncPosition();
    _startMetadataCheck();
  }

  Future<void> _startStreamPlayback() async {
    final streamUrl = 'http://$_serverIp:8080/stream';
    await _audioPlayer.play(UrlSource(streamUrl));
    _nplayer._isPlaying = true;
    _nplayer.notifyListeners();
  }

  Future<void> _syncPosition() async {
    try {
      final response = await http.get(Uri.parse('http://$_serverIp:8080/position'));
      if (response.statusCode == 200) {
        final positionData = json.decode(response.body);
        final position = Duration(milliseconds: positionData['position']);
        await _audioPlayer.seek(position);
      }
    } catch (e) {
      print('Error syncing position: $e');
    }
  }

  void _startMetadataCheck() {
    _metadataCheckTimer = Timer.periodic(Duration(seconds: 1), (_) => _checkMetadata());
  }

  Future<void> _checkMetadata() async {
    try {
      final response = await http.get(Uri.parse('http://$_serverIp:8080/metadata'));
      if (response.statusCode == 200) {
        final metadata = json.decode(response.body);
        if (metadata['title'] != _currentSongTitle) {
          _currentSongTitle = metadata['title'];
          await _startStreamPlayback();
          await _syncPosition();
        }
        _updateNPlayerMetadata(metadata);
      }
    } catch (e) {
      print('Error checking metadata: $e');
    }
  }

  void _updateNPlayerMetadata(Map<String, dynamic> metadata) {
    // Update NPlayer's metadata properties
    _nplayer._currentPosition = Duration(milliseconds: metadata['position']);
    // Update other relevant properties in NPlayer
    _nplayer.notifyListeners();
  }

  Future<bool> _isValidServer(String ip) async {
    try {
      final response = await http.get(Uri.parse('http://$ip:8080/metadata'))
          .timeout(Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    _metadataCheckTimer?.cancel();
    await _audioPlayer.stop();
    _nplayer._isPlayingFromServer = false;
    _nplayer._isPlaying = false;
    _serverIp = null;
    _currentSongTitle = null;
    _nplayer.notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_nplayer._isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
    _nplayer._isPlaying = !_nplayer._isPlaying;
    _nplayer.notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
    _nplayer._currentPosition = position;
    _nplayer.notifyListeners();
  }

  void dispose() {
    _metadataCheckTimer?.cancel();
    _audioPlayer.dispose();
  }
}