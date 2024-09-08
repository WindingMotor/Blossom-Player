// nserver.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blossom/audio/nplayer.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:http/http.dart' as http;


class NServer {
  HttpServer? _server;
  final NPlayer _nplayer;
  StreamSubscription? _songChangeSubscription;
  String? _currentIp;
  bool _isRunning = false;

  NServer(this._nplayer);

  Future<void> start() async {
    if (_isRunning) {
      print('Server is already running.');
      return;
    }

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
      _currentIp = _server!.address.address;
      _isRunning = true;
      print('Server running on $_currentIp:${_server!.port}');

      _songChangeSubscription = _nplayer.songChangeStream.listen((_) {
        print('Song changed, updating server');
      });

      _server!.listen(_handleRequest, onError: (e) {
        print('Error handling request: $e');
      });
    } catch (e) {
      print('Failed to start server: $e');
    }
  }

  Future<void> stop() async {
    if (!_isRunning) {
      print('Server is not running.');
      return;
    }

    try {
      await _songChangeSubscription?.cancel();
      await _server?.close(force: true);
      _server = null;
      _currentIp = null;
      _isRunning = false;
      print('Server stopped');
    } catch (e) {
      print('Error stopping server: $e');
    }
  }

  bool get isRunning => _isRunning;

  void _handleRequest(HttpRequest request) {
    print('Received request for: ${request.uri.path}');

    switch (request.uri.path) {
      case '/stream':
        _handleStreamRequest(request);
        break;
      case '/metadata':
        _handleMetadataRequest(request);
        break;
      default:
        _serveHtmlPage(request);
    }
  }

  void _serveHtmlPage(HttpRequest request) {
    request.response
      ..headers.contentType = ContentType.html
      ..write('''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Blossom Music Server</title>
</head>
<body>
    <h1>Welcome to the Blossom Music Server!</h1>
    <p>This server is running and ready to stream music.</p>
    <p>Use the /stream endpoint to access the current playing song.</p>
    <p>Use the /metadata endpoint to get information about the current song.</p>
</body>
</html>
''')
      ..close();
  }

  Future<void> _handleStreamRequest(HttpRequest request) async {
    print('Received stream request');
    final currentSong = _nplayer.getCurrentSong();
    if (currentSong != null && await File(currentSong.path).exists()) {
      print('Serving stream for: ${currentSong.title}');
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      await File(currentSong.path).openRead().pipe(request.response);
      print('Stream sent successfully');
    } else {
      print('No current song or file not found');
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('No current song or file not found')
        ..close();
    }
  }

  Future<void> _handleMetadataRequest(HttpRequest request) async {
    print('Received metadata request');
    final currentSong = _nplayer.getCurrentSong();
    if (currentSong != null) {
      try {
        final metadata = await MetadataGod.readMetadata(file: currentSong.path);
        final metadataMap = {
          'title': metadata.title ?? currentSong.title,
          'artist': metadata.artist ?? currentSong.artist,
          'album': metadata.album ?? currentSong.album,
          'year': metadata.year?.toString() ?? currentSong.year,
          'genre': metadata.genre ?? currentSong.genre,
          'duration': metadata.durationMs ?? currentSong.duration,
          'picture': currentSong.picture != null
              ? base64Encode(currentSong.picture!)
              : null,
        };

        request.response
          ..headers.contentType = ContentType.json
          ..write(json.encode(metadataMap))
          ..close();
        print('Metadata sent successfully');
      } catch (e) {
        print('Error reading metadata: $e');
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..write('Error reading metadata')
          ..close();
      }
    } else {
      print('No current song');
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('No current song')
        ..close();
    }
  }

  String? get currentIp => _currentIp;

  static Future<bool> isValidServer(String ip) async {
    try {
      final response = await http.get(Uri.parse('http://$ip:8080'))
          .timeout(Duration(seconds: 5));
      return response.statusCode == 200 && response.body.contains('Blossom Music Server');
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getRemoteMetadata(String ip) async {
    final response = await http.get(Uri.parse('http://$ip:8080/metadata'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load metadata');
    }
  }
}
