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

  /// Loads sorting and organizational preferences from Settings.
  void _loadSortPreferences() {
    setState(() {
      _sortBy = Settings.albumSortBy;
      _sortAscending = Settings.albumSortAscending;
      _organizeByFolder = Settings.albumOrganizeByFolder;
    });
  }

  /// Saves sorting and organizational preferences to Settings.
  void _saveSortPreferences() {
    Settings.setAlbumSort(_sortBy, _sortAscending, _organizeByFolder);
    _initializeAlbumList(); // Re-initialize the list after saving preferences
  }

  /// Initializes the album list based on current preferences.
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

  /// Handles debounced scroll events to optimize performance.
  void _debouncedScroll(void Function() callback) {
    if (_scrollDebounce?.isActive ?? false) _scrollDebounce!.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 180), callback);
  }

  /// Listens to scroll notifications for dynamic UI updates.
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (String value) {
              if (value == 'organize_by_folder') {
                // Toggle Organize by Folder
                setState(() {
                  _organizeByFolder = !_organizeByFolder;
                  _saveSortPreferences();
                });
              } else {
                setState(() {
                  if (_sortBy == value) {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortBy = value;
                    _sortAscending = true;
                  }
                  _sortAlbums();
                  _saveSortPreferences();
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

  /// Filters albums based on the current search query.
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

  /// Displays the songs within a selected album in a bottom sheet.
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

  /// Sorts the album list based on current sorting preferences.
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

  /// Groups songs by their album names.
  Map<String, List<Music>> _groupSongsByAlbum(List<Music> songs) {
    final albumMap = <String, List<Music>>{};
    for (final song in songs) {
      albumMap.putIfAbsent(song.album, () => []).add(song);
    }
    return albumMap;
  }

  /// Organizes songs by their folder names.
  Map<String, List<Music>> _organizeByFolderFunc(List<Music> songs) {
    final folderMap = <String, List<Music>>{};
    for (final song in songs) {
      folderMap.putIfAbsent(song.folderName, () => []).add(song);
    }
    return folderMap;
  }

  /// Builds a PopupMenuItem with an icon and text.
  PopupMenuItem<String> _buildPopupMenuItem(String value, IconData icon) {
    String displayText;
    switch (value) {
      case 'name':
        displayText = 'Name';
        break;
      case 'songs':
        displayText = 'Number of Songs';
        break;
      case 'year':
        displayText = 'Year';
        break;
      case 'folder':
        displayText = 'Folder';
        break;
      default:
        displayText = value.capitalize();
    }
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(displayText),
        ],
      ),
    );
  }
}

/// Represents information about an album.
class AlbumInfo {
  final String name;
  final List<Music> songs;
  final Music firstSong;

  AlbumInfo(
      {required this.name, required this.songs, required this.firstSong});
}

extension StringExtension on String {
  /// Capitalizes the first letter of a string.
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

/// A stateless widget representing an individual album in the list.
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

  String _getYearRange() {
    if (album.songs.length == 1) {
      return album.firstSong.year;
    }

    // Find min and max years
    final years = album.songs.map((song) => song.year).where((year) => year.isNotEmpty).toList();
    if (years.isEmpty) return '';
    
    final minYear = years.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
    final maxYear = years.reduce((a, b) => a.compareTo(b) > 0 ? a : b);

    return minYear == maxYear ? minYear : '$minYear - $maxYear';
  }

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
          style: const TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${album.songs.length} songs • ${organizeByFolder ? 'Folder' : album.firstSong.artist}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          _getYearRange(),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        onTap: onTap,
      ),
    );
  }
}