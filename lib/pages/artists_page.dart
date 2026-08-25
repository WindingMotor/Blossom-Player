import 'dart:async';
import 'package:blossom/custom/search_bar.dart';
import 'package:blossom/song_list/song_list_tile.dart';
import 'package:blossom/tools/settings.dart';
import 'package:blossom/tools/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import '../sheets/bottom_sheet.dart';

class ArtistsPage extends StatefulWidget {
  const ArtistsPage({super.key});

  @override
  ArtistsPageState createState() => ArtistsPageState();
}

class ArtistsPageState extends State<ArtistsPage>
    with TickerProviderStateMixin {
  late String _sortBy;
  late bool _sortAscending;
  final TextEditingController _searchController = TextEditingController();
  List<ArtistInfo> _artistList = [];
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
      _initializeArtistList();
      if (mounted) {
        _animationController.forward();
        final saved = Settings.artistsScrollPosition;
        if (saved > 0 && _scrollController.hasClients) {
          _scrollController.jumpTo(saved);
        }
      }
    });
  }

  void _onScroll() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      Settings.setArtistsScrollPosition(_scrollController.offset);
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

  void _showSortMenu() {
    UIHelpers.showSortMenu(
      context,
      buttonKey: _sortButtonKey,
      items: [
        UIHelpers.buildPopupMenuItem(
          context,
          value: 'name',
          icon: Icons.person_rounded,
          isActive: _sortBy == 'name',
        ),
        UIHelpers.buildPopupMenuItem(
          context,
          value: 'songs',
          icon: Icons.format_list_numbered_rounded,
          isActive: _sortBy == 'songs',
        ),
        UIHelpers.buildPopupMenuItem(
          context,
          value: 'albums',
          icon: Icons.album_rounded,
          isActive: _sortBy == 'albums',
        ),
        UIHelpers.buildPopupMenuItem(
          context,
          value: 'year',
          icon: Icons.calendar_today_rounded,
          isActive: _sortBy == 'year',
        ),
      ],
    ).then((String? value) {
      if (value != null) {
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
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filterArtists();

    return Scaffold(
      backgroundColor: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.1),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              OptimizedSearchBar(
                searchController: _searchController,
                onSearchChanged: (value) {
                  if (value.length == 1 && _scrollController.hasClients) {
                    _scrollController.jumpTo(0);
                    Settings.setArtistsScrollPosition(0);
                  }
                  setState(() {});
                },
                hintText: 'Search artists...',
                trailingWidget: UIHelpers.buildSortButton(
                  context,
                  key: _sortButtonKey,
                  onTap: _showSortMenu,
                  sortAscending: _sortAscending,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    interactive: true,
                    radius: const Radius.circular(10),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 0),
                      controller: _scrollController,
                      itemCount: filteredList.length,
                      itemExtent:
                          UIHelpers.isDesktopPlatform(context) ? 60.0 : 80.0,
                      cacheExtent: 1000,
                      itemBuilder: (context, index) {
                        final artist = filteredList[index];
                        return _ArtistListTile(
                          key: ValueKey(artist.name),
                          artist: artist,
                          onTap: () => _showArtistSongs(context, artist),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<ArtistInfo> _filterArtists() {
    if (_searchController.text.isEmpty) {
      return _artistList;
    }
    final lowercaseQuery = _searchController.text.toLowerCase();
    return _artistList
        .where((artist) => artist.name.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  void _showArtistSongs(BuildContext context, ArtistInfo artist) {
    final player = Provider.of<NPlayer>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MusicBottomSheet(
        title: artist.name,
        subtitle:
            '${artist.songCount} songs • ${artist.songs.map((s) => s.album).toSet().length} albums',
        itemCount: artist.songCount,
        songs: artist.songs,
        onPlayPressed: (song) => player.playArtist(artist.songs, song),
        image: artist.firstSong.picture != null
            ? Image(
                image: AlbumArtCache.of(
                    artist.firstSong.path, artist.firstSong.picture!),
                fit: BoxFit.cover)
            : null,
      ),
    );
  }

  void openArtist(String artistName) {
    if (_artistList.isEmpty) {
      _initializeArtistList();
    }

    final index = _artistList.indexWhere(
      (artist) => artist.name.toLowerCase() == artistName.toLowerCase(),
    );
    if (index == -1) return;

    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      setState(() {});
    }

    final itemExtent = UIHelpers.isDesktopPlatform(context) ? 60.0 : 80.0;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        index * itemExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showArtistSongs(context, _artistList[index]);
    });
  }

  void _sortArtists() {
    _artistList.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          return _sortAscending
              ? a.name.compareTo(b.name)
              : b.name.compareTo(a.name);
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

  void _saveSortPreferences() {
    Settings.setArtistSort(_sortBy, _sortAscending);
  }
}

class ArtistInfo {
  final String name;
  final int songCount;
  final int albumCount;
  final String yearRange;
  final Music firstSong;
  final List<Music> songs;

  ArtistInfo({
    required this.name,
    required this.songCount,
    required this.firstSong,
    required this.songs,
  })  : albumCount = songs.map((s) => s.album).toSet().length,
        yearRange = UIHelpers.getYearRange(songs, (s) => (s as Music).year);
}

class _ArtistListTile extends StatelessWidget {
  final ArtistInfo artist;
  final VoidCallback onTap;

  const _ArtistListTile({
    Key? key,
    required this.artist,
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
          picture: artist.firstSong.picture,
          songPath: artist.firstSong.path,
          icon: Icons.person_rounded,
        ),
        title: Text(
          artist.name,
          style: textTheme.bodyMedium,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${artist.songCount} songs • ${artist.albumCount} albums',
          style: textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).round()),
          ),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          artist.yearRange,
          style: textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).round()),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
