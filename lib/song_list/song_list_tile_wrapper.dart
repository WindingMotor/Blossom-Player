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
    Color backgroundColor = Colors.transparent;
    
    if (isCurrentSong) {
      backgroundColor = theme.colorScheme.primary.withOpacity(0.15);
    } else if (isSelected) {
      backgroundColor = theme.colorScheme.secondary.withOpacity(0.1);
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: SongListTile(
        song: song,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
