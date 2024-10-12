import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import '../audio/nserver.dart';
import 'package:network_info_plus/network_info_plus.dart';

class ServerSheet extends StatefulWidget {
  const ServerSheet({Key? key}) : super(key: key);

  @override
  _ServerSheetState createState() => _ServerSheetState();
}

class _ServerSheetState extends State<ServerSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final TextEditingController _ipController = TextEditingController();
  List<String> _availableServers = [];
  bool _isScanning = false;
  StreamSubscription? _songChangeSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
  }

  void _initializeAnimation() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  Future<void> _toggleServer() async {
    final nplayer = Provider.of<NPlayer>(context, listen: false);
    try {
      await nplayer.toggleServer();
      if (nplayer.isServerOn) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Server started on ${nplayer.server!.currentIp}:8080')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server stopped')),
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
    if (wifiIP == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to retrieve Wi-Fi IP')),
      );
      setState(() {
        _isScanning = false;
      });
      return;
    }

    final subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));

    // Limit the number of concurrent requests to prevent flooding
    final List<Future<void>> scanFutures = [];
    for (int i = 1; i <= 254; i++) {
      final host = '$subnet.$i';
      scanFutures.add(_checkServer(host));
    }

    await Future.wait(scanFutures);

    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _checkServer(String host) async {
    if (await NServer.isValidServer(host)) {
      setState(() {
        _availableServers.add(host);
      });
    }
  }

void _connectToServer(String ip) {
  final nplayer = Provider.of<NPlayer>(context, listen: false);
  nplayer.connectToServer(ip).then((_) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connected to server at $ip')),
    );
  }).catchError((error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to connect to server: $error')),
    );
  });
}

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, nplayer, _) {
        final server = nplayer.server;
        final isServerOn = nplayer.isServerOn;
        final currentIp = server?.currentIp;

        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, (1 - _animation.value) * 100),
              child: Opacity(
                opacity: _animation.value,
                child: child,
              ),
            );
          },
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor,
                  Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHandle(),
                const SizedBox(height: 10),
                _buildHeader(isServerOn, currentIp),
                const SizedBox(height: 20),
                _buildServerControls(isServerOn),
                const SizedBox(height: 20),
                _buildConnectionSection(),
                const SizedBox(height: 20),
                _buildAvailableServers(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[400],
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }

  Widget _buildHeader(bool isServerOn, String? currentIp) {
    return Text(
      isServerOn
          ? 'Server is running on $currentIp:8080'
          : 'Server is not running',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isServerOn ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildServerControls(bool isServerOn) {
    return ElevatedButton.icon(
      onPressed: _toggleServer,
      icon: Icon(isServerOn ? Icons.stop : Icons.play_arrow),
      label: Text(isServerOn ? 'Stop Server' : 'Start Server'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isServerOn ? Colors.red : Colors.green,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildConnectionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          TextField(
            controller: _ipController,
            decoration: InputDecoration(
              labelText: 'Enter Server IP',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.link),
                onPressed: () {
                  final ip = _ipController.text.trim();
                  if (ip.isNotEmpty) {
                    _connectToServer(ip);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid IP')),
                    );
                  }
                },
              ),
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _isScanning ? null : _scanForServers,
            icon: Icon(_isScanning ? Icons.refresh : Icons.search),
            label: Text(_isScanning ? 'Scanning...' : 'Scan for Servers'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableServers() {
    return Expanded(
      child: _availableServers.isEmpty
          ? Center(
              child: Text(
                _isScanning
                    ? 'Scanning for servers...'
                    : 'No servers found. Try scanning again.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          : ListView.builder(
              itemCount: _availableServers.length,
              itemBuilder: (context, index) {
                final ip = _availableServers[index];
                return ListTile(
                  leading: const Icon(Icons.link),
                  title: Text(ip),
                  trailing: IconButton(
                    icon: const Icon(Icons.connect_without_contact),
                    onPressed: () => _connectToServer(ip),
                  ),
                  onTap: () => _connectToServer(ip),
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _songChangeSubscription?.cancel();
    super.dispose();
  }
}