import 'package:audio_service/audio_service.dart';
import 'package:blossom/audio/nplayer.dart';

/// Handles Android Auto MediaBrowser content browsing.
/// Delegated from [CustomAudioHandler] to keep the handler file focused on
/// audio focus / playback logic.
class AndroidAutoBrowser {
  final NPlayer _nPlayer;

  AndroidAutoBrowser(this._nPlayer);

  static const String allSongsId = 'all_songs';
  static const String albumsId = 'albums';
  static const String queueId = 'queue';

  static const String _extraPage = 'android.media.browse.extra.PAGE';
  static const String _extraPageSize = 'android.media.browse.extra.PAGE_SIZE';
  static const int _defaultPageSize = 100;

  Future<List<MediaItem>> getChildren(
      String parentMediaId, Map<String, dynamic>? options) async {
    switch (parentMediaId) {
      case AudioService.browsableRootId:
        return [
          const MediaItem(
            id: allSongsId,
            title: 'All Songs',
            playable: false,
            extras: {'contentStyle': 1},
          ),
          const MediaItem(
            id: albumsId,
            title: 'Albums',
            playable: false,
            extras: {'contentStyle': 2},
          ),
          const MediaItem(
            id: queueId,
            title: 'Queue',
            playable: false,
            extras: {'contentStyle': 1},
          ),
        ];

      case allSongsId:
        return paginate(
          _nPlayer.sortedSongs.map(songToMediaItem).toList(),
          options,
        );

      case albumsId:
        return paginate(
          _nPlayer.albumMap.entries.map((e) {
            final first = e.value.first;
            return MediaItem(
              id: 'album:${e.key}',
              title: e.key,
              artist: first.artist,
              playable: false,
            );
          }).toList(),
          options,
        );

      case queueId:
        final queue = _nPlayer.playingSongs;
        if (queue.isEmpty) {
          return const [
            MediaItem(
              id: 'queue_empty',
              title: 'Queue is empty',
              artist: 'Start playing music to build a queue',
              playable: false,
            ),
          ];
        }
        return paginate(queue.map(songToMediaItem).toList(), options);

      default:
        if (parentMediaId.startsWith('album:')) {
          final albumName = parentMediaId.substring(6);
          final songs = _nPlayer.albumMap[albumName] ?? [];
          return paginate(songs.map(songToMediaItem).toList(), options);
        }
        return [];
    }
  }

  Future<MediaItem?> getMediaItem(String mediaId) async {
    try {
      return _nPlayer.allSongs
          .where((s) => s.path == mediaId)
          .map(songToMediaItem)
          .firstOrNull;
    } catch (_) {
      return null;
    }
  }

  /// Finds the song in the current queue first (to preserve queue position),
  /// then falls back to sorted songs list.
  Future<int?> resolvePlayIndex(String mediaId) async {
    // Check queue first so tapping a queue item skips to the right position
    final queueIdx =
        _nPlayer.playingSongs.indexWhere((s) => s.path == mediaId);
    if (queueIdx != -1) return null; // handled by playSpecificSong

    final sortedIdx =
        _nPlayer.sortedSongs.indexWhere((s) => s.path == mediaId);
    return sortedIdx == -1 ? null : sortedIdx;
  }

  MediaItem songToMediaItem(Music song) => MediaItem(
        id: song.path,
        title: song.title.isNotEmpty ? song.title : 'Unknown Title',
        artist: song.artist.isNotEmpty ? song.artist : 'Unknown Artist',
        album: song.album.isNotEmpty ? song.album : 'Unknown Album',
        duration: Duration(milliseconds: song.duration),
        playable: true,
      );

  List<MediaItem> paginate(
      List<MediaItem> items, Map<String, dynamic>? options) {
    final page = (options?[_extraPage] as int?) ?? 0;
    final size = (options?[_extraPageSize] as int?) ?? _defaultPageSize;
    final start = page * size;
    if (start >= items.length) return [];
    return items.sublist(start, (start + size).clamp(0, items.length));
  }
}
