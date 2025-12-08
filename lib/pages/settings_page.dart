import 'package:blossom/main.dart';
import 'package:blossom/tools/supported_formats.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:blossom/tools/settings.dart';
import 'package:blossom/audio/nplayer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback onThemeChanged;

  const SettingsPage({Key? key, required this.onThemeChanged})
      : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _cacheStats;
  bool _isLoadingCache = false;

  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }

  Future<void> _loadCacheStats() async {
    setState(() => _isLoadingCache = true);
    try {
      final player = Provider.of<NPlayer>(context, listen: false);
      final stats = await player.getCacheStats();
      setState(() {
        _cacheStats = stats;
        _isLoadingCache = false;
      });
    } catch (e) {
      print('Error loading cache stats: $e');
      setState(() => _isLoadingCache = false);
    }
  }

Future<void> _clearCache(BuildContext context) async {
  // Show confirmation dialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Clear Cache?'),
      content: Text(
        'This will delete all cached song metadata. '
        'Songs will need to be re-scanned on next app launch.\n\n'
        'Your music files and playlists will not be affected.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Clear Cache'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    try {
      final player = Provider.of<NPlayer>(context, listen: false);
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Clear cache WITHOUT reloading
      await player.cache.clear();
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Reload cache stats to show empty cache
      await _loadCacheStats();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cache deleted successfully')),
      );
    } catch (e) {
      // Close loading dialog if still open
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing cache: $e')),
      );
    }
  }
}

  Future<void> _copyFilesToBlossomFolder(BuildContext context) async {
    try {
      // Get supported extensions dynamically
      final allowedExtensions = SupportedFormats.supportedAudioFormats
          .where((format) => 
              format['platform'] == 'ALL' || 
              (Platform.isAndroid && format['platform'] == 'ANDROID') ||
              (Platform.isIOS && format['platform'] == 'IOS'))
          .map((format) => format['extension']!.substring(1)) // Remove leading dot
          .toSet()
          .toList();

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: true,
      );

      if (result != null) {
        final directory = await getApplicationDocumentsDirectory();
        String blossomFolderPath = directory.path;

        for (var file in result.files) {
          File sourceFile = File(file.path!);
          String newPath = path.join(blossomFolderPath, file.name);
          await sourceFile.copy(newPath);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Files copied to Blossom folder successfully')),
        );
      } else {
        print('No files selected');
      }
    } catch (e) {
      print('Error copying files: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error copying files: ${e.toString()}')),
      );
    }
  }

  Future<void> _resetWelcomePage(BuildContext context) async {
    await Settings.setHasSeenWelcomePage(false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Welcome page will show on next app launch')),
    );
  }

  Future<void> _selectCustomDirectory(BuildContext context) async {
    try {
      // Use file_picker to select a directory
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      
      if (selectedDirectory != null) {
        // Save the selected directory
        await Settings.setCustomMusicDirectory(selectedDirectory);
        setState(() {}); // Refresh UI
        
        // Show confirmation to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Music folder set to: $selectedDirectory')),
        );
        
        // Ask if they want to scan for music now
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Scan for Music?'),
            content: Text('Would you like to scan for music in this folder now?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Later'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Get reference to NPlayer and reload songs
                  final player = Provider.of<NPlayer>(context, listen: false);
                  player.reloadSongs();
                },
                child: Text('Scan Now'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Error selecting directory: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting directory: $e')),
      );
    }
  }

  String _getSupportedFormatsDescription() {
    final formats = SupportedFormats.supportedAudioFormats
        .where((format) => 
            format['platform'] == 'ALL' || 
            (Platform.isAndroid && format['platform'] == 'ANDROID') ||
            (Platform.isIOS && format['platform'] == 'IOS'))
        .map((format) => format['extension']!.toUpperCase().substring(1))
        .toSet()
        .join(', ');
    return formats;
  }

  Widget _buildAndroidDirectorySection(BuildContext context) {
    // Only show for Android
    if (!Platform.isAndroid) return const SizedBox.shrink();
    
    final String? currentDir = Settings.customMusicDirectory;
    
    return _buildSection(
      'Music Folder',
      [
        _buildInfoTile(
          'Current Music Folder',
          currentDir?.isNotEmpty == true 
              ? currentDir!
              : Platform.isAndroid 
                ? '/storage/emulated/0/Music (default)'
                : Platform.isIOS
                  ? 'App Documents (default)'
                  : 'BlossomMedia folder (default)',
          context
        ),
        SizedBox(height: 8),
        _buildButton(
          'Select Music Folder',
          () => _selectCustomDirectory(context),
          context,
        ),
        if (currentDir?.isNotEmpty == true) 
          _buildButton(
            'Clear Custom Folder',
            () async {
              await Settings.clearCustomMusicDirectory();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Using default music folders now')),
              );
            },
            context,
          ),
        SizedBox(height: 8),
      ],
      context
    );
  }

  Widget _buildCacheSection(BuildContext context) {
    return _buildSection(
      'Cache',
      [
        _buildInfoTile(
          'About Cache',
          'Blossom caches song metadata to speed up library loading. '
          'Clear cache if you experience issues with song information.',
          context,
        ),
        if (_isLoadingCache)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_cacheStats != null) ...[
          _buildInfoTile(
            'Cached Songs',
            '${_cacheStats!['totalEntries']} songs',
            context,
          ),
          _buildInfoTile(
            'Pending Writes',
            '${_cacheStats!['pendingWrites']} entries',
            context,
          ),
          _buildInfoTile(
            'Cache Status',
            _cacheStats!['isInitialized'] ? 'Active' : 'Not initialized',
            context,
          ),
        ],
        SizedBox(height: 8),
        _buildButton(
          'Refresh Cache Stats',
          () => _loadCacheStats(),
          context,
        ),
        _buildButton(
          'Clear Cache & Rescan',
          () => _clearCache(context),
          context,
        ),
        SizedBox(height: 8),
      ],
      context,
    );
  }

