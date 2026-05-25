import 'dart:io';
import 'package:flutter/material.dart';
import 'package:blossom/audio/nplayer.dart';
import 'package:blossom/song_list/song_list_tile.dart';

class PlaylistArtwork extends StatelessWidget {
  final String? customImagePath;
  final List<Music> songs;
  final double size;

  const PlaylistArtwork({
    Key? key,
    this.customImagePath,
    required this.songs,
    this.size = 48,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If custom artwork exists, use it
    if (customImagePath != null) {
      return Image.file(File(customImagePath!), fit: BoxFit.cover);
    }

    // If no songs, show default icon
    if (songs.isEmpty) {
      return Container(
        color: Colors.grey[800],
        child: Icon(Icons.playlist_play, color: Colors.grey[600]),
      );
    }

    // If only one song with artwork, use it
    if (songs.length == 1 && songs.first.picture != null) {
      return Image(
        image: AlbumArtCache.of(songs.first.path, songs.first.picture!),
        fit: BoxFit.cover,
      );
    }

    // For multiple songs, create a grid of up to 4 album arts
    List<Music> artSongs = songs.where((s) => s.picture != null).take(4).toList();
    if (artSongs.isEmpty) {
      return Container(
        color: Colors.grey[800],
        child: Icon(Icons.playlist_play, color: Colors.grey[600]),
      );
    }

    return GridView.count(
      crossAxisCount: artSongs.length == 1 ? 1 : 2,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: artSongs.map((song) {
        return Image(
          image: AlbumArtCache.of(song.path, song.picture!),
          fit: BoxFit.cover,
        );
      }).toList(),
    );
  }
}
