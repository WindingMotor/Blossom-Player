import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:blossom/audio/nplayer.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class NServer {
  final NPlayer _player;
  HttpServer? _server;
  String? currentIp;
  bool isRunning = false;

  NServer(this._player);

  Future<void> start() async {
    if (isRunning) return;

    try {
      final addresses = await NetworkInterface.list(type: InternetAddressType.IPv4);
      final address = addresses.first.addresses.first;
      _server = await HttpServer.bind(address, 8080);
      currentIp = address.address;
      isRunning = true;

    _server!.listen((HttpRequest request) async {
      switch (request.uri.path) {
        case '/metadata':
          _handleMetadataRequest(request);
          break;
        case '/stream':
          await _handleStreamRequest(request);
          break;
        case '/position':
          _handlePositionRequest(request);
          break;
        default:
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
      }
    });

      print('Server running on $currentIp:8080');
    } catch (e) {
      print('Failed to start server: $e');
      isRunning = false;
    }
  }

  void _handleMetadataRequest(HttpRequest request) {
    final currentSong = _player.getCurrentSong();
    if (currentSong == null) {
      request.response
        ..statusCode = HttpStatus.noContent
        ..close();
      return;
    }

    final metadata = {
      'title': currentSong.title,
      'artist': currentSong.artist,
      'album': currentSong.album,
      'duration': currentSong.duration,
    };

    request.response
      ..headers.contentType = ContentType.json
      ..write(json.encode(metadata))
      ..close();
  }

  Future<void> _handleStreamRequest(HttpRequest request) async {
    final currentSong = _player.getCurrentSong();
    if (currentSong == null) {
      request.response
        ..statusCode = HttpStatus.noContent
        ..close();
      return;
    }

    final file = File(currentSong.path);
    if (!await file.exists()) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }

    final fileExtension = path.extension(currentSong.path).toLowerCase();
    final mimeType = fileExtension == '.mp3' ? 'audio/mpeg' : 'audio/flac';

    request.response.headers.add('Content-Type', mimeType);
    request.response.headers.add('Accept-Ranges', 'bytes');

    if (request.headers.value('range') != null) {
      await _handleRangeRequest(request, file);
    } else {
      await file.openRead().pipe(request.response);
    }
  }

  Future<void> _handleRangeRequest(HttpRequest request, File file) async {
    final range = request.headers.value('range')!;
    final fileSize = await file.length();
    final start = int.parse(range.split('=')[1].split('-')[0]);
    final end = fileSize - 1;

    request.response.statusCode = HttpStatus.partialContent;
    request.response.headers.add('Content-Range', 'bytes $start-$end/$fileSize');
    request.response.headers.add('Content-Length', (end - start + 1).toString());

    await file.openRead(start, end + 1).pipe(request.response);
  }

    void _handlePositionRequest(HttpRequest request) {
    final currentPosition = _player.currentPosition;
    final duration = _player.duration;

    final positionData = {
      'position': currentPosition.inMilliseconds,
      'duration': duration.inMilliseconds,
    };

    request.response
      ..headers.contentType = ContentType.json
      ..write(json.encode(positionData))
      ..close();
  }

  Future<void> stop() async {
    if (!isRunning) return;

    await _server?.close();
    _server = null;
    currentIp = null;
    isRunning = false;
    print('Server stopped');
  }

  static Future<bool> isValidServer(String ip) async {
    try {
      final response = await http.get(Uri.parse('http://$ip:8080/metadata'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}