import 'dart:io';
import 'dart:convert';
import 'package:blossom/audio/nplayer.dart';
import 'package:network_info_plus/network_info_plus.dart';

class NWebServer {
  final NPlayer player;
  HttpServer? _server;
  bool isRunning = false;
  String? _serverUrl;

  NWebServer(this.player);

  String? get serverUrl => _serverUrl;

Future<void> start({int port = 8080}) async {
  if (isRunning) return;

  try {
    // Use a safer fallback for the bind address.
    InternetAddress bindAddress = Platform.isIOS || Platform.isMacOS
        ? InternetAddress.loopbackIPv4
        : InternetAddress.anyIPv4;

    // Bind the server.
    _server = await HttpServer.bind(bindAddress, port, shared: true);
    isRunning = true;

    final info = NetworkInfo();
    final wifiIP = await info.getWifiIP();
    _serverUrl = 'http://${wifiIP ?? _server!.address.address}:${_server!.port}';

    print('Web server running at $_serverUrl');

    // Process incoming requests.
    await for (HttpRequest request in _server!) {
      _handleRequest(request);
    }
  } on SocketException catch (e) {
    print('SocketException: Failed to bind server: $e');
    stop(); // Ensure cleanup on failure.
    rethrow;
  } catch (e) {
    print('Failed to start web server: $e');
    stop(); // Ensure cleanup on other errors.
    rethrow;
  }
}


  Future<void> stop() async {
    if (!isRunning) return;
    await _server?.close();
    isRunning = false;
    _server = null;
    _serverUrl = null;
  }

  void _handleRequest(HttpRequest request) async {
    switch (request.method) {
      case 'GET':
        if (request.uri.path == '/') {
          _serveFile(request, 'web/index.html', 'text/html');
        } else if (request.uri.path == '/style.css') {
          _serveFile(request, 'web/style.css', 'text/css');
        } else if (request.uri.path == '/script.js') {
          _serveFile(request, 'web/script.js', 'application/javascript');
        } else if (request.uri.path == '/album-art' && player.getCurrentSong()?.picture != null) {
          _serveAlbumArt(request);
        } else if (request.uri.path == '/api/state') {
          _servePlayerState(request);
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
        }
        break;
      default:
        request.response
          ..statusCode = HttpStatus.methodNotAllowed
          ..close();
    }
  }

  void _serveFile(HttpRequest request, String path, String contentType) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        request.response.headers.contentType = ContentType.parse(contentType);
        await request.response.addStream(file.openRead());
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
    } finally {
      request.response.close();
    }
  }

  void _servePlayerState(HttpRequest request) {
    final currentSong = player.getCurrentSong();
    final state = {
      'currentSong': currentSong != null
          ? {
              'title': currentSong.title,
              'artist': currentSong.artist,
              'album': currentSong.album,
              'picture': currentSong.picture != null,
            }
          : null,
      'isPlaying': player.isPlaying,
      'currentPosition': player.currentPosition.inSeconds,
      'duration': player.duration.inSeconds,
      'queue': player.playingSongs
          .skip(player.currentSongIndex ?? 0)
          .take(5)
          .map((song) => {
                'title': song.title,
                'artist': song.artist,
              })
          .toList(),
    };

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(state));
    request.response.close();
  }

  void _serveAlbumArt(HttpRequest request) {
    final currentSong = player.getCurrentSong();
    if (currentSong?.picture != null) {
      request.response.headers.contentType = ContentType('image', 'jpeg');
      request.response.add(currentSong!.picture!);
    } else {
      request.response.statusCode = HttpStatus.notFound;
    }
    request.response.close();
  }
}
