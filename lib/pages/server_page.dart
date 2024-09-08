
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import '../audio/nserver.dart';
import 'package:network_info_plus/network_info_plus.dart';

class ServerPage extends StatefulWidget {
  const ServerPage({Key? key}) : super(key: key);

  @override
  _ServerPageState createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> {
  NServer? _server;
  String _status = 'Server not started';
  List<String> _availableServers = [];
  bool _isScanning = false;
  bool _isServerRunning = false;
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _toggleServer() async {
    final nplayer = Provider.of<NPlayer>(context, listen: false);
    
    if (_isServerRunning) {
      _server?.stop();
      setState(() {
        _isServerRunning = false;
        _status = 'Server stopped';
      });
    } else {
      _server = NServer(nplayer);
      await _server!.start();
      setState(() {
        _isServerRunning = true;
        _status = 'Server running on ${_server!.currentIp}:8080';
      });
    }
  }

  Future<void> _scanForServers() async {
    setState(() {
      _isScanning = true;
      _availableServers.clear();
    });

    final info = NetworkInfo();
    final wifiIP = await info.getWifiIP();
    final subnet = wifiIP!.substring(0, wifiIP.lastIndexOf('.'));

    for (int i = 1; i <= 254; i++) {
      final host = '$subnet.$i';
      if (await NServer.isValidServer(host)) {
        setState(() {
          _availableServers.add(host);
        });
      }
    }

    setState(() {
      _isScanning = false;
    });
  }

  void _connectToServer(String ip) {
    final nplayer = Provider.of<NPlayer>(context, listen: false);
    nplayer.playFromServer(ip);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connecting to server: $ip')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nplayer = Provider.of<NPlayer>(context);
    final currentSong = nplayer.getCurrentSong();

    return Scaffold(
      appBar: AppBar(title: const Text('Music Server')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(_status),
          ),
          ElevatedButton(
            onPressed: _toggleServer,
            child: Text(_isServerRunning ? 'Stop Server' : 'Start Server'),
          ),
          if (_isServerRunning && currentSong != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Currently streaming: ${currentSong.title} by ${currentSong.artist}'),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: 'Enter Server IP',
                suffixIcon: IconButton(
                  icon: Icon(Icons.play_arrow),
                  onPressed: () => _connectToServer(_ipController.text),
                ),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _isScanning ? null : _scanForServers,
            child: Text(_isScanning ? 'Scanning...' : 'Scan for Servers'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _availableServers.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_availableServers[index]),
                  onTap: () => _connectToServer(_availableServers[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _server?.stop();
    super.dispose();
  }
}