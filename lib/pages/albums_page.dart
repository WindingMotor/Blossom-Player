import 'dart:async';
import 'package:blossom/custom/search_bar.dart';
import 'package:blossom/song_list/song_list_tile.dart';
import 'package:blossom/tools/settings.dart';
import 'package:blossom/tools/ui_helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import '../sheets/bottom_sheet.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

class AlbumInfo {
  final String name;
  final List<Music> songs;
  final Music firstSong;
  final String yearRange;

  AlbumInfo({required this.name, required this.songs, required this.firstSong})
      : yearRange = UIHelpers.getYearRange(songs, (s) => (s as Music).year);
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class SongAlbums extends StatefulWidget {
  const SongAlbums({super.key});

  @override
  SongAlbumsState createState() => SongAlbumsState();
}

class SongAlbumsState extends State<SongAlbums>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late String _sortBy;
  late bool _sortAscending;
  late bool _organizeByFolder;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _sortButtonKey = GlobalKey();

  List<AlbumInfo> _albumList = [];
  List<AlbumInfo> _largeAlbums = [];
  List<AlbumInfo> _smallAlbums = [];

  Timer? _saveDebounce;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Load prefs without setState — these are late fields, no build needed yet
    _sortBy = Settings.albumSortBy;
    _sortAscending = Settings.albumSortAscending;
    _organizeByFolder = Settings.albumOrganizeByFolder;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAlbumList(); // sync, instant
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

