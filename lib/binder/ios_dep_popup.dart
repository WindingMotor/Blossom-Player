import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class iOSDepPopup {
  static void showDependencyDialog(BuildContext context) {
    final Map<String, String> dependencies = {
      'linux': 'sudo apt-get install ifuse usbmuxd libimobiledevice6',
      'macos': 'brew install ifuse usbmuxd',
      'windows': 'Currently not supported on Windows'
    };

    String platform = Platform.isLinux 
        ? 'linux' 
        : Platform.isMacOS 
            ? 'macos' 
            : 'windows';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Missing Dependencies',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The following dependencies are required for iOS device support:',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 16),
              Text(
                '• ifuse\n• usbmuxd',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Install command:',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: SelectableText(
                  dependencies[platform]!,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface,
              ),
              child: const Text('Close'),
            ),
            FilledButton.tonal(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: dependencies[platform]!));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Command copied to clipboard'),
                    backgroundColor: theme.colorScheme.secondary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Copy Command'),
            ),
            const SizedBox(width: 8),
          ],
        );
      },
    );
  }
}
