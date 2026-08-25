import 'package:blossom/audio/nplayer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('playback source exposes openable sources', () {
    const library = PlaybackSource(PlaybackSourceType.library);
    const album = PlaybackSource(PlaybackSourceType.album, name: 'Album');
    const playlist =
        PlaybackSource(PlaybackSourceType.playlist, name: 'Playlist');

    expect(library.canOpen, isFalse);
    expect(album.canOpen, isTrue);
    expect(playlist.canOpen, isTrue);
  });
}
