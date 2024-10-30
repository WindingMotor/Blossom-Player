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

class _ServerSheetState extends State<ServerSheet> with SingleTickerProviderStateMixin {
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

  Future<void> _toggleServer(NPlayer nplayer) async {
    try {
      if (nplayer.isServerOn) {
        await nplayer.stopServer();
      } else {
        await nplayer.startServer();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(nplayer.isServerOn ? 'Server started' : 'Server stopped'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Failed to toggle server: $e'),
          ),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Unable to retrieve Wi-Fi IP'),
          ),
        );
      }
      setState(() {
        _isScanning = false;
      });
      return;
    }

    final subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
    final List<Future<void>> scanFutures = [];
    for (int i = 1; i <= 254; i++) {
      scanFutures.add(_checkServer('$subnet.$i'));
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

  void _connectToServer(NPlayer nplayer, String ip) {
    nplayer.connectToServer(ip, 8080).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Connected to server at $ip'),
          ),
        );
      }
    }).catchError((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Failed to connect to server: $error'),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, nplayer, _) {
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
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                _buildHandle(),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      _buildAppBar(nplayer),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildServerStatus(nplayer),
                              const SizedBox(height: 24),
                              _buildManualConnection(),
                              const SizedBox(height: 24),
                              _buildScanSection(),
                            ],
                          ),
                        ),
                      ),
                      _buildServerList(nplayer),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 32,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildAppBar(NPlayer nplayer) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(context).cardColor,
      title: const Text(
        'Server Connection',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildServerStatus(NPlayer nplayer) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  nplayer.isServerOn ? Icons.cloud_done : Icons.cloud_off,
                  color: nplayer.isServerOn ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 12),
                Text(
                  'Server Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _toggleServer(nplayer),
              icon: Icon(nplayer.isServerOn ? Icons.stop : Icons.play_arrow),
              label: Text(nplayer.isServerOn ? 'Stop Server' : 'Start Server'),
              style: FilledButton.styleFrom(
                backgroundColor: nplayer.isServerOn ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualConnection() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link),
                const SizedBox(width: 12),
                Text(
                  'Manual Connection',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                hintText: 'Enter server IP address',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    final ip = _ipController.text.trim();
                    if (ip.isNotEmpty) {
                      final nplayer = Provider.of<NPlayer>(context, listen: false);
                      _connectToServer(nplayer, ip);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanSection() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wifi_find),
                const SizedBox(width: 12),
                Text(
                  'Network Scan',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isScanning ? null : _scanForServers,
              icon: _isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.search),
              label: Text(_isScanning ? 'Scanning Network...' : 'Scan for Servers'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerList(NPlayer nplayer) {
    if (_availableServers.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.devices_other,
                size: 48,
                color: Colors.grey.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _isScanning
                    ? 'Searching for servers...'
                    : 'No servers found\nTry scanning the network',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final ip = _availableServers[index];
          return ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.computer),
            ),
            title: Text(ip),
            subtitle: const Text('Available server'),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => _connectToServer(nplayer, ip),
            ),
          );
        },
        childCount: _availableServers.length,
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