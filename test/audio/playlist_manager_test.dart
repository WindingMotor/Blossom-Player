import 'dart:convert';
import 'dart:io';

import 'package:blossom/audio/nplaylist.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('concurrent bulk playlist updates persist every song', () async {
    final tempDir = await Directory.systemTemp.createTemp('blossom-playlists-');
    addTearDown(() => tempDir.delete(recursive: true));
    const pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
    });

    await PlaylistManager.initialize();
    await PlaylistManager.createPlaylist('Road trip');
    await Future.wait([
      PlaylistManager.updateSongsInPlaylist(
        'Road trip',
        ['/music/a.mp3', '/music/b.mp3'],
        add: true,
      ),
      PlaylistManager.updateSongsInPlaylist(
        'Road trip',
        ['/music/c.mp3', '/music/d.mp3'],
        add: true,
      ),
    ]);

    expect(
      PlaylistManager.getPlaylistSongs('Road trip').toSet(),
      {'/music/a.mp3', '/music/b.mp3', '/music/c.mp3', '/music/d.mp3'},
    );

    final file = File(path.join(
      PlaylistManager.playlistDirectory,
      'playlists.json',
    ));
    final persisted =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(
      (persisted['Road trip']['songs'] as List<dynamic>).toSet(),
      {'/music/a.mp3', '/music/b.mp3', '/music/c.mp3', '/music/d.mp3'},
    );
  });
}
