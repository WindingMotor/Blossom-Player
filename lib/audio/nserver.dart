import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blossom/audio/nplayer.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path/path.dart' as path;

class NServer {
  HttpServer? _server;
  final NPlayer _nplayer;
  StreamSubscription? _songChangeSubscription;
  String? _currentIp;
  bool _isRunning = false;
  List<WebSocketChannel> _clients = [];

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
        print('Song changed, updating clients');
        notifyClients('songChange', _nplayer.getCurrentSong()?.toJson());
      });

      _server!.listen((HttpRequest request) {
        if (request.uri.path == '/ws') {
          _handleWebSocketConnection(request);
        } else {
          _handleHttpRequest(request);
        }
      }, onError: (e) {
        print('Error handling request: $e');
      });
    } catch (e) {
      print('Failed to start server: $e');
      _isRunning = false;
    }
  }

  void _handleWebSocketConnection(HttpRequest request) {
    print('Handling WebSocket connection request');
    WebSocketTransformer.upgrade(request).then((WebSocket webSocket) {
      print('WebSocket connection established');
      final channel = IOWebSocketChannel(webSocket);
      _clients.add(channel);
      _handleWebSocket(channel);
    }).catchError((error) {
      print('Error upgrading to WebSocket: $error');
    });
  }

  void _handleWebSocket(WebSocketChannel channel) {
    channel.stream.listen(
      (message) {
        final data = json.decode(message);
        switch (data['type']) {
          case 'getCurrentSong':
            final currentSong = _nplayer.getCurrentSong();
            if (currentSong != null) {
              channel.sink.add(json.encode({
                'type': 'songChange',
                'song': currentSong.toJson(),
              }));
            } else {
              channel.sink.add(json.encode({
                'type': 'songChange',
                'song': null,
              }));
            }
            break;
          case 'seek':
            _nplayer.seek(Duration(milliseconds: data['position']));
            notifyClients('seek', {'position': data['position']});
            break;
          case 'skip':
            if (data['direction'] == 'next') {
              _nplayer.nextSong();
            } else {
              _nplayer.previousSong();
            }
            notifyClients('skip', {'direction': data['direction']});
            break;
        }
      },
      onDone: () {
        _clients.remove(channel);
      },
    );
  }

  void _handleHttpRequest(HttpRequest request) {
    print('Received HTTP request for: ${request.uri.path}');

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
    <title>Blossom Music Player</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/howler/2.2.3/howler.min.js"></script>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            background-color: #f0f0f0;
        }
        #albumArt {
            width: 300px;
            height: 300px;
            object-fit: cover;
            margin-bottom: 20px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
        }
        #songInfo {
            text-align: center;
            margin-bottom: 20px;
        }
        #controls {
            display: flex;
            gap: 10px;
        }
        button {
            padding: 10px 20px;
            font-size: 16px;
        }
    </style>
</head>
<body>
    <h1>Blossom Music Player</h1>
    <img id="albumArt" src="/metadata" alt="Album Art">
    <div id="songInfo">
        <h2 id="title">Loading...</h2>
        <p id="artist"></p>
        <p id="album"></p>
    </div>
    <div id="controls">
        <button id="playPauseBtn">Play</button>
        <button id="stopBtn">Stop</button>
    </div>

    <script>
        let sound;
        let isPlaying = false;

        function initializeAudio() {
            console.log('Initializing audio stream');
            if (sound) {
                sound.unload();
            }
            sound = new Howl({
                src: ['/stream'],
                format: ['mp3'],
                html5: true,
                onplay: () => {
                    console.log('Audio started playing');
                    isPlaying = true;
                    updatePlayPauseButton();
                },
                onpause: () => {
                    console.log('Audio paused');
                    isPlaying = false;
                    updatePlayPauseButton();
                },
                onstop: () => {
                    console.log('Audio stopped');
                    isPlaying = false;
                    updatePlayPauseButton();
                },
                onloaderror: (id, error) => {
                    console.error('Error loading audio:', error);
                },
                onplayerror: (id, error) => {
                    console.error('Error playing audio:', error);
                },
                onend: () => {
                    console.log('Audio ended, restarting stream');
                    sound.play();
                }
            });
        }

        function updatePlayPauseButton() {
            const playPauseBtn = document.getElementById('playPauseBtn');
            playPauseBtn.textContent = isPlaying ? 'Pause' : 'Play';
        }

        function updateMetadata() {
            console.log('Updating metadata');
            fetch('/metadata')
                .then(response => response.json())
                .then(data => {
                    console.log('Received metadata:', data);
                    document.getElementById('title').textContent = data.title || 'Unknown Title';
                    document.getElementById('artist').textContent = data.artist || 'Unknown Artist';
                    document.getElementById('album').textContent = data.album || 'Unknown Album';
                    if (data.picture) {
                        document.getElementById('albumArt').src = 'data:image/jpeg;base64,' + data.picture;
                    } else {
                        document.getElementById('albumArt').src = 'https://via.placeholder.com/300?text=No+Album+Art';
                    }
                })
                .catch(error => console.error('Error fetching metadata:', error));
        }

        document.getElementById('playPauseBtn').addEventListener('click', () => {
            if (!sound) {
                initializeAudio();
            }
            if (isPlaying) {
                sound.pause();
            } else {
                sound.play();
            }
        });

        document.getElementById('stopBtn').addEventListener('click', () => {
            if (sound) {
                sound.stop();
            }
        });

        // Initialize audio and start metadata updates
        initializeAudio();
        updateMetadata();
        setInterval(updateMetadata, 5000);
    </script>
