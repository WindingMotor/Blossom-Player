import 'package:blossom/audio/nplayer.dart';
import 'package:blossom/song_list/song_list_tile.dart';
import 'package:blossom/tools/app_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Per-song action sheet: queue actions plus quick navigation.
/// Opened from the "more" button on song tiles.
class SongActionsSheet extends StatelessWidget {
  final Music song;

  /// True when opened from the playing-queue list, enabling queue removal.
  final bool isInQueueContext;

  const SongActionsSheet({
    Key? key,
    required this.song,
    this.isInQueueContext = false,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context,
    Music song, {
    bool isInQueueContext = false,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SongActionsSheet(
        song: song,
        isInQueueContext: isInQueueContext,
      ),
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = context.read<NPlayer>();
    final navigation = context.read<AppNavigationController>();
    final isCurrent = player.getCurrentSong()?.path == song.path;
    final canRemoveFromQueue =
        isInQueueContext && !isCurrent && player.isInQueue(song);

    Widget action(IconData icon, String label, VoidCallback onTap,
        {String? subtitle}) {
      return ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(label),
        subtitle: subtitle != null
            ? Text(subtitle, style: theme.textTheme.bodySmall)
            : null,
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ListTile(
              leading:
                  AlbumArtThumbnail(picture: song.picture, songPath: song.path),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${song.artist} • ${song.album}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            if (!isCurrent)
              action(Icons.playlist_play_rounded, 'Play next', () {
                player.playNext(song);
                _snack(context, 'Playing next: ${song.title}');
              }),
            if (!isCurrent)
              action(Icons.queue_music_rounded, 'Add to queue', () {
                player.addToQueue(song);
                _snack(context, 'Added to queue: ${song.title}');
              }),
            if (canRemoveFromQueue)
              action(Icons.remove_circle_outline_rounded, 'Remove from queue',
                  () {
                player.removeFromQueue(song);
                _snack(context, 'Removed from queue: ${song.title}');
              }),
            action(Icons.album_rounded, 'Go to album', () {
              navigation.openAlbum(song);
            }, subtitle: song.album),
            action(Icons.person_rounded, 'Go to artist', () {
              navigation.openArtist(song.artist);
            }, subtitle: song.artist),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
