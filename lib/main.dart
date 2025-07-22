/// Blossom Music Player - A modern cross-platform music player built with Flutter
/// This is the main entry point of the application.

import 'dart:io';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:blossom/audio/nplayer_extensions/nplayer_widget_desktop.dart';
import 'package:blossom/binder/ios_mount_widget.dart';
import 'package:blossom/custom/custom_appbar.dart';
import 'package:blossom/pages/standby/standby_page.dart';
import 'package:blossom/pages/welcome_page.dart';
import 'package:blossom/tools/downloader.dart';
import 'package:blossom/pages/loading_page.dart';
import 'package:blossom/audio/nplaylist.dart';
import 'package:blossom/tools/settings.dart';
import 'package:blossom/pages/albums_page.dart';
import 'package:blossom/pages/artists_page.dart';
import 'package:blossom/pages/playlist_page.dart';
import 'package:blossom/tools/themes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'audio/nplayer.dart';
import 'audio/widgets/nplayer_widget.dart';
import 'pages/library_page.dart';
import 'widgets/sleep_timer_countdown.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Requests necessary permissions for file access based on the platform
/// For Android: Storage and External Storage permissions
/// For iOS: Photos permission
/// Requests necessary permissions for file access based on the platform
Future<void> requestPermissions() async {
  if (Platform.isAndroid) {
    try {
      // Get device info to check Android version
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      final int sdkVersion = androidInfo.version.sdkInt;
      
      if (sdkVersion >= 33) { // Android 13+
        // Request granular media permissions for Android 13+
        await Permission.audio.request();
        
        // Check if permission was granted
        final bool audioGranted = await Permission.audio.isGranted;
        
        if (audioGranted) {
          print('Audio permission granted successfully');
        } else {
          print('Audio permission denied - please enable in Settings');
        }
      } else {
        // For Android 12 and below, use storage permission
        await Permission.storage.request();
        final bool storageGranted = await Permission.storage.isGranted;
        
        if (storageGranted) {
          print('Storage permission granted successfully');
        } else {
          print('Storage permission denied - please enable in Settings');
        }
      }
    } catch (e) {
      print('Error requesting Android permissions: $e');
      // Try a fallback approach
      try {
        await Permission.storage.request();
      } catch (fallbackError) {
        print('Fallback permission request also failed: $fallbackError');
      }
    }
  } else if (Platform.isIOS) {
    try {
      // For iOS, request both photos and media library permissions
      final photosStatus = await Permission.photos.request();
      final mediaLibraryStatus = await Permission.mediaLibrary.request();
      
      if (photosStatus.isGranted) {
        print('iOS Photos permission granted');
      } else {
        print('iOS Photos permission denied');
      }
      
      if (mediaLibraryStatus.isGranted) {
        print('iOS Media Library permission granted');
      } else {
        print('iOS Media Library permission denied');
      }
    } catch (e) {
      print('Error requesting iOS permissions: $e');
    }
  }
}

/// Application entry point
/// Initializes essential services and launches the app
void main() async {
  // Ensure Flutter bindings are initialized first
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize metadata handling service
  MetadataGod.initialize();
  
  // Initialize app settings
  await Settings.init();
  await PlaylistManager.load();

  // Get directories first
  final songDir = await Settings.getSongDir();
  print("SONG SETTINGS DIRECTORY: $songDir");

  final applicationsDir = await getApplicationDocumentsDirectory();
  print("APPLICATIONS DIRECTORY: $applicationsDir");

  // Request permissions after UI is initialized
  WidgetsBinding.instance.addPostFrameCallback((_) {
    requestPermissions();
  });

  // Desktop window configuration
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    try {
      await windowManager.ensureInitialized();
      WindowOptions windowOptions = const WindowOptions(
        size: Size(800, 600),
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
      print('Error initializing window manager: $e');
    }
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => NPlayer(),
      child: AudioServiceWidget(
        child: const MyApp(),
      ),
    ),
  );
}

/// Root widget of the application
/// Handles theme management and provides the basic app structure
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
      home: Container(
        color: theme.scaffoldBackgroundColor,
        child: LoadingPage(
          child: const MainStructure(),
          theme: theme,
        ),
      ),
    );
  }
}

/// Main application structure widget
/// Manages the primary navigation and layout of the application
class MainStructure extends StatefulWidget {
  const MainStructure({super.key});

  @override
  _MainStructureState createState() => _MainStructureState();
}

