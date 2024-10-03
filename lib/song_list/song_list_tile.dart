

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

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: _AlbumArt(picture: song.picture),
        title: Text(
          song.title,
          style: textTheme.bodyLarge,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${song.artist} • ${song.genre}',
          style: textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          Utils.formatMilliseconds(song.duration),
          style: textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
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

  const _AlbumArt({Key? key, required this.picture}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 48,
        height: 48,
        child: picture != null
            ? Image.memory(picture!, fit: BoxFit.cover)
            : Container(
                color: theme.colorScheme.surface,
                child:
                    Icon(Icons.music_note, color: theme.colorScheme.onSurface),
              ),
      ),
    );
  }
}
