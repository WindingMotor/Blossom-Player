import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:blossom/audio/nplayer.dart';
import 'package:blossom/tools/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const String _protocolGet = 'BLOSSOM/1 GET';
const String _protocolPing = 'BLOSSOM/1 PING';
const int _maxHeaderBytes = 64 * 1024;

class NServer {
  final NPlayer _player;
  final Set<Socket> _clients = <Socket>{};
  ServerSocket? _server;
  bool _isRunning = false;

  NServer(this._player);

  Future<void> start({int port = 8080}) async {
    if (_isRunning) return;
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _isRunning = true;
    Log.i(LogTag.server,
        'Server listening on ${_server!.address.address}:${_server!.port}');
    _server!.listen(
      _handleClient,
      onError: (Object error, StackTrace stack) =>
          Log.e(LogTag.server, 'Server socket error: $error', stack),
    );
  }

  Future<void> _handleClient(Socket client) async {
    if (_clients.length >= 4) {
      client.destroy();
      return;
    }
    _clients.add(client);
    try {
      final reader = _SocketReader(client.timeout(const Duration(seconds: 10)));
      final command = await reader.readLine(maxBytes: 64);
      if (command == _protocolPing) {
        client.write('BLOSSOM/1 PONG\n');
        await client.flush();
        return;
      }
      if (command != _protocolGet) {
        throw const FormatException('Unsupported Blossom server request');
      }

      final currentSong = _player.getCurrentSong();
      if (currentSong == null) {
        await _writeHeader(client, {'error': 'No song playing'});
        return;
      }
      final songFile = File(currentSong.path);
      if (!await songFile.exists()) {
        await _writeHeader(client, {'error': 'Song file not found'});
        return;
      }

      await _writeHeader(client, {
        'title': currentSong.title,
        'artist': currentSong.artist,
        'album': currentSong.album,
        'size': await songFile.length(),
        'extension': p.extension(songFile.path),
      });
      await client.addStream(songFile.openRead());
      await client.flush();
    } catch (e, stack) {
      Log.e(LogTag.server, 'Error handling client: $e', stack);
    } finally {
      _clients.remove(client);
      await client.close().catchError((_) {});
    }
  }

  Future<void> _writeHeader(Socket client, Map<String, Object> value) async {
    final payload = utf8.encode(jsonEncode(value));
    final prefix = ByteData(4)..setUint32(0, payload.length, Endian.big);
    client.add(prefix.buffer.asUint8List());
    client.add(payload);
    await client.flush();
  }

  static Future<bool> isValidServer(String host, {int port = 8080}) async {
    Socket? socket;
    try {
      socket =
          await Socket.connect(host, port, timeout: const Duration(seconds: 2));
      socket.write('$_protocolPing\n');
      await socket.flush();
      final reader = _SocketReader(socket.timeout(const Duration(seconds: 2)));
      return await reader.readLine(maxBytes: 64) == 'BLOSSOM/1 PONG';
    } catch (_) {
      return false;
    } finally {
      socket?.destroy();
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _isRunning = false;
    for (final client in _clients.toList()) {
      client.destroy();
    }
    _clients.clear();
    await server?.close();
    Log.i(LogTag.server, 'Server stopped');
  }

  bool get isRunning => _isRunning;
}

class NClient {
  final NPlayer _player;

  NClient(this._player);

  Future<void> connectAndPlay(String host, int port) async {
    Socket? socket;
    File? partialFile;
    try {
      socket =
          await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      socket.write('$_protocolGet\n');
      await socket.flush();

      final reader = _SocketReader(socket.timeout(const Duration(seconds: 30)));
      final headerLength = ByteData.sublistView(await reader.readExact(4))
          .getUint32(0, Endian.big);
      if (headerLength <= 0 || headerLength > _maxHeaderBytes) {
        throw const FormatException('Invalid Blossom server header');
      }
      final decoded =
          jsonDecode(utf8.decode(await reader.readExact(headerLength)));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid Blossom server metadata');
      }
      if (decoded['error'] case final String message) throw Exception(message);
      final fileSize = decoded['size'];
      if (fileSize is! int || fileSize <= 0) {
        throw const FormatException('Invalid song size');
      }

      final tempDir = await getTemporaryDirectory();
      final extension = _safeExtension(decoded['extension'] as String?);
      partialFile = File(p.join(tempDir.path,
          'blossom-${DateTime.now().microsecondsSinceEpoch}$extension.part'));
      final sink = partialFile.openWrite();
      try {
        await reader.pipeExact(sink, fileSize);
      } finally {
        await sink.close();
      }
      if (await partialFile.length() != fileSize) {
        throw const FileSystemException('Received an incomplete song');
      }
      final finalFile =
          File(partialFile.path.substring(0, partialFile.path.length - 5));
      await partialFile.rename(finalFile.path);
      partialFile = null;

      await _player.playSpecificSong(Music(
        path: finalFile.path,
        folderName: 'Temp',
        lastModified: DateTime.now(),
        title: decoded['title'] as String? ?? 'Unknown Title',
        album: decoded['album'] as String? ?? 'Unknown Album',
        artist: decoded['artist'] as String? ?? 'Unknown Artist',
        duration: 0,
        year: '',
        genre: '',
        size: fileSize,
      ));
    } catch (e, stack) {
      Log.e(LogTag.server, 'Error connecting to server: $e', stack);
      rethrow;
    } finally {
      socket?.destroy();
      if (partialFile != null && await partialFile.exists()) {
        try {
          await partialFile.delete();
        } catch (_) {}
      }
    }
  }

  String _safeExtension(String? value) {
    if (value == null || !RegExp(r'^\.[A-Za-z0-9]{1,8}$').hasMatch(value)) {
      return '.mp3';
    }
    return value.toLowerCase();
  }
}

class _SocketReader {
  final StreamIterator<Uint8List> _iterator;
  Uint8List _buffer = Uint8List(0);
  int _offset = 0;

  _SocketReader(Stream<Uint8List> stream) : _iterator = StreamIterator(stream);

  Future<bool> _fill() async {
    if (_offset < _buffer.length) return true;
    if (!await _iterator.moveNext()) return false;
    _buffer = _iterator.current;
    _offset = 0;
    return true;
  }

  Future<Uint8List> readExact(int count) async {
    final result = Uint8List(count);
    var written = 0;
    while (written < count) {
      if (!await _fill()) {
        throw const FormatException('Unexpected end of stream');
      }
      final take = (count - written).clamp(0, _buffer.length - _offset);
      result.setRange(written, written + take, _buffer, _offset);
      written += take;
      _offset += take;
    }
    return result;
  }

  Future<String> readLine({required int maxBytes}) async {
    final bytes = <int>[];
    while (bytes.length < maxBytes) {
      if (!await _fill()) {
        throw const FormatException('Unexpected end of stream');
      }
      final byte = _buffer[_offset++];
      if (byte == 10) return utf8.decode(bytes).trimRight();
      bytes.add(byte);
    }
    throw const FormatException('Protocol line too long');
  }

  Future<void> pipeExact(IOSink sink, int count) async {
    var remaining = count;
    while (remaining > 0) {
      if (!await _fill()) throw const FormatException('Unexpected end of song');
      final take = remaining.clamp(0, _buffer.length - _offset);
      sink.add(Uint8List.sublistView(_buffer, _offset, _offset + take));
      _offset += take;
      remaining -= take;
    }
  }
}
