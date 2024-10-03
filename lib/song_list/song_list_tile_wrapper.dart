
import 'package:blossom/audio/nplayer.dart';
import 'package:blossom/song_list/song_list_tile.dart';
import 'package:flutter/material.dart';

class SongListTileWrapper extends StatelessWidget {
  final Music song;
  final bool isCurrentSong;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const SongListTileWrapper({
    Key? key,
    required this.song,
    required this.isCurrentSong,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: isSelected
          ? theme.colorScheme.secondary.withOpacity(0.2)
          : Colors.transparent,
      child: SongListTile(
        song: song,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
