import 'dart:async';
import 'package:blossom/custom/search_bar.dart';
import 'package:blossom/song_list/song_list_tile.dart';
import 'package:blossom/tools/settings.dart';
import 'package:blossom/tools/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import '../sheets/bottom_sheet.dart';

class SongAlbums extends StatefulWidget {
  const SongAlbums({super.key});

  @override
  _SongAlbumsState createState() => _SongAlbumsState();
}

class _SongAlbumsState extends State<SongAlbums>
    with TickerProviderStateMixin {
  late String _sortBy;
  late bool _sortAscending;
  late bool _organizeByFolder;
  final TextEditingController _searchController = TextEditingController();
  List<AlbumInfo> _albumList = [];
  final ScrollController _scrollController = ScrollController();
  Timer? _saveDebounce;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final GlobalKey _sortButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _loadSortPreferences();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAlbumList();
      if (mounted) {
        _animationController.forward();
        final saved = Settings.albumsScrollPosition;
        if (saved > 0 && _scrollController.hasClients) {
          _scrollController.jumpTo(saved);
        }
      }
    });
  }

  void _onScroll() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      Settings.setAlbumsScrollPosition(_scrollController.offset);
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _loadSortPreferences() {
    setState(() {
      _sortBy = Settings.albumSortBy;
      _sortAscending = Settings.albumSortAscending;
      _organizeByFolder = Settings.albumOrganizeByFolder;
    });
  }

  void _saveSortPreferences() {
    Settings.setAlbumSort(_sortBy, _sortAscending, _organizeByFolder);
    _initializeAlbumList();
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

  void _showSortMenu() {
    UIHelpers.showSortMenu(
      context,
      buttonKey: _sortButtonKey,
      items: [
        UIHelpers.buildPopupMenuItem(
          context,
          value: 'name',
          icon: Icons.abc_rounded,
          isActive: _sortBy == 'name',
          displayText: 'Name',
        ),
        UIHelpers.buildPopupMenuItem(
          context,
          value: 'songs',
          icon: Icons.format_list_numbered_rounded,
          isActive: _sortBy == 'songs',
          displayText: 'Number of Songs',
        ),
        UIHelpers.buildPopupMenuItem(
          context,
          value: 'year',
          icon: Icons.calendar_today_rounded,
          isActive: _sortBy == 'year',
          displayText: 'Year',
        ),
        UIHelpers.buildPopupMenuItem(
          context,
          value: 'folder',
          icon: Icons.folder_rounded,
          isActive: _sortBy == 'folder',
          displayText: 'Folder',
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'organize_by_folder',
          child: Row(
            children: [
              Icon(
                _organizeByFolder ? Icons.album_rounded : Icons.folder_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                _organizeByFolder ? 'Group by Album' : 'Organize by Folder',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((String? value) {
      if (value != null) {
        if (value == 'organize_by_folder') {
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
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filterAlbums();
    final largeAlbums = filteredList.where((album) => album.songs.length >= 5).toList();
    final smallAlbums = filteredList.where((album) => album.songs.length < 5).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              OptimizedSearchBar(
                searchController: _searchController,
                onSearchChanged: (value) {
                  if (value.length == 1) {
                    _scrollController.jumpTo(0);
                    Settings.setAlbumsScrollPosition(0);
                  }
                  if (mounted) setState(() {});
                },
                hintText: 'Search albums...',
                trailingWidget: UIHelpers.buildSortButton(
                  context,
                  key: _sortButtonKey,
                  onTap: _showSortMenu,
                  sortAscending: _sortAscending,
                ),
              ),
              
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  interactive: true,
                  radius: const Radius.circular(10),
                  child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        if (largeAlbums.isNotEmpty) ...[
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            sliver: SliverToBoxAdapter(
                              child: Text(
                                'Albums (${largeAlbums.length})',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            sliver: SliverGrid(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                                childAspectRatio: 0.85,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final album = largeAlbums[index];
                                  return _AlbumCard(
                                    album: album,
                                    organizeByFolder: _organizeByFolder,
                                    onTap: () => _showAlbumSongs(context, album),
                                  );
                                },
                                childCount: largeAlbums.length,
                              ),
                            ),
                          ),
                        ],
                        if (smallAlbums.isNotEmpty) ...[
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                            sliver: SliverToBoxAdapter(
                              child: Text(
                                'Singles & EPs (${smallAlbums.length})',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final album = smallAlbums[index];
                                  return _AlbumListTile(
                                    album: album,
                                    organizeByFolder: _organizeByFolder,
                                    onTap: () => _showAlbumSongs(context, album),
                                  );
                                },
                                childCount: smallAlbums.length,
                              ),
                            ),
                          ),
                        ],
                        const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<AlbumInfo> _filterAlbums() {
    if (_searchController.text.isEmpty) {
      return _albumList;
    }
    final lowercaseQuery = _searchController.text.toLowerCase();
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
      useSafeArea: true,
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
}

class AlbumInfo {
  final String name;
  final List<Music> songs;
  final Music firstSong;
  final String yearRange;

  AlbumInfo({required this.name, required this.songs, required this.firstSong})
      : yearRange = UIHelpers.getYearRange(songs, (s) => (s as Music).year);
}

class _AlbumCard extends StatelessWidget {
  final AlbumInfo album;
  final bool organizeByFolder;
  final VoidCallback onTap;

  const _AlbumCard({
    Key? key,
    required this.album,
    required this.organizeByFolder,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: album.firstSong.picture != null
                      ? Image(
                          image: AlbumArtCache.of(album.firstSong.path, album.firstSong.picture!),
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.album,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    organizeByFolder ? 'Folder' : album.firstSong.artist,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.music_note,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${album.songs.length} songs',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        album.yearRange,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
    final isDesktop = UIHelpers.isDesktopPlatform(context);
    final tileSize = isDesktop ? 36.0 : 48.0;

    return Card(
      color: Theme.of(context).cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        dense: isDesktop,
        visualDensity: isDesktop ? VisualDensity.compact : VisualDensity.standard,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: tileSize,
            height: tileSize,
            child: album.firstSong.picture != null
                ? Image(
                    image: AlbumArtCache.of(album.firstSong.path, album.firstSong.picture!),
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: Colors.grey[800],
                    child: Icon(Icons.album, color: Colors.grey[600]),
                  ),
          ),
        ),
        title: Text(album.name, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${album.songs.length} songs • ${organizeByFolder ? 'Folder' : album.firstSong.artist}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          album.yearRange,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        onTap: onTap,
      ),
    );
  }
}