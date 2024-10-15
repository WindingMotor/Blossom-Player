import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:blossom/audio/nplayer.dart';
import 'package:path_provider/path_provider.dart';

class NServer {
  final NPlayer _player;
  ServerSocket? _server;
  bool _isRunning = false;

  NServer(this._player);

  Future<void> start({int port = 8080}) async {
    if (_isRunning) return;

    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _isRunning = true;
      print('Server listening on ${_server!.address.address}:${_server!.port}');

      _server!.listen((Socket client) {
        print('Client connected: ${client.remoteAddress.address}:${client.remotePort}');
        _handleClient(client);
      });
    } catch (e) {
      print('Error starting server: $e');
    }
  }

  void _handleClient(Socket client) async {
    try {
      Music? currentSong = _player.getCurrentSong();
      if (currentSong == null) {
        client.write('No song playing');
        await client.close();
        return;
      }

      File songFile = File(currentSong.path);
      if (!await songFile.exists()) {
        client.write('Song file not found');
        await client.close();
        return;
      }

      // Send song metadata
      client.write('${currentSong.title}\n');
      client.write('${currentSong.artist}\n');
      client.write('${currentSong.album}\n');
      client.write('${await songFile.length()}\n');

      // Send the file content
      await songFile.openRead().pipe(client);
    } catch (e) {
      print('Error handling client: $e');
    } finally {
      client.close();
    }
  }

    static Future<bool> isValidServer(String host, {int port = 8080}) async {
    try {
      final socket = await Socket.connect(host, port, timeout: Duration(seconds: 2));
      await socket.close();
      return true;
    } catch (e) {
      print('Error checking server: $e');
      return false;
    }
  }


   Future<void> stop () async {
    _server?.close();
    _isRunning = false;
    print('Server stopped');
  }

  bool get isRunning => _isRunning;
}
class NClient {
  final NPlayer _player;

  NClient(this._player);

  Future<void> connectAndPlay(String host, int port) async {
    try {
      final socket = await Socket.connect(host, port);
      print('Connected to server');

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_song.mp3');
      final sink = tempFile.openWrite();

      String title = await _readLine(socket);
      String artist = await _readLine(socket);
      String album = await _readLine(socket);
      int fileSize = int.parse(await _readLine(socket));

      int bytesReceived = 0;
      await for (Uint8List data in socket) {
        sink.add(data);
        bytesReceived += data.length;
        if (bytesReceived >= fileSize) break;
      }

      await sink.close();
      await socket.close();

      print('Song received and saved to ${tempFile.path}');

      // Create a Music object for the received song
      final receivedSong = Music(
        path: tempFile.path,
        folderName: 'Temp',
        lastModified: DateTime.now(),
        title: title,
        album: album,
        artist: artist,
        duration: 0, // You might want to get the actual duration
        year: '',
        genre: '',
        size: fileSize,
      );

      // Tell NPlayer to play the received song
      await _player.playSpecificSong(receivedSong);
    } catch (e) {
      print('Error connecting to server: $e');
    }
  }

  Future<String> _readLine(Socket socket) async {
    final completer = Completer<String>();
    List<int> lineBytes = [];

    socket.listen(
      (data) {
        for (var byte in data) {
          if (byte == 10) { // newline character
            completer.complete(String.fromCharCodes(lineBytes));
            return;
          }
          lineBytes.add(byte);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(String.fromCharCodes(lineBytes));
        }
      },
      onError: completer.completeError,
      cancelOnError: true,
    );

    return completer.future;
  }
}