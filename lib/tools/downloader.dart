import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'settings.dart';
import 'package:restart_app/restart_app.dart';

class Downloader extends StatefulWidget {
  const Downloader({super.key});

  @override
  _DownloaderState createState() => _DownloaderState();
}

class _DownloaderState extends State<Downloader> {
  String _output = '';
  bool _isLoading = false;
  bool _ffmpegInstalled = false;
  bool _spotdlInstalled = false;
  final TextEditingController _urlController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _setupEnvironment();
  }

  void _restartApp() {
    Restart.restartApp();
  }

  Future<void> _setupEnvironment() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _output = 'Setting up environment...\n';
    });

    try {
      await _checkFFmpegInstallation();
      await _setupSpotDL();
    } catch (e) {
      if (mounted) {
        setState(() => _output += 'Unexpected error: $e\n');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkFFmpegInstallation() async {
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      if (result.exitCode == 0) {
        setState(() {
          _ffmpegInstalled = true;
          _output += 'FFmpeg is installed and ready to use.\n';
        });
      } else {
        setState(() {
          _ffmpegInstalled = false;
          _output += 'FFmpeg is not installed.\n';
        });
      }
    } catch (e) {
      setState(() {
        _ffmpegInstalled = false;
        _output += 'Error checking FFmpeg installation: $e\n';
      });
    }
  }

  Future<void> _setupSpotDL() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final venvPath = '${documentsDir.path}/blossom_venv';

    // Check if python3 is installed
    final pythonCheckResult = await Process.run('python3', ['--version']);
    if (pythonCheckResult.exitCode != 0) {
      if (mounted) {
        setState(() =>
            _output += 'Error: Python3 is not installed or not in PATH.\n');
      }
      return;
    }

    // Create virtual environment
    final venvDir = Directory(venvPath);
    if (!await venvDir.exists()) {
      final venvResult = await Process.run('python3', ['-m', 'venv', venvPath]);
      if (venvResult.exitCode != 0) {
        if (mounted) {
          setState(() => _output +=
              'Error creating virtual environment: ${venvResult.stderr}\n');
        }
        return;
      }
      if (mounted) {
        setState(() => _output += 'Virtual environment created.\n');
      }
    } else {
      if (mounted) {
        setState(() => _output += 'Virtual environment already exists.\n');
      }
    }

    if (mounted) {
      setState(() => _output +=
          'Checking if spotdl is installed. If not wait for it to download.\n');
    }

    // Install spotdl
    final pipPath =
        Platform.isWindows ? '$venvPath\\Scripts\\pip' : '$venvPath/bin/pip';
    final spotdlInstallResult =
        await Process.run(pipPath, ['install', 'spotdl']);
    if (spotdlInstallResult.exitCode != 0) {
      if (mounted) {
        setState(() => _output +=
            'Error installing spotdl: ${spotdlInstallResult.stderr}\n');
      }
      return;
    }

    if (mounted) {
      setState(() {
        _output += 'spotdl installed successfully.\n';
        _spotdlInstalled = true;
      });
    }
  }

  void _showFFmpegInstructions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Install FFmpeg'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('Please install FFmpeg for your system:'),
                const SizedBox(height: 10),
                if (Platform.isWindows)
                  const Text(
                      'Windows: Visit the official FFmpeg website and follow the installation instructions.'),
                if (Platform.isMacOS)
                  const Text('macOS: Run "brew install ffmpeg" in Terminal.'),
                if (Platform.isLinux)
                  const Text(
                      'Linux: Run "sudo apt install ffmpeg" or use your distro\'s package manager.'),
                const SizedBox(height: 10),
                const Text('After installation, click "Confirm" below.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Open FFmpeg Website'),
              onPressed: () {
                launchUrl(Uri.parse('https://ffmpeg.org/download.html'));
              },
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop();
                _checkFFmpegInstallation();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadPlaylist() async {
    if (_urlController.text.isEmpty) {
      setState(() => _output += 'Please enter a valid URL.\n');
      return;
    }

    setState(() {
      _isLoading = true;
      _output += 'Downloading playlist...\n';
    });

    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final venvPath = '${documentsDir.path}/blossom_venv';
      final spotdlPath = Platform.isWindows
          ? '$venvPath\\Scripts\\spotdl'
          : '$venvPath/bin/spotdl';

      // Ensure the download directory exists
      final songDir = await Settings.getSongDir();
      final downloadDir = Directory(songDir);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final process = await Process.start(
        spotdlPath,
        [
          _urlController.text,
          '--output',
          songDir,
          '--format',
          'mp3',
          '--threads',
          '4',
          '--sponsor-block',
        ],
      );

      process.stdout.transform(utf8.decoder).listen((data) {
        setState(() {
          _output += data;
          _scrollToBottom();
        });
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        setState(() {
          _output += 'Error: $data';
          _scrollToBottom();
        });
      });

      final exitCode = await process.exitCode;

      if (exitCode == 0) {
        setState(() => _output +=
            'Playlist downloaded successfully to ${songDir}\n');
        _showDownloadCompleteDialog();
      } else {
        setState(() =>
            _output += 'Error downloading playlist. Exit code: $exitCode\n');
      }
    } catch (e) {
      setState(() => _output += 'Error downloading playlist: $e\n');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status',
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(8),
                            child: Text(_output),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_ffmpegInstalled && _spotdlInstalled)
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Download Spotify Playlist',
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _urlController,
                            decoration: InputDecoration(
                              hintText: 'Enter playlist URL',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  void _showDownloadCompleteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Download Complete'),
          content: const Text(
              'New songs will not be shown until the app is restarted.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget? _buildFAB() {
    if (_isLoading) return null;

    if (_ffmpegInstalled && _spotdlInstalled) {
      return FloatingActionButton(
        onPressed: _downloadPlaylist,
        tooltip: 'Download Playlist',
        child: const Icon(Icons.download),
      );
    }

    if (!_ffmpegInstalled) {
      return FloatingActionButton.extended(
        onPressed: _showFFmpegInstructions,
        icon: const Icon(Icons.download),
        label: const Text('Install FFmpeg'),
      );
    }

    return FloatingActionButton(
      onPressed: _setupEnvironment,
      tooltip: 'Retry Setup',
      child: const Icon(Icons.refresh),
    );
  }
}
