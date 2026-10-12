import 'package:audio_service/audio_service.dart';
import 'package:blossom/audio/nplayer.dart';

/// Maps only the requested page, avoiding full-library temporary allocations.
List<R> paginateItems<T, R>(
  List<T> items, {
  required int page,
  required int pageSize,
  required R Function(T) convert,
}) {
  if (page < 0 || pageSize <= 0) return <R>[];
  final start = page * pageSize;
  if (start >= items.length) return <R>[];
  final end = (start + pageSize).clamp(0, items.length);
  return [for (var index = start; index < end; index++) convert(items[index])];
}

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
        return paginateMapped(_nPlayer.sortedSongs, options, songToMediaItem);

      case albumsId:
        return paginateMapped(
          _nPlayer.albumMap.entries.toList(),
          options,
          (e) {
            final first = e.value.first;
            return MediaItem(
              id: 'album:${e.key}',
              title: e.key,
              artist: first.artist,
              playable: false,
            );
          },
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
        return paginateMapped(queue, options, songToMediaItem);

      default:
        if (parentMediaId.startsWith('album:')) {
          final albumName = parentMediaId.substring(6);
          final songs = _nPlayer.albumMap[albumName] ?? [];
          return paginateMapped(songs, options, songToMediaItem);
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
    final queueIdx = _nPlayer.playingSongs.indexWhere((s) => s.path == mediaId);
    if (queueIdx != -1) return null; // handled by playSpecificSong

    final sortedIdx = _nPlayer.sortedSongs.indexWhere((s) => s.path == mediaId);
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
    return paginateMapped(items, options, (item) => item);
  }

  List<MediaItem> paginateMapped<T>(List<T> items,
      Map<String, dynamic>? options, MediaItem Function(T) convert) {
    final page = (options?[_extraPage] as int?) ?? 0;
    final size = (options?[_extraPageSize] as int?) ?? _defaultPageSize;
    return paginateItems(
      items,
      page: page,
      pageSize: size,
      convert: convert,
    );
  }
}