Widget _buildPublicSharingSection(BuildContext context, NPlayer player) {
  return _buildSection(
    'Public Sharing',
    [
      _buildInfoTile(
        'About Public Sharing',
        'Share what you\'re listening to with friends. '
        'When enabled, your current song and online status will be visible to anyone with your User ID.',
        context,
      ),
      SizedBox(height: 8),
      
      // Enable/Disable Toggle
      _buildSwitchTile(
        'Enable Public Sharing',
        player.isSharingEnabled,
        (bool value) async {
          await player.togglePublicSharing(value);
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(value 
                ? 'Public sharing enabled - Friends can see what you\'re listening to'
                : 'Public sharing disabled'
              ),
            ),
          );
        },
        context,
      ),
      
      Divider(height: 32, indent: 16, endIndent: 16),
      
      // User ID (UUID) - Read-only with copy button
      ListTile(
        title: Text('Your User ID'),
        subtitle: Text(
          player.userUuid.isNotEmpty ? player.userUuid : 'Generating...',
          style: TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        leading: Icon(Icons.fingerprint, color: Theme.of(context).colorScheme.secondary),
        trailing: IconButton(
          icon: Icon(Icons.copy),
          tooltip: 'Copy User ID',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: player.userUuid));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('User ID copied to clipboard')),
            );
          },
        ),
      ),
      _buildInfoTile(
        'Share this ID',
        'Friends can use your User ID to see what you\'re currently listening to. '
        'Your ID is unique and cannot be changed.',
        context,
      ),
      
      SizedBox(height: 16),
      
      // Public Username
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: TextField(
          decoration: InputDecoration(
            labelText: 'Public Display Name',
            hintText: 'Music Lover',
            helperText: 'This name is shown to friends viewing your status',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: Icon(Icons.person),
          ),
          controller: TextEditingController(
            text: player.publicUsername ?? '',
          )..selection = TextSelection.collapsed(
            offset: (player.publicUsername ?? '').length,
          ),
          onSubmitted: (value) async {
            if (value.trim().isNotEmpty) {
              await player.setPublicUsername(value.trim());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Display name updated to "$value"')),
              );
            }
          },
        ),
      ),
      
      SizedBox(height: 8),
      
      // Current Status Preview
      if (player.isSharingEnabled) ...[
        Divider(height: 32, indent: 16, endIndent: 16),
        _buildInfoTile(
          'Current Public Status',
          player.isPlaying && player.getCurrentSong() != null
            ? 'Now sharing: "${player.getCurrentSong()!.title}" by ${player.getCurrentSong()!.artist}'
            : 'Online (not playing)',
          context,
        ),
      ],
      
      SizedBox(height: 8),
    ],
    context,
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Consumer<NPlayer>(
        builder: (context, player, child) {
          return ListView(
            children: [
              // Verison info 
              _buildSection(
                'Version',
                [
                  _buildInfoTile(
                    'Version',
                    '1.1.1+6',
                    context
                  ),
                ],
                context
              ),
              _buildSection(
                'Library',
                [
                  _buildInfoTile(
                    'Where to add music files',
                    'Blossom scans the Music folder on your device for audio files',
                    context
                  ),
                  _buildInfoTile(
                    'Supported locations',
                    Platform.isAndroid 
                      ? 'Music folder, Downloads folder, and internal app storage'
                      : Platform.isIOS
                        ? 'Files app > Blossom folder'
                        : 'BlossomMedia folder in your Documents directory',
                    context
                  ),
                  _buildInfoTile(
                    'Supported formats', 
                    '${_getSupportedFormatsDescription()} audio files',
                    context
                  ),
                  SizedBox(height: 8),
                  if (!Platform.isAndroid)
                    _buildButton(
                      'Copy Files to Blossom Folder',
                      () => _copyFilesToBlossomFolder(context),
                      context,
                    ),
                  SizedBox(height: 8),
                ],
                context
              ),
              
              // Add the Android directory selection section
              if (Platform.isAndroid)
                _buildAndroidDirectorySection(context),

              // Add the cache section
              _buildCacheSection(context),

              _buildSection(
                  'Playback',
                  [
                    _buildDropdownTile(
                      'Repeat Mode',
                      player.repeatMode,
                      ['off', 'one', 'all'],
                      (String value) {
                        player.setRepeatMode(value);
                        setState(() {});
                      },
                      context,
                    ),
                    _buildSliderTile(
                      'Internal App Volume',
                      player.volume,
                      (double value) {
                        player.setVolume(value);
                        setState(() {});
                      },
                      context,
                    ),
                    _buildSwitchTile(
                      'Previous Action Shuffles Songs',
                      Settings.previousForShuffle,
                      (bool value) async {
                        await Settings.setPreviousForShuffle(value);
                        setState(() {});
                      },
                      context,
                    ),
                  ],
                  context),

              _buildPublicSharingSection(context, player),
              _buildSection(
                'Appearance',
                [
                  _buildDropdownTile('App Theme', Settings.appTheme, [
                    'light',
                    'dark',
                    'oled',
                    '-',
                    'slate',
                    'ocean',
                    'forest',
                    'algae',
                    '-',
                    'sunset',
                    'rose',
                    'pink',
                    'lavender',
                    'orange',
                  ], (String value) async {
                    if (value != '-') {
                      await Settings.setAppTheme(value);
                      print('New theme set: $value');
                      widget.onThemeChanged();
                      setState(() {});
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => MyApp()),
                        (Route<dynamic> route) => false,
                      );
                    }
                  }, context),
                ],
                context
              ),
              _buildSection(
                'Developer Options',
                [
                  _buildButton(
                    'Reset Welcome Page',
                    () => _resetWelcomePage(context),
                    context,
                  ),
                  _buildInfoTile(
                    'Reset Welcome Page',
                    'Shows the welcome page again on next app launch',
                    context,
                  ),
                ],
                context,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(
      String title, List<Widget> children, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ),
        ...children,
        Divider(color: Colors.grey.shade800),
      ],
    );
  }

  Widget _buildInfoTile(String title, String subtitle, BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      leading: Icon(Icons.info_outline,
          color: Theme.of(context).colorScheme.secondary),
    );
  }

  Widget _buildButton(
      String text, VoidCallback onPressed, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(text),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          foregroundColor: Theme.of(context).colorScheme.onSecondary,
        ),
      ),
    );
  }

  Widget _buildDropdownTile(String title, String currentValue,
      List<String> items, Function(String) onChanged, BuildContext context) {
    if (!items.contains(currentValue)) {
      currentValue = items.first;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        title: Text(title),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
          ),
          child: DropdownButton<String>(
            value: currentValue,
            onChanged: (String? newValue) {
              if (newValue != null) onChanged(newValue);
            },
            items: items.map<DropdownMenuItem<String>>((String value) {
              if (value == '-') {
                return DropdownMenuItem<String>(
                  enabled: false,
                  value: value,
                  child: Divider(color: Theme.of(context).colorScheme.outline),
                );
              }
              return DropdownMenuItem<String>(
                value: value,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Text(value.capitalize()),
                ),
              );
            }).toList(),
            dropdownColor: Theme.of(context).colorScheme.surface,
            underline: Container(), // Remove the default underline
            icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderTile(String title, double value,
      Function(double) onChanged, BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Slider(
        value: value,
        min: 0.0,
        max: 1.0,
        divisions: 20,
        label: (value * 100).round().toString(),
        onChanged: onChanged,
        activeColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged,
      BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: SwitchListTile(
        title: Text(title),
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).colorScheme.secondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}