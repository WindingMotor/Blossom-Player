import 'dart:async';

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
  String _status = 'Server not started';
  List<String> _availableServers = [];
  bool _isScanning = false;
  final TextEditingController _ipController = TextEditingController();
  StreamSubscription? _songChangeSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateServerStatus();
    });
  }

  void _updateServerStatus() {
    final nplayer = Provider.of<NPlayer>(context, listen: false);
    setState(() {
      _status = nplayer.isServerOn
          ? 'Server running on ${nplayer.server!.currentIp}:8080'
          : 'Server not started';
    });
  }

  Future<void> _toggleServer() async {
    final nplayer = Provider.of<NPlayer>(context, listen: false);
    try {
      await nplayer.toggleServer();
      _updateServerStatus();
      if (nplayer.isServerOn) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Server started on ${nplayer.server!.currentIp}:8080')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server stopped')),
        );
      }
    } catch (e) {
      print('Error toggling server: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle server: $e')),
      );
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
            child: Text(nplayer.isServerOn ? 'Stop Server' : 'Start Server'),
          ),
          if (nplayer.isPlayingFromServer)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                currentSong != null
                    ? 'Currently streaming: ${currentSong.title} by ${currentSong.artist}'
                    : 'No song currently playing',
              ),
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
    _songChangeSubscription?.cancel();
    super.dispose();
  }
}