/// State management for MainStructure
/// Handles:
/// - Page navigation
/// - Theme changes
/// - Layout adjustments
/// - Player positioning
class _MainStructureState extends State<MainStructure>
    with SingleTickerProviderStateMixin {
  bool _showWelcomePage = true;
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _animationController;
  final bool enableTesting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _showWelcomePage = !Settings.hasSeenWelcomePage;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _isLandscape(BuildContext context) {
    // Only trigger standby page on mobile devices in landscape
    return MediaQuery.of(context).orientation == Orientation.landscape &&
           (Platform.isAndroid || Platform.isIOS);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (mounted) {
      setState(() => _currentIndex = index);
    }
  }

  void _dismissWelcomePage() {
    setState(() {
      _showWelcomePage = false;
    });
  }

  List<Widget> _getPages() {
    List<Widget> pages = [
      SongLibrary(onThemeChanged: _onThemeChanged),
      const PlaylistPage(),
      const SongAlbums(),
      const ArtistsPage(),
    ];

    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      pages.add(const Downloader());
    }

    return pages;
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Song Library';
      case 1:
        return 'Playlists';
      case 2:
        return 'Albums';
      case 3:
        return 'Artists';
      case 4:
        return enableTesting ? 'Stream' : 'Downloader';
      case 5:
        return 'Downloader';
      default:
        return 'Blossom';
    }
  }

  /// Calculate proper bottom position for the player widget
  double _getPlayerBottomOffset() {
    if (_showWelcomePage) return 10;
    
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    if (isDesktop) {
      return 80; // Account for bottom nav bar height + margin
    } else {
      // Mobile: account for bottom nav bar + system UI
      return 80 + bottomPadding;
    }
  }

  /// Build the modern bottom navigation bar items
  List<_ModernNavItem> _getNavItems() {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    
    List<_ModernNavItem> items = [
      _ModernNavItem(
        icon: Icons.library_music_rounded,
        activeIcon: Icons.library_music,
        label: 'Library',
        index: 0,
      ),
      _ModernNavItem(
        icon: Icons.playlist_play_rounded,
        activeIcon: Icons.playlist_play,
        label: 'Playlists',
        index: 1,
      ),
      _ModernNavItem(
        icon: Icons.album_rounded,
        activeIcon: Icons.album,
        label: 'Albums',
        index: 2,
      ),
      _ModernNavItem(
        icon: Icons.person_rounded,
        activeIcon: Icons.person,
        label: 'Artists',
        index: 3,
      ),
    ];

    if (enableTesting) {
      items.add(_ModernNavItem(
        icon: Icons.wifi_rounded,
        activeIcon: Icons.wifi,
        label: 'Server',
        index: 4,
      ));
    }

    if (isDesktop) {
      items.add(_ModernNavItem(
        icon: Icons.download_rounded,
        activeIcon: Icons.download,
        label: 'Download',
        index: items.length,
      ));
    }

    return items;
  }

  /// Build the modern bottom navigation bar
  Widget _buildModernBottomNavBar() {
    if (_showWelcomePage) return const SizedBox.shrink();

    final navItems = _getNavItems();
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

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
              height: 50, // Fixed compact height
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(isDesktop ? 16 : 20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -2),
                  ),
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    blurRadius: 40,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: navItems.map((item) => 
                  _ModernNavButton(
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
                  ),
                ).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = _getPages();
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    
    if (_isLandscape(context)) {
      return const StandbyPage();
    }

    return Scaffold(
      appBar: !Platform.isIOS && !Platform.isAndroid
          ? CustomAppBar(
              titleWidget: Text(
                _getAppBarTitle(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              additionalActions: isDesktop ? [
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
              ] : null,
            )
          : null,
      extendBody: true,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: pages.length,
            itemBuilder: (context, index) {
              if (index == 0) {
                return SongLibrary(onThemeChanged: _onThemeChanged);
              }
              return pages[index];
            },
            onPageChanged: _onPageChanged,
            physics: const ClampingScrollPhysics(),
          ),
          if (_showWelcomePage)
            WelcomePage(
              onDismiss: _dismissWelcomePage,
            ),
          // Player widget positioned properly above bottom nav
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
          // Bottom navigation bar
          _buildModernBottomNavBar(),
          const SleepTimerCountdown(),
          // Add the iOS mount widget
          if (!Platform.isAndroid && !Platform.isIOS)
            const iOSMountWidget(),
        ],
      ),
    );
  }
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
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
          splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          highlightColor: Theme.of(context).colorScheme.primary.withOpacity(0.05),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: SizedBox(
                  height: 50, // Fixed height to prevent overflow
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(widget.isActive ? 8 : 6),
                      decoration: BoxDecoration(
                        color: widget.isActive
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.isActive ? widget.item.activeIcon : widget.item.icon,
                        size: widget.isDesktop ? 18 : 22,
                        color: widget.isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
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
