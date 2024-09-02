
import 'package:blossom/tools/settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import '../sheets/bottom_sheet.dart';

class ArtistsPage extends StatefulWidget {
  const ArtistsPage({super.key});

  @override
  _ArtistsPageState createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<ArtistsPage> {
  late String _sortBy;
  late bool _sortAscending;
  String _searchQuery = '';
  List<ArtistInfo> _artistList = [];

  @override
  void initState() {
    super.initState();
    _loadSortPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeArtistList();
    });
  }

  void _loadSortPreferences() {
    setState(() {
      _sortBy = Settings.artistSortBy;
      _sortAscending = Settings.artistSortAscending;
    });
  }
  
  void _initializeArtistList() {
    final player = Provider.of<NPlayer>(context, listen: false);
    final artistMap = <String, List<Music>>{};
    for (final song in player.allSongs) {
      artistMap.putIfAbsent(song.artist, () => []).add(song);
    }


    _artistList = artistMap.entries.map((entry) {
      return ArtistInfo(
        name: entry.key,
        songCount: entry.value.length,
        firstSong: entry.value.first,
        songs: entry.value,
      );
    }).toList();

    _sortArtists();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _searchQuery.isEmpty
        ? _artistList
        : _artistList
            .where((artist) => artist.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: const InputDecoration(
            hintText: 'Search artists...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Library',
            onPressed: () {
              _initializeArtistList();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
      onSelected: (String value) {
        setState(() {
          if (_sortBy == value) {
            _sortAscending = !_sortAscending;
          } else {
            _sortBy = value;
            _sortAscending = true;
          }
          _sortArtists();
          _saveSortPreferences();
        });
            },
            itemBuilder: (BuildContext context) => [
              _buildPopupMenuItem('name', Icons.person_rounded),
              _buildPopupMenuItem('songs', Icons.format_list_numbered_rounded),
              _buildPopupMenuItem('albums', Icons.album_rounded),
              _buildPopupMenuItem('year', Icons.calendar_today_rounded),
            ],
          ),
          const SizedBox(width: 15),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          child: Scrollbar(
            thumbVisibility: true,
            interactive: true,
            thickness: 8,
            radius: const Radius.circular(4),
            child: ListView.builder(
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final artist = filteredList[index];
                return _ArtistListTile(
                  artist: artist,
                  onTap: () => _showArtistSongs(context, artist),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showArtistSongs(BuildContext context, ArtistInfo artist) {
    final player = Provider.of<NPlayer>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MusicBottomSheet(
        title: artist.name,
        subtitle: '${artist.songCount} songs • ${artist.songs.map((s) => s.album).toSet().length} albums',
        itemCount: artist.songCount,
        songs: artist.songs,
        onPlayPressed: (song) => player.playArtist(artist.songs, song),
        image: artist.firstSong.picture != null
            ? Image.memory(artist.firstSong.picture!, fit: BoxFit.cover)
            : null,
      ),
    );
  }

  void _sortArtists() {
    _artistList.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          return _sortAscending ? a.name.compareTo(b.name) : b.name.compareTo(a.name);
        case 'songs':
          return _sortAscending
              ? a.songCount.compareTo(b.songCount)
              : b.songCount.compareTo(a.songCount);
        case 'albums':
          final aAlbumCount = a.songs.map((s) => s.album).toSet().length;
          final bAlbumCount = b.songs.map((s) => s.album).toSet().length;
          return _sortAscending
              ? aAlbumCount.compareTo(bAlbumCount)
              : bAlbumCount.compareTo(aAlbumCount);
        case 'year':
          return _sortAscending
              ? a.firstSong.year.compareTo(b.firstSong.year)
              : b.firstSong.year.compareTo(a.firstSong.year);
        default:
          return 0;
      }
    });
  }

  PopupMenuItem<String> _buildPopupMenuItem(String value, IconData icon) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(value.capitalize()),
        ],
      ),
    );
  }
  
 void _saveSortPreferences() {
    Settings.setArtistSort(_sortBy, _sortAscending);
  }

}

class ArtistInfo {
  final String name;
  final int songCount;
  final Music firstSong;
  final List<Music> songs;

  ArtistInfo({required this.name, required this.songCount, required this.firstSong, required this.songs});
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class _ArtistListTile extends StatefulWidget {
  final ArtistInfo artist;
  final VoidCallback onTap;

  const _ArtistListTile({
    Key? key,
    required this.artist,
    required this.onTap,
  }) : super(key: key);

  @override
  _ArtistListTileState createState() => _ArtistListTileState();
}

class _ArtistListTileState extends State<_ArtistListTile> {

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 48,
            height: 48,
            child: widget.artist.firstSong.picture != null
                ? Image.memory(widget.artist.firstSong.picture!, fit: BoxFit.cover)
                : Container(
                    color: Colors.grey[800],
                    child: Icon(Icons.album, color: Colors.grey[600]),
                  ),
          ),
        ),
        title: Text(
          widget.artist.name,
          style: TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${widget.artist.songCount} songs • ${widget.artist.songs.map((s) => s.album).toSet().length} albums',
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          widget.artist.firstSong.year,
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        ),
        onTap: widget.onTap,
      ),
    );
  }
}