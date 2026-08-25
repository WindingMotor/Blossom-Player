/// Blossom Music Player - A modern cross-platform music player built with Flutter
/// This is the main entry point of the application.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:blossom/audio/nplayer_extensions/nplayer_widget_desktop.dart';
import 'package:blossom/custom/custom_appbar.dart';
import 'package:blossom/dialog/nextcloud_startup_check.dart';
import 'package:blossom/pages/social_page.dart';
import 'package:blossom/pages/standby/standby_page.dart';
import 'package:blossom/pages/welcome_page.dart';
import 'package:blossom/tools/downloader.dart';
import 'package:blossom/tools/app_navigation.dart';
import 'package:blossom/pages/loading_page.dart';
import 'package:blossom/audio/nplaylist.dart';
import 'package:blossom/tools/nextcloud_sync.dart';
import 'package:blossom/tools/settings.dart';
import 'package:blossom/pages/albums_page.dart';
import 'package:blossom/pages/artists_page.dart';
import 'package:blossom/pages/playlist_page.dart';
import 'package:blossom/tools/sync_notification.dart';
import 'package:blossom/tools/logger.dart';
import 'package:blossom/tools/themes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'audio/nplayer.dart';
import 'audio/widgets/nplayer_widget.dart';
import 'pages/home_page.dart';
import 'pages/library_page.dart';
import 'widgets/sleep_timer_countdown.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

/// Requests necessary permissions for file access safely
Future<void> requestPermissions() async {
  if (Platform.isAndroid) {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      final int sdkVersion = androidInfo.version.sdkInt;

      if (sdkVersion >= 33) {
        if (!await Permission.audio.isGranted) {
          await Permission.audio.request();
        }
      } else {
        if (!await Permission.storage.isGranted) {
          await Permission.storage.request();
        }
      }
    } catch (e) {
      Log.w(LogTag.settings, 'Error requesting Android permissions: $e');
    }
  } else if (Platform.isIOS) {
    try {
      await Permission.photos.request();
      await Permission.mediaLibrary.request();
    } catch (e) {
      Log.w(LogTag.settings, 'Error requesting iOS permissions: $e');
    }
  }
}

/// Application entry point
void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      try {
        MetadataGod.initialize();
      } catch (e) {
        Log.d(LogTag.ui, 'MetadataGod init error (safe to ignore): $e');
      }

      await Settings.init();
      await NextcloudSync().initialize();
      final notifier = SyncNotificationManager.instance;
      try {
        await notifier.initialize();
        await notifier.requestPermissionIfNeeded();
        notifier.attachTo(NextcloudSync());
      } catch (e) {
        Log.w(LogTag.syncNotification,
            'Init failed — notifications disabled: $e');
      }

      await Settings.loadFriendsList();
      await Settings.initializeUsername();

      try {
        await PlaylistManager.load();
      } catch (e) {
        Log.w(LogTag.playlist, 'Playlist load error: $e');
      }

      if (!kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        try {
          await windowManager.ensureInitialized();
          const initialSize = Size(1024, 768);
          WindowOptions windowOptions = const WindowOptions(
            size: initialSize,
            minimumSize: Size(400, 300),
            center: true,
            backgroundColor: Colors.transparent,
            skipTaskbar: false,
            titleBarStyle: TitleBarStyle.hidden,
          );
          await windowManager.waitUntilReadyToShow(windowOptions);
          await windowManager.setResizable(true);
          await windowManager.show();
          await windowManager.focus();
        } catch (e) {
          Log.w(LogTag.ui, 'Error initializing window manager: $e');
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        requestPermissions();
      });
    } catch (e, stack) {
      Log.e(LogTag.ui, 'CRITICAL INITIALIZATION ERROR: $e', stack);
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => NPlayer()),
          ChangeNotifierProvider(create: (_) => AppNavigationController()),
          // Expose the already-initialized singleton so every
          // Consumer<NextcloudSync> in the widget tree can find it without a
          // ProviderNotFoundException (library_page, nextcloud_page, etc.).
          ChangeNotifierProvider.value(value: NextcloudSync()),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    Log.e(LogTag.ui, 'GLOBAL UNCAUGHT ERROR: $error', stack);
  });
}

/// Root widget of the application
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    final theme = getThemeData(Settings.appTheme);
    return MaterialApp(
      title: 'Blossom',
      theme: theme,
      debugShowCheckedModeBanner: false,
      // LoadingPage is now inside MainStructure so onLoaded has access to the
      // fully-mounted NPlayer context when it fires.
      home: Container(
        color: theme.scaffoldBackgroundColor,
        child: const MainStructure(),
      ),
    );
  }
}

/// Main application structure widget
class MainStructure extends StatefulWidget {
  const MainStructure({super.key});

  @override
  _MainStructureState createState() => _MainStructureState();
}

