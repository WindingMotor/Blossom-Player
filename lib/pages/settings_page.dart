import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blossom/tools/settings.dart';
import 'package:blossom/audio/nplayer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
          SnackBar(content: Text('Files copied to Blossom folder successfully')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(fontFamily: 'Magic Retro', fontSize: 24)),
        backgroundColor: Colors.black.withOpacity(0.8),
      ),
      body: Consumer<NPlayer>(
        builder: (context, player, child) {
          return ListView(
            children: [
              _buildSection(
                'Music Library',
                [
                  _buildInfoTile('Add songs to your library', 'Put files into the Blossom folder'),
                  _buildButton(
                    'Copy Files to Blossom Folder',
                    () => _copyFilesToBlossomFolder(context),
                  ),
                ],
              ),
              _buildSection(
                'Playback Settings',
                [
                  _buildDropdownTile(
                    'Repeat Mode',
                    player.repeatMode,
                    ['off', 'one', 'all'],
                    (String value) => player.setRepeatMode(value),
                  ),
                  _buildSliderTile(
                    'Default Volume',
                    player.volume,
                    (double value) => player.setVolume(value),
                  ),
                ],
              ),
              _buildSection(
                'Display Settings',
                [
                  _buildDropdownTile(
                    'Theme Mode',
                    Settings.themeMode,
                    ['system', 'light', 'dark'],
                    (String value) => Settings.setThemeMode(value),
                  ),
                ],
              ),
              _buildSection(
                'Sorting Preferences',
                [
_buildDropdownTile(
  'Album Sort By',
  Settings.albumSortBy,
  ['name', 'year', 'artist'],
  (String value) => Settings.setAlbumSort(value, Settings.albumSortAscending, Settings.albumOrganizeByFolder),
),
                  _buildSwitchTile(
                    'Artist Sort Order',
                    Settings.artistSortAscending,
                    (bool value) => Settings.setArtistSort(Settings.artistSortBy, value),
                  ),
                  _buildDropdownTile(
                    'Album Sort By',
                    Settings.albumSortBy,
                    ['name', 'year', 'artist'],
                    (String value) => Settings.setAlbumSort(value, Settings.albumSortAscending, Settings.albumOrganizeByFolder),
                  ),
                  _buildSwitchTile(
                    'Album Sort Order',
                    Settings.albumSortAscending,
                    (bool value) => Settings.setAlbumSort(Settings.albumSortBy, value, Settings.albumOrganizeByFolder),
                  ),
                  _buildSwitchTile(
                    'Organize Albums by Folder',
                    Settings.albumOrganizeByFolder,
                    (bool value) => Settings.setAlbumSort(Settings.albumSortBy, Settings.albumSortAscending, value),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.pinkAccent),
          ),
        ),
        ...children,
        Divider(color: Colors.grey.shade800),
      ],
    );
  }

  Widget _buildInfoTile(String title, String subtitle) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      leading: Icon(Icons.info_outline, color: Colors.pinkAccent),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(text),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

Widget _buildDropdownTile(String title, String currentValue, List<String> items, Function(String) onChanged) {
  // Ensure currentValue is in the items list
  if (!items.contains(currentValue)) {
    currentValue = items.first; // Default to the first item if current value is not in the list
  }
  
  return ListTile(
    title: Text(title),
    trailing: DropdownButton<String>(
      value: currentValue,
      onChanged: (String? newValue) {
        if (newValue != null) onChanged(newValue);
      },
      items: items.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value.capitalize()),
        );
      }).toList(),
      dropdownColor: Colors.grey.shade900,
    ),
  );
}

  Widget _buildSliderTile(String title, double value, Function(double) onChanged) {
    return ListTile(
      title: Text(title),
      subtitle: Slider(
        value: value,
        min: 0.0,
        max: 1.0,
        divisions: 20,
        label: (value * 100).round().toString(),
        onChanged: onChanged,
        activeColor: Colors.pinkAccent,
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.pinkAccent,
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}