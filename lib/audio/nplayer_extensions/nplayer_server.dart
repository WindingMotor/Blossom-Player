part of '../nplayer.dart';

extension NPlayerServer on NPlayer {
  // MARK: Server-related methods

  Future<void> startServer({int port = 8080}) async {
    Log.d(LogTag.server, 'Starting server on port $port');
    final server = NServer(this);
    await server.start(port: port);
    _server = server;
    _isServerOn = true;
    _internalNotifyListeners();
  }

  Future<void> stopServer() async {
    Log.d(LogTag.server, 'Stopping server');
    if (_server != null) {
      await _server!.stop();
      _server = null;
      _isServerOn = false;
      _internalNotifyListeners();
    }
  }

  Future<void> connectToServer(String host, int port) async {
    if (_client == null) {
      _client = NClient(this);
    }
    await _client!.connectAndPlay(host, port);
  }
}
