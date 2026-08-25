

import 'dart:collection';
import 'dart:typed_data';

import 'package:blossom/audio/nplayer.dart';
import 'package:blossom/tools/utils.dart';
import 'package:flutter/material.dart';

class SongListTile extends StatelessWidget {
  final Music song;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onMorePressed;

  const SongListTile({
    Key? key,
    required this.song,
    required this.onTap,
    required this.onLongPress,
    this.onMorePressed,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDesktopPlatform = [TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS]
        .contains(Theme.of(context).platform);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: EdgeInsets.symmetric(
        horizontal: 8, 
        vertical: isDesktopPlatform ? 2 : 4
      ),
      child: ListTile(
      dense: isDesktopPlatform,
      visualDensity: isDesktopPlatform 
          ? VisualDensity.compact 
          : VisualDensity.standard,
        leading: AlbumArtThumbnail(picture: song.picture, songPath: song.path),

title: Text(
  song.title,
  style: textTheme.bodyMedium,
  overflow: TextOverflow.ellipsis,
),
subtitle: Text(
  '${song.artist} • ${song.genre}',
  style: textTheme.bodySmall?.copyWith(
    color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).round()),
  ),
  overflow: TextOverflow.ellipsis,
),
trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      Utils.formatMilliseconds(song.duration),
      style: textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).round()),
      ),
    ),
    if (onMorePressed != null)
      IconButton(
        icon: Icon(
          Icons.more_vert_rounded,
          size: 20,
          color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).round()),
        ),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        tooltip: 'Song options',
        onPressed: onMorePressed,
      ),
  ],
),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

// Shared album-art thumbnail used by song, album, and artist list tiles so
// they stay visually consistent. Falls back to a themed icon when there's
// no embedded picture or it fails to decode.
class AlbumArtThumbnail extends StatelessWidget {
  final Uint8List? picture;
  final String songPath; // you need to pass the song path!
  final double size;
  final IconData icon;

  const AlbumArtThumbnail({
    Key? key,
    required this.picture,
    required this.songPath,
    this.size = 48,
    this.icon = Icons.music_note,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: picture != null
            ? Image(
                image: AlbumArtCache.of(songPath, picture!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: theme.colorScheme.surface,
                  child: Icon(icon, color: theme.colorScheme.onSurface),
                ),
              )
            : Container(
                color: theme.colorScheme.surface,
                child: Icon(icon, color: theme.colorScheme.onSurface),
              ),
      ),
    );
  }
}

// LRU cache — keeps the most-recently-used 100 entries to avoid OOM on large libraries.
class AlbumArtCache {
  static const _maxSize = 100;
  static final _memCache = LinkedHashMap<String, MemoryImage>();

  static MemoryImage of(String path, Uint8List picture) {
    final existing = _memCache.remove(path);
    if (existing != null) {
      _memCache[path] = existing;
      return existing;
    }
    final image = MemoryImage(picture);
    _memCache[path] = image;
    if (_memCache.length > _maxSize) _memCache.remove(_memCache.keys.first);
    return image;
  }
}