</body>
</html>
''')
    ..close();
}

// Parses the Range header and returns a list of byte ranges
List<_HttpRange>? _parseRange(String rangeHeader, int fileLength) {
  final regex = RegExp(r"bytes=(\d*)-(\d*)");
  final match = regex.firstMatch(rangeHeader);
  if (match != null) {
    final startStr = match.group(1);
    final endStr = match.group(2);
    int? start = startStr != null && startStr.isNotEmpty ? int.parse(startStr) : null;
    int? end = endStr != null && endStr.isNotEmpty ? int.parse(endStr) : null;

    if (start == null && end != null) {
      start = fileLength - end;
      end = fileLength - 1;
    } else if (start != null && end == null) {
      end = fileLength - 1;
    }

    if (start != null && end != null && start <= end && end < fileLength) {
      return [_HttpRange(start, end)];
    }
  }
  return null;
}

// Determines the Content-Type based on file extension
ContentType _getContentType(String filePath) {
  final extension = path.extension(filePath).toLowerCase();
  switch (extension) {
    case '.mp3':
      return ContentType('audio', 'mpeg');
    case '.flac':
      return ContentType('audio', 'x-flac');
    case '.wav':
      return ContentType('audio', 'wav');
    // Add more cases as needed for other audio formats
    default:
      return ContentType('application', 'octet-stream');
  }
}

Future<void> _handleStreamRequest(HttpRequest request) async {
  print('Received stream request');
  final currentSong = _nplayer.getCurrentSong();

  if (currentSong != null && await File(currentSong.path).exists()) {
    print('Serving stream for: ${currentSong.title}');

    final file = File(currentSong.path);
    final fileLength = await file.length();
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);

    if (rangeHeader != null) {
      final ranges = _parseRange(rangeHeader, fileLength);
      if (ranges != null && ranges.isNotEmpty) {
        final range = ranges.first;
        final start = range.start;
        final end = range.end;
        final contentLength = end - start + 1;

        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set(HttpHeaders.contentTypeHeader, _getContentType(currentSong.path));
        request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$fileLength');
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        request.response.headers.set(HttpHeaders.contentLengthHeader, contentLength);

        try {
          await for (var chunk in file.openRead(start, end + 1)) {
            request.response.add(chunk);
            await request.response.flush();
          }
          await request.response.close();
          print('Partial stream sent successfully');
          return;
        } catch (e) {
          print('Error streaming partial content: $e');
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write('Error streaming partial content')
            ..close();
          return;
        }
      }
    }

    // Serve the entire file if no Range header is present
    request.response.headers.contentType = _getContentType(currentSong.path);
    request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

    try {
      await for (var chunk in file.openRead()) {
        request.response.add(chunk);
        await request.response.flush();
      }
      await request.response.close();
      print('Full stream sent successfully');
    } catch (e) {
      print('Error streaming file: $e');
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write('Error streaming file')
        ..close();
    }
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

void notifyClients(String type, dynamic data) {
  final update = json.encode({'type': type, 'data': data});
  print('Notifying clients: $update');
  for (var client in _clients) {
    client.sink.add(update);
  }
}

  void notifySongChange() {
    final currentSong = _nplayer.getCurrentSong();
    if (currentSong != null) {
      notifyClients('songChange', {'song': currentSong.toJson()});
    } else {
      print('No current song to notify clients about');
      notifyClients('songChange', {'song': null});
    }
  }

  Future<void> stop() async {
    if (!_isRunning) {
      print('Server is not running.');
      return;
    }

    try {
      await _songChangeSubscription?.cancel();
      for (var client in _clients) {
        await client.sink.close();
      }
      _clients.clear();
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
  String? get currentIp => _currentIp;

  static Future<bool> isValidServer(String ip) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ip:8080'))
          .timeout(Duration(seconds: 5));
      return response.statusCode == 200 &&
          response.body.contains('Blossom Music Server');
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

// Represents a byte range
class _HttpRange {
  final int start;
  final int end;

  _HttpRange(this.start, this.end);
}
