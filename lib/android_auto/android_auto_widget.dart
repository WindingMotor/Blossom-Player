import 'dart:typed_data';
import 'dart:ui';
import 'package:blossom/audio/nplayer.dart';
import 'package:blossom/tools/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Android Auto–style sidebar "now playing" panel.
///
/// Designed for large-touch, glanceable use in-car:
///  - Blurred album art background
///  - Large song title / artist
///  - Oversized prev / play-pause / next controls
///  - Slim seek bar at the bottom
class AndroidAutoWidget extends StatelessWidget {
  const AndroidAutoWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, player, _) {
        final song = player.getCurrentSong();
        if (song == null) return const _EmptyState();
        return _AutoPanel(player: player, song: song);
      },
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0F0F),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_off_rounded, size: 56, color: Color(0xFF555555)),
            SizedBox(height: 12),
            Text(
              'Nothing playing',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Main panel ──────────────────────────────────────────────────────────────

class _AutoPanel extends StatelessWidget {
  const _AutoPanel({required this.player, required this.song});

  final NPlayer player;
  final Music song;

  static const _bg = Color(0xFF0F0F0F);
  static const _accent = Color(0xFF4FC3F7);
  static const _textPrimary = Color(0xFFEEEEEE);
  static const _textSecondary = Color(0xFF888888);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (song.picture != null) _BlurredArt(picture: song.picture!),

          // Dark scrim so text is always legible
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC0F0F0F),
                  Color(0xDD0F0F0F),
                  Color(0xF50F0F0F),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const _AutoHeader(),
                  const SizedBox(height: 16),
                  _AlbumArt(picture: song.picture),
                  const SizedBox(height: 20),
                  _SongInfo(song: song),
                  const Spacer(),
                  _Controls(player: player, song: song),
                  const SizedBox(height: 16),
                  _SeekBar(player: player),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Blurred art background ───────────────────────────────────────────────────

class _BlurredArt extends StatelessWidget {
  const _BlurredArt({required this.picture});
  final Uint8List picture;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: Image.memory(picture, fit: BoxFit.cover),
    );
  }
}

// ─── Header label ─────────────────────────────────────────────────────────────

class _AutoHeader extends StatelessWidget {
  const _AutoHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.directions_car_rounded,
            size: 16, color: Color(0xFF4FC3F7)),
        SizedBox(width: 6),
        Text(
          'Android Auto',
          style: TextStyle(
            color: Color(0xFF4FC3F7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// ─── Album art ────────────────────────────────────────────────────────────────

class _AlbumArt extends StatelessWidget {
  const _AlbumArt({required this.picture});
  final Uint8List? picture;

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
        image: picture != null
            ? DecorationImage(fit: BoxFit.cover, image: MemoryImage(picture!))
            : null,
      ),
      child: picture == null
          ? const Icon(Icons.album_rounded,
              size: 64, color: Color(0xFF444444))
          : null,
    );
  }
}

// ─── Song info ────────────────────────────────────────────────────────────────

class _SongInfo extends StatelessWidget {
  const _SongInfo({required this.song});
  final Music song;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          song.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _AutoPanel._textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          song.artist,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _AutoPanel._textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ─── Controls ─────────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  const _Controls({required this.player, required this.song});
  final NPlayer player;
  final Music song;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _AutoIconButton(
          icon: Icons.skip_previous_rounded,
          size: 36,
          onTap: player.previousSong,
        ),
        const SizedBox(width: 20),
        _PlayPauseButton(player: player),
        const SizedBox(width: 20),
        _AutoIconButton(
          icon: Icons.skip_next_rounded,
          size: 36,
          onTap: player.nextSong,
        ),
        const SizedBox(width: 28),
        _FavoriteButton(player: player, song: song),
      ],
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.player});
  final NPlayer player;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: player.togglePlayPause,
      child: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _AutoPanel._accent,
          boxShadow: [
            BoxShadow(
              color: Color(0x554FC3F7),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.black,
          size: 40,
        ),
      ),
    );
  }
}

class _AutoIconButton extends StatelessWidget {
  const _AutoIconButton({
    required this.icon,
    required this.onTap,
    this.size = 30,
  });
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: _AutoPanel._textPrimary, size: size),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.player, required this.song});
  final NPlayer player;
  final Music song;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => player.toggleFavorite(),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: song.isFavorite ? Colors.redAccent : _AutoPanel._textSecondary,
          size: 28,
        ),
      ),
    );
  }
}

// ─── Seek bar ─────────────────────────────────────────────────────────────────

class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.player});
  final NPlayer player;

  @override
  Widget build(BuildContext context) {
    final totalMs = player.duration.inMilliseconds.toDouble();
    final posMs =
        player.currentPosition.inMilliseconds.toDouble().clamp(0.0, totalMs > 0 ? totalMs : 1.0);

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: _AutoPanel._accent,
            inactiveTrackColor: const Color(0xFF333333),
            thumbColor: _AutoPanel._accent,
            overlayColor: const Color(0x334FC3F7),
          ),
          child: Slider(
            value: posMs,
            min: 0,
            max: totalMs > 0 ? totalMs : 1.0,
            onChanged: totalMs > 0
                ? (v) => player.seek(Duration(milliseconds: v.round()))
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Utils.formatDuration(player.currentPosition.inSeconds),
                style: const TextStyle(
                  color: _AutoPanel._textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                Utils.formatDuration(player.duration.inSeconds),
                style: const TextStyle(
                  color: _AutoPanel._textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