  void _onScroll() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      Settings.setAlbumsScrollPosition(_scrollController.offset);
    });
  }

  // ── Core data pipeline — async, off UI thread ──────────────────────────────

  void _initializeAlbumList() {
    final player = Provider.of<NPlayer>(context, listen: false);
    final albumMap = _organizeByFolder ? player.folderMap : player.albumMap;

    final list = albumMap.entries
        .map((entry) => AlbumInfo(
              name: entry.key,
              songs: entry.value,
              firstSong: entry.value.first,
            ))
        .toList();

    _sortList(list);
    final filtered = _applySearch(list);

    setState(() {
      _albumList = list;
      _largeAlbums = filtered.where((a) => a.songs.length >= 5).toList();
      _smallAlbums = filtered.where((a) => a.songs.length < 5).toList();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _animationController.forward();
      final saved = Settings.albumsScrollPosition;
      if (saved > 0 && _scrollController.hasClients) {
        _scrollController.jumpTo(saved);
      }
    });
  }

  void _sortList(List<AlbumInfo> list) {
    list.sort((a, b) {
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

  List<AlbumInfo> _applySearch(List<AlbumInfo> source) {
    if (_searchController.text.isEmpty) return source;
    final q = _searchController.text.toLowerCase();
    return source.where((a) {
      return a.name.toLowerCase().contains(q) ||
          a.firstSong.artist.toLowerCase().contains(q);
    }).toList();
  }

  void _rebuildDisplayLists() {
    final filtered = _applySearch(_albumList);
    setState(() {
      _largeAlbums = filtered.where((a) => a.songs.length >= 5).toList();
      _smallAlbums = filtered.where((a) => a.songs.length < 5).toList();
    });
  }

  void _saveSortPreferences() {
    Settings.setAlbumSort(_sortBy, _sortAscending, _organizeByFolder);
  }

  void _showSortMenu() {
    UIHelpers.showSortMenu(
      context,
      buttonKey: _sortButtonKey,
      items: [
        UIHelpers.buildPopupMenuItem(context,
            value: 'name',
            icon: Icons.abc_rounded,
            isActive: _sortBy == 'name',
            displayText: 'Name'),
        UIHelpers.buildPopupMenuItem(context,
            value: 'songs',
            icon: Icons.format_list_numbered_rounded,
            isActive: _sortBy == 'songs',
            displayText: 'Number of Songs'),
        UIHelpers.buildPopupMenuItem(context,
            value: 'year',
            icon: Icons.calendar_today_rounded,
            isActive: _sortBy == 'year',
            displayText: 'Year'),
        UIHelpers.buildPopupMenuItem(context,
            value: 'folder',
            icon: Icons.folder_rounded,
            isActive: _sortBy == 'folder',
            displayText: 'Folder'),
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
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
      ],
    ).then((String? value) {
      if (value == null) return;

      if (value == 'organize_by_folder') {
        // FIX: mutate state first, THEN save + reload — no nested setState
        setState(() => _organizeByFolder = !_organizeByFolder);
        _saveSortPreferences();
        _initializeAlbumList(); // re-run async pipeline with new grouping
      } else {
        setState(() {
          if (_sortBy == value) {
            _sortAscending = !_sortAscending;
          } else {
            _sortBy = value;
            _sortAscending = true;
          }
        });
        _saveSortPreferences();
        // Sorting is cheap — do it synchronously on existing list
        _sortList(_albumList);
        _rebuildDisplayLists();
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.1),
      body: SafeArea(
        child: Column(
          children: [
            OptimizedSearchBar(
              searchController: _searchController,
              onSearchChanged: (value) {
                if (value.length == 1 && _scrollController.hasClients) {
                  _scrollController.jumpTo(0);
                  Settings.setAlbumsScrollPosition(0);
                }
                _rebuildDisplayLists();
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
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_largeAlbums.isEmpty && _smallAlbums.isEmpty) {
      return UIHelpers.buildEmptyState(
        context,
        icon: Icons.album_outlined,
        title: 'No albums found',
        subtitle: 'Add some music to get started',
      );
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      interactive: true,
      radius: const Radius.circular(10),
      child: CustomScrollView(
        controller: _scrollController,
        cacheExtent: 800,
        slivers: [
          if (_largeAlbums.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Albums (${_largeAlbums.length})',
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
                  crossAxisCount:
                      MediaQuery.of(context).size.width > 600 ? 3 : 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final album = _largeAlbums[index];
                    return RepaintBoundary(
                      child: _AlbumCard(
                        album: album,
                        organizeByFolder: _organizeByFolder,
                        onTap: () => _showAlbumSongs(context, album),
                      ),
                    );
                  },
                  childCount: _largeAlbums.length,
                ),
              ),
            ),
          ],
          if (_smallAlbums.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Singles & EPs (${_smallAlbums.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              sliver: SliverFixedExtentList(
                itemExtent: [
                  TargetPlatform.windows,
                  TargetPlatform.linux,
                  TargetPlatform.macOS
                ].contains(Theme.of(context).platform)
                    ? 72
                    : 88,
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final album = _smallAlbums[index];
                    return RepaintBoundary(
                      child: _AlbumListTile(
                        album: album,
                        organizeByFolder: _organizeByFolder,
                        onTap: () => _showAlbumSongs(context, album),
                      ),
                    );
                  },
                  childCount: _smallAlbums.length,
                ),
              ),
            ),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
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

  void openAlbumForSong(Music song) {
    if (_organizeByFolder) {
      _organizeByFolder = false;
      _saveSortPreferences();
      _initializeAlbumList();
    }

    final album = _albumList.cast<AlbumInfo?>().firstWhere(
          (album) => album?.name == song.album,
          orElse: () => null,
        );
    if (album == null) return;

    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      _rebuildDisplayLists();
    }

    final largeIndex = _largeAlbums.indexWhere((a) => a.name == album.name);
    final smallIndex = _smallAlbums.indexWhere((a) => a.name == album.name);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 600;
    double offset = 0;

    if (largeIndex != -1) {
      final crossAxisCount = isDesktop ? 3 : 2;
      final row = largeIndex ~/ crossAxisCount;
      final cardWidth =
          (width - 16 - (crossAxisCount - 1) * 12) / crossAxisCount;
      final cardHeight = cardWidth / 0.85;
      offset = 48 + row * (cardHeight + 12);
    } else if (smallIndex != -1) {
      final crossAxisCount = isDesktop ? 3 : 2;
      final largeRows = (_largeAlbums.length / crossAxisCount).ceil();
      final cardWidth =
          (width - 16 - (crossAxisCount - 1) * 12) / crossAxisCount;
      final cardHeight = cardWidth / 0.85;
      final smallExtent = UIHelpers.isDesktopPlatform(context) ? 72.0 : 88.0;
      offset =
          48 + largeRows * (cardHeight + 12) + 64 + smallIndex * smallExtent;
    }

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showAlbumSongs(context, album);
    });
  }
}

// ─── Album grid card ──────────────────────────────────────────────────────────

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
      clipBehavior: Clip.antiAlias,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: album.firstSong.picture != null
                  ? Image(
                      image: AlbumArtCache.of(
                          album.firstSong.path, album.firstSong.picture!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      // Graceful fallback if art fails to decode
                      errorBuilder: (_, __, ___) => _PlaceholderArt(),
                    )
                  : _PlaceholderArt(),
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
                      Icon(Icons.music_note,
                          size: 14,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '${album.songs.length} songs',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 11,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        album.yearRange,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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

class _PlaceholderArt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.album,
        size: 64,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
      ),
    );
  }
}

// ─── Album list tile (singles/EPs) ────────────────────────────────────────────

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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDesktop = UIHelpers.isDesktopPlatform(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: isDesktop ? 2 : 4,
      ),
      child: ListTile(
        dense: isDesktop,
        visualDensity:
            isDesktop ? VisualDensity.compact : VisualDensity.standard,
        leading: AlbumArtThumbnail(
          picture: album.firstSong.picture,
          songPath: album.firstSong.path,
          icon: Icons.album,
        ),
        title: Text(
          album.name,
          style: textTheme.bodyMedium,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${album.songs.length} songs • ${organizeByFolder ? 'Folder' : album.firstSong.artist}',
          style: textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).round()),
          ),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          album.yearRange,
          style: textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).round()),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