class _MainStructureState extends State<MainStructure>
    with SingleTickerProviderStateMixin {
  bool _showWelcomePage = true;
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _animationController;
  final GlobalKey<PlaylistPageState> _playlistPageKey =
      GlobalKey<PlaylistPageState>();
  final GlobalKey<SongAlbumsState> _albumsPageKey =
      GlobalKey<SongAlbumsState>();
  final GlobalKey<ArtistsPageState> _artistsPageKey =
      GlobalKey<ArtistsPageState>();
  bool _hasLoadedLibrary = false;
  bool _hasRunStartupLibraryCheck = false;
  AppNavigationController? _navigationController;

  @override
  void initState() {
    super.initState();

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        FlutterDisplayMode.setHighRefreshRate();
      }
    } catch (e) {
      Log.w(LogTag.ui, 'Display mode error: $e');
    }

    _pageController = PageController(initialPage: _currentIndex);

    try {
      _showWelcomePage = !Settings.hasSeenWelcomePage;
    } catch (e) {
      _showWelcomePage = true;
    }

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<AppNavigationController>();
    if (_navigationController == controller) return;
    _navigationController?.removeListener(_handleNavigationRequest);
    _navigationController = controller;
    _navigationController?.addListener(_handleNavigationRequest);
  }

  /// Triggered by LoadingPage once allSongs is confirmed stable.
  void _onLibraryLoaded() {
    if (!mounted) return;
    _hasLoadedLibrary = true;
    if (_hasRunStartupLibraryCheck) return;
    _hasRunStartupLibraryCheck = true;
    final nplayer = Provider.of<NPlayer>(context, listen: false);
    final snapshot = List<Music>.unmodifiable(nplayer.allSongs);
    checkNextcloudOnStartup(context, localMusic: snapshot);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  bool _isLandscape(BuildContext context) {
    try {
      return MediaQuery.of(context).orientation == Orientation.landscape &&
          (Platform.isAndroid || Platform.isIOS);
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _navigationController?.removeListener(_handleNavigationRequest);
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleNavigationRequest() {
    final request = _navigationController?.takeRequest();
    if (request == null || !mounted) return;

    switch (request.target) {
      case AppNavigationTarget.playlist:
        final playlistName = request.name;
        if (playlistName == null || playlistName.isEmpty) return;
        _openPageAndRun(_indexOfPage('playlists'), () {
          final state = _playlistPageKey.currentState;
          if (state == null) return false;
          state.openPlaylist(playlistName);
          return true;
        });
        break;
      case AppNavigationTarget.album:
        final song = request.song;
        if (song == null) return;
        _openPageAndRun(_indexOfPage('albums'), () {
          final state = _albumsPageKey.currentState;
          if (state == null) return false;
          state.openAlbumForSong(song);
          return true;
        });
        break;
      case AppNavigationTarget.artist:
        final artistName = request.name;
        if (artistName == null || artistName.isEmpty) return;
        _openPageAndRun(_indexOfPage('artists'), () {
          final state = _artistsPageKey.currentState;
          if (state == null) return false;
          state.openArtist(artistName);
          return true;
        });
        break;
    }
  }

  void _openPageAndRun(int index, bool Function() action, {int attempt = 0}) {
    if (!mounted) return;
    setState(() => _currentIndex = index);
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (action()) return;
      if (attempt < 5) {
        _openPageAndRun(index, action, attempt: attempt + 1);
      }
    });
  }

  void _onPageChanged(int index) {
    if (mounted) setState(() => _currentIndex = index);
  }

  void _dismissWelcomePage() {
    setState(() => _showWelcomePage = false);
    try {
      Settings.setHasSeenWelcomePage(true);
    } catch (e) {
      Log.w(LogTag.ui, 'Error saving welcome page state: $e');
    }
  }

  /// Single source of truth for the tab pages: id, widget, title, and nav
  /// icons stay in sync no matter which optional pages are enabled.
  List<_PageEntry> _buildPageEntries() {
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    final entries = <_PageEntry>[
      if (Settings.showHomePage)
        _PageEntry(
          id: 'home',
          title: 'Home',
          label: 'Home',
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          page: const HomePage(),
        ),
      _PageEntry(
        id: 'library',
        title: 'Song Library',
        label: 'Library',
        icon: Icons.library_music_rounded,
        activeIcon: Icons.library_music,
        page: SongLibrary(onThemeChanged: _onThemeChanged),
      ),
      _PageEntry(
        id: 'playlists',
        title: 'Playlists',
        label: 'Playlists',
        icon: Icons.playlist_play_rounded,
        activeIcon: Icons.playlist_play,
        page: PlaylistPage(key: _playlistPageKey),
      ),
      _PageEntry(
        id: 'albums',
        title: 'Albums',
        label: 'Albums',
        icon: Icons.album_rounded,
        activeIcon: Icons.album,
        page: SongAlbums(key: _albumsPageKey),
      ),
      _PageEntry(
        id: 'artists',
        title: 'Artists',
        label: 'Artists',
        icon: Icons.person_rounded,
        activeIcon: Icons.person,
        page: ArtistsPage(key: _artistsPageKey),
      ),
      if (Settings.isPublicSharingEnabled)
        _PageEntry(
          id: 'social',
          title: 'Social',
          label: 'Social',
          icon: Icons.people_outline_rounded,
          activeIcon: Icons.people_rounded,
          page: const SocialPage(),
        ),
      if (isDesktop)
        _PageEntry(
          id: 'downloader',
          title: 'Downloader',
          label: 'Download',
          icon: Icons.download_rounded,
          activeIcon: Icons.download,
          page: const Downloader(),
        ),
    ];

    return entries;
  }

  int _indexOfPage(String id) {
    final index = _buildPageEntries().indexWhere((e) => e.id == id);
    return index == -1 ? 0 : index;
  }

  List<Widget> _getPages() =>
      _buildPageEntries().map((e) => e.page).toList();

  String _getAppBarTitle() {
    final entries = _buildPageEntries();
    if (_currentIndex >= 0 && _currentIndex < entries.length) {
      return entries[_currentIndex].title;
    }
    return 'Blossom';
  }

  double _getPlayerBottomOffset() {
    if (_showWelcomePage) return 10;
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return isDesktop ? 80 : 70 + bottomPadding;
  }

  List<_ModernNavItem> _getNavItems() {
    final entries = _buildPageEntries();
    return [
      for (var i = 0; i < entries.length; i++)
        _ModernNavItem(
          icon: entries[i].icon,
          activeIcon: entries[i].activeIcon,
          label: entries[i].label,
          index: i,
        ),
    ];
  }

  Widget _buildModernBottomNavBar() {
    if (_showWelcomePage) return const SizedBox.shrink();

    final navItems = _getNavItems();
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    return Positioned(
      left: isDesktop ? 16 : 8,
      right: isDesktop ? 16 : 8,
      bottom: isDesktop ? 16 : 8,
      child: SafeArea(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isDesktop ? 16 : 20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(isDesktop ? 16 : 20),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .shadow
                        .withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: navItems
                    .map((item) => _ModernNavButton(
                          item: item,
                          isActive: _currentIndex == item.index,
                          onTap: () {
                            if (mounted) {
                              setState(() => _currentIndex = item.index);
                              _pageController.jumpToPage(item.index);
                              _animationController.forward().then((_) {
                                _animationController.reverse();
                              });
                            }
                          },
                          isDesktop: isDesktop,
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = getThemeData(Settings.appTheme);
    final pages = _getPages();

    if (_currentIndex >= pages.length) {
      _currentIndex = 0;
      _pageController.jumpToPage(0);
    }

    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    return LoadingPage(
      theme: theme,
      onLoaded: _onLibraryLoaded,
      initiallyLoaded: _hasLoadedLibrary,
      child: _isLandscape(context)
          ? const StandbyPage()
          : Scaffold(
              appBar: !Platform.isIOS && !Platform.isAndroid
                  ? CustomAppBar(
                      titleWidget: Text(
                        _getAppBarTitle(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      additionalActions: isDesktop
                          ? [
                              IconButton(
                                icon: const Icon(Icons.fullscreen),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const StandbyPage(),
                                    ),
                                  );
                                },
                                tooltip: 'Enter Standby Mode',
                              ),
                            ]
                          : null,
                    )
                  : null,
              extendBody: true,
              body: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: pages.length,
                    itemBuilder: (context, index) {
                      if (index >= pages.length) return const SizedBox.shrink();
                      return pages[index];
                    },
                    onPageChanged: _onPageChanged,
                    physics: const ClampingScrollPhysics(),
                  ),
                  if (_showWelcomePage)
                    WelcomePage(onDismiss: _dismissWelcomePage),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: _getPlayerBottomOffset(),
                    child: _isLandscape(context)
                        ? const SizedBox.shrink()
                        : isDesktop
                            ? const NPlayerWidgetDesktop()
                            : const NPlayerWidget(),
                  ),
                  _buildModernBottomNavBar(),
                  const SleepTimerCountdown(),
                ],
              ),
            ),
    );
  }
}

/// Descriptor tying together a tab page, its title, and its nav icons.
class _PageEntry {
  final String id;
  final String title;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;

  const _PageEntry({
    required this.id,
    required this.title,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.page,
  });
}

/// Data class for navigation items
class _ModernNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;

  const _ModernNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
  });
}

/// Modern navigation button widget
class _ModernNavButton extends StatefulWidget {
  final _ModernNavItem item;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDesktop;

  const _ModernNavButton({
    required this.item,
    required this.isActive,
    required this.onTap,
    required this.isDesktop,
  });

  @override
  _ModernNavButtonState createState() => _ModernNavButtonState();
}

class _ModernNavButtonState extends State<_ModernNavButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_ModernNavButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          highlightColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: SizedBox(
                  height: 50,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(widget.isActive ? 8 : 6),
                      decoration: BoxDecoration(
                        color: widget.isActive
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.isActive
                            ? widget.item.activeIcon
                            : widget.item.icon,
                        size: widget.isDesktop ? 18 : 22,
                        color: widget.isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
