import 'dart:async';

import 'package:blossom/custom/custom_searchbar.dart';
import 'package:blossom/tools/settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import '../sheets/bottom_sheet.dart';

class SongAlbums extends StatefulWidget {
  const SongAlbums({super.key});

  @override
  _SongAlbumsState createState() => _SongAlbumsState();
}

class _SongAlbumsState extends State<SongAlbums> {
  late String _sortBy;
  late bool _sortAscending;
  late bool _organizeByFolder;
  String _searchQuery = '';
  List<AlbumInfo> _albumList = [];
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollDebounce;

  @override
  void initState() {
    super.initState();
    _loadSortPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAlbumList();
    });
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadSortPreferences() {
    if (mounted) {
      setState(() {
        _sortBy = Settings.albumSortBy;
        _sortAscending = Settings.albumSortAscending;
        _organizeByFolder = Settings.albumOrganizeByFolder;
      });
    }
  }

  void _saveSortPreferences() {
    Settings.setAlbumSort(_sortBy, _sortAscending, _organizeByFolder);
  }

  void _initializeAlbumList() {
    final player = Provider.of<NPlayer>(context, listen: false);
    final albumMap = _organizeByFolder
        ? _organizeByFolderFunc(player.allSongs)
        : _groupSongsByAlbum(player.allSongs);
    _albumList = albumMap.entries.map((entry) {
      return AlbumInfo(
        name: entry.key,
        songs: entry.value,
        firstSong: entry.value.first,
      );
    }).toList();
    _sortAlbums();
    if (mounted) {
      setState(() {});
    }
  }

  void _debouncedScroll(void Function() callback) {
    if (_scrollDebounce?.isActive ?? false) _scrollDebounce!.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 180), callback);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      if (mounted) {
        _debouncedScroll(() {
          setState(() {});
        });
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filterAlbums();

    return Scaffold(
      appBar: CustomSearchBar(
        hintText: 'Search albums...',
        onChanged: (value) {
          if (mounted) {
            setState(() {
              _searchQuery = value;
            });
          }
        },
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (String value) {
              if (mounted) {
                setState(() {
                  if (value == 'organize_by_folder') {
                    _organizeByFolder = !_organizeByFolder;
                    _initializeAlbumList();
                  } else {
                    if (_sortBy == value) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortBy = value;
                      _sortAscending = true;
                    }
                    _sortAlbums();
                    _saveSortPreferences();
                  }
                });
              }
            },
            itemBuilder: (BuildContext context) => [
              _buildPopupMenuItem('name', Icons.abc_rounded),
              _buildPopupMenuItem('songs', Icons.format_list_numbered_rounded),
              _buildPopupMenuItem('year', Icons.calendar_today_rounded),
              _buildPopupMenuItem('folder', Icons.folder_rounded),
              PopupMenuItem(
                value: 'organize_by_folder',
                child: Row(
                  children: [
                    Icon(
                        _organizeByFolder
                            ? Icons.album_rounded
                            : Icons.folder_rounded,
                        size: 20),
                    const SizedBox(width: 8),
                    Text(_organizeByFolder
                        ? 'Group by Album'
                        : 'Organize by Folder'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 15),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 10),
              itemCount: filteredList.length,
              itemExtent: 80.0,
              cacheExtent: 1000,
              itemBuilder: (context, index) {
                final album = filteredList[index];
                return _AlbumListTile(
                  key: ValueKey(album.name),
                  album: album,
                  organizeByFolder: _organizeByFolder,
                  onTap: () => _showAlbumSongs(context, album),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<AlbumInfo> _filterAlbums() {
    if (_searchQuery.isEmpty) {
      return _albumList;
    }
    final lowercaseQuery = _searchQuery.toLowerCase();
    return _albumList
        .where((album) =>
            album.name.toLowerCase().contains(lowercaseQuery) ||
            album.firstSong.artist.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  void _showAlbumSongs(BuildContext context, AlbumInfo album) {
    final player = Provider.of<NPlayer>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MusicBottomSheet(
        title: album.name,
        subtitle:
            '${album.songs.length} songs • ${_organizeByFolder ? 'Folder' : album.firstSong.artist}',
        itemCount: album.songs.length,
        songs: album.songs,
        onPlayPressed: (song) => player.playAlbum(album.songs, song),
        image: album.firstSong.picture != null
            ? Image.memory(album.firstSong.picture!, fit: BoxFit.cover)
            : null,
      ),
    );
  }

  void _sortAlbums() {
    _albumList.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          return _sortAscending
              ? a.name.compareTo(b.name)
              : b.name.compareTo(a.name);
        case 'songs':
          return _sortAscending
              ? a.songs.length.compareTo(b.songs.length)
              : b.songs.length.compareTo(a.songs.length);
        case 'year':
          return _sortAscending
              ? a.firstSong.year.compareTo(b.firstSong.year)
              : b.firstSong.year.compareTo(a.firstSong.year);
        case 'folder':
          return _sortAscending
              ? a.firstSong.folderName.compareTo(b.firstSong.folderName)
              : b.firstSong.folderName.compareTo(a.firstSong.folderName);
        default:
          return 0;
      }
    });
  }

  Map<String, List<Music>> _groupSongsByAlbum(List<Music> songs) {
    final albumMap = <String, List<Music>>{};
    for (final song in songs) {
      albumMap.putIfAbsent(song.album, () => []).add(song);
    }
    return albumMap;
  }

  Map<String, List<Music>> _organizeByFolderFunc(List<Music> songs) {
    final folderMap = <String, List<Music>>{};
    for (final song in songs) {
      folderMap.putIfAbsent(song.folderName, () => []).add(song);
    }
    return folderMap;
  }

  PopupMenuItem<String> _buildPopupMenuItem(String value, IconData icon) {
    return PopupMenuItem(
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
}

class AlbumInfo {
  final String name;
  final List<Music> songs;
  final Music firstSong;

  AlbumInfo({required this.name, required this.songs, required this.firstSong});
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class _AlbumListTile extends StatelessWidget {
  final AlbumInfo album;
  final bool organizeByFolder;
  final VoidCallback onTap;

  const _AlbumListTile({
    Key? key,
    required this.album,
    required this.organizeByFolder,
    required this.onTap,
  }) : super(key: key);

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
            child: album.firstSong.picture != null
                ? Image.memory(album.firstSong.picture!, fit: BoxFit.cover)
                : Container(
                    color: Colors.grey[800],
                    child: Icon(Icons.album, color: Colors.grey[600]),
                  ),
          ),
        ),
        title: Text(
          album.name,
          style: TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${album.songs.length} songs • ${organizeByFolder ? 'Folder' : album.firstSong.artist}',
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          album.firstSong.year,
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        ),
        onTap: onTap,
      ),
    );
  }
}
