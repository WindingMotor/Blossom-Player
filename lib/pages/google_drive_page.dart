import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../tools/google_auth_service.dart';

class GoogleDrivePage extends StatefulWidget {
  const GoogleDrivePage({Key? key}) : super(key: key);

  @override
  State<GoogleDrivePage> createState() => _GoogleDrivePageState();
}

class _GoogleDrivePageState extends State<GoogleDrivePage> {
  bool _isLoading = false;
  List<drive.File> _audioFiles = [];
  Set<String> _downloadingFiles = {};

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    
    if (GoogleAuthService.currentUser == null) {
      final success = await GoogleAuthService.signIn();
      if (!success) {
        setState(() => _isLoading = false);
        return;
      }
    }

    final files = await GoogleAuthService.listAudioFiles();
    setState(() {
      _audioFiles = files;
      _isLoading = false;
    });
  }

  Future<void> _downloadFile(drive.File file) async {
    if (_downloadingFiles.contains(file.id)) return;

    setState(() => _downloadingFiles.add(file.id!));
    
    try {
      final success = await GoogleAuthService.downloadFile(file);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded ${file.name}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download ${file.name}')),
        );
      }
    } finally {
      setState(() => _downloadingFiles.remove(file.id!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Drive'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFiles,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await GoogleAuthService.signOut();
              setState(() => _audioFiles.clear());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleAuthService.currentUser == null
              ? Center(
                  child: ElevatedButton(
                    onPressed: _loadFiles,
                    child: const Text('Sign in with Google'),
                  ),
                )
              : _audioFiles.isEmpty
                  ? const Center(child: Text('No audio files found'))
                  : ListView.builder(
                      itemCount: _audioFiles.length,
                      itemBuilder: (context, index) {
                        final file = _audioFiles[index];
                        final isDownloading = _downloadingFiles.contains(file.id);
                        
                        return ListTile(
                          title: Text(file.name ?? 'Unnamed file'),
                          subtitle: Text(_formatFileSize(int.parse(file.size ?? '0'))),
                          trailing: isDownloading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () => _downloadFile(file),
                                ),
                        );
                      },
                    ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
