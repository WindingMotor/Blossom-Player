import 'package:blossom/main.dart';
import 'package:flutter/material.dart';
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
  Future<void> _copyFilesToBlossomFolder(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'flac'],
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

  Widget _buildConfettiToggle(BuildContext context) {
    return _buildSwitchTile(
      'Confetti Effects',
      Settings.showConfetti,
      (value) async {
        await Settings.setShowConfetti(value);
        setState(() {});
      },
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
              _buildSection(
                  'Library',
                  [
                    _buildInfoTile('To add songs to your library',
                        'Put files into the Blossom folder in Files', context),
                    _buildInfoTile(
                      'Files can also be placed into folders for organizing.', 
                      'Blossom will search for files in the folders and add them to the library.',
                      context
                    ),
                    SizedBox(height: 8),
                    _buildButton(
                      'Copy Files to Blossom Folder',
                      () => _copyFilesToBlossomFolder(context),
                      context,
                    ),
                    SizedBox(height: 8),
                  ],
                  context),
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
              /*
              _buildSection(
                'Fun',
                [
                  _buildConfettiToggle(context),
                ],
                context
              ),
              */
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
