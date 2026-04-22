

import 'dart:typed_data';

import 'package:blossom/audio/nplayer.dart';
import 'package:blossom/tools/utils.dart';
import 'package:flutter/material.dart';

class SongListTile extends StatelessWidget {
  final Music song;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const SongListTile({
    Key? key,
    required this.song,
    required this.onTap,
    required this.onLongPress,
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
        leading: _AlbumArt(picture: song.picture, songPath: song.path),

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
trailing: Text(
  Utils.formatMilliseconds(song.duration),
  style: textTheme.bodySmall?.copyWith(
    color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).round()),
  ),
),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

class _AlbumArt extends StatelessWidget {
  final Uint8List? picture;
  final String songPath; // you need to pass the song path!

  const _AlbumArt({Key? key, required this.picture, required this.songPath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 48,
        height: 48,
        child: picture != null
            ? Image(
                image: _AlbumArtCache.of(songPath, picture!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: theme.colorScheme.surface,
                  child: Icon(Icons.music_note, color: theme.colorScheme.onSurface),
                ),
              )
            : Container(
                color: theme.colorScheme.surface,
                child: Icon(Icons.music_note, color: theme.colorScheme.onSurface),
              ),
      ),
    );
  }
}

// The cache (add once)
class _AlbumArtCache {
  static final Map<String, MemoryImage> _memCache = {};
  static MemoryImage of(String path, Uint8List picture) =>
      _memCache.putIfAbsent(path, () => MemoryImage(picture));
}


