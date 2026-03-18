/// Blossom Music Player - A modern cross-platform music player built with Flutter
/// This is the main entry point of the application.

import 'dart:async'; // Added for runZonedGuarded
import 'dart:io';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:blossom/audio/nplayer_extensions/nplayer_widget_desktop.dart';
import 'package:blossom/custom/custom_appbar.dart';
import 'package:blossom/pages/social_page.dart';
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
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'audio/nplayer.dart';
import 'audio/widgets/nplayer_widget.dart';
import 'pages/library_page.dart';
import 'widgets/sleep_timer_countdown.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

/// Requests necessary permissions for file access safely
Future<void> requestPermissions() async {
  if (Platform.isAndroid) {
    try {
      // Get device info to check Android version
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      final int sdkVersion = androidInfo.version.sdkInt;
      
      if (sdkVersion >= 33) { // Android 13+
        // Request granular media permissions for Android 13+
        // Check if already granted first to avoid unnecessary requests
        if (!await Permission.audio.isGranted) {
             await Permission.audio.request();
        }
      } else {
        // For Android 12 and below, use storage permission
        if (!await Permission.storage.isGranted) {
            await Permission.storage.request();
        }
      }
    } catch (e) {
      print('Error requesting Android permissions: $e');
    }
  } else if (Platform.isIOS) {
    try {
      await Permission.photos.request();
      await Permission.mediaLibrary.request();
    } catch (e) {
      print('Error requesting iOS permissions: $e');
    }
  }
}

/// Application entry point
/// Initializes essential services and launches the app
void main() {
  // PROTECTIVE LAYER: Catch any error during startup to prevent crash-on-launch
  runZonedGuarded(() async {
    // Ensure Flutter bindings are initialized first
    WidgetsFlutterBinding.ensureInitialized();

    try {
      // Initialize FFI for sqflite on desktop platforms (Linux/Windows)
      if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
      
      // Initialize metadata handling service safely
      try {
        MetadataGod.initialize();
      } catch (e) {
        print("MetadataGod init error (safe to ignore): $e");
      }
      
      // Initialize app settings
      await Settings.init();

      // Load friends list and initialize username
      await Settings.loadFriendsList();
      await Settings.initializeUsername();

      // Load playlists
      try {
        await PlaylistManager.load();
      } catch (e) {
        print("Playlist load error: $e");
      }

      // Desktop window configuration (Wrapped in try-catch specifically)
      if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        try {
          await windowManager.ensureInitialized();
          
          // FIX: Use slightly larger default size for Linux to help with scaling issues
          // If the OS scaling is 200%, 800 logical pixels might be rendered as 400 physical if not handled right.
          // Setting a generous default size helps ensure it's usable even if scaling is weird.
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
          print('Error initializing window manager (safe to ignore on mobile): $e');
        }
      }

      // Request permissions safely after UI is ready
      // We don't await this so the app launches immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        requestPermissions();
      });

    } catch (e, stack) {
      print("CRITICAL INITIALIZATION ERROR: $e");
      print(stack);
      // Even if init fails, we proceed to runApp so the user sees *something*
    }

    runApp(
      ChangeNotifierProvider(
        create: (context) => NPlayer(),
        child: AudioServiceWidget(
          child: const MyApp(),
        ),
      ),
    );
  }, (error, stack) {
    // GLOBAL ERROR CATCHER
    // This prevents the app from "Force Closing" on unhandled errors
    print("GLOBAL UNCAUGHT ERROR: $error");
    print(stack);
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
    // Use a safe fallback theme if Settings.appTheme isn't ready
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
  final bool enableTesting = false;

  @override
  void initState() {
    super.initState();

    // Safely set refresh rate
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        FlutterDisplayMode.setHighRefreshRate();
      } 
    } catch (e) {
      print("Display mode error: $e");
    }
    
    _pageController = PageController(initialPage: _currentIndex);
    
    // Safe access to Settings
    try {
      _showWelcomePage = !Settings.hasSeenWelcomePage;
    } catch (e) {
      _showWelcomePage = true; // Default to true on error
    }

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
    try {
      return MediaQuery.of(context).orientation == Orientation.landscape &&
             (Platform.isAndroid || Platform.isIOS);
    } catch (e) {
      return false;
    }
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
    // Save settings safely
    try {
        Settings.setHasSeenWelcomePage(true);
    } catch(e) {
        print("Error saving welcome page state: $e");
    }
  }

  List<Widget> _getPages() {
    final pages = <Widget>[
      SongLibrary(onThemeChanged: _onThemeChanged),
      const PlaylistPage(),
      const SongAlbums(),
      const ArtistsPage(),
    ];

    if (Settings.isPublicSharingEnabled) {
      pages.add(const SocialPage());
    }

    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      pages.add(const Downloader());
    }

    return pages;
  }

  String _getAppBarTitle() {
    // Base pages: 0–3
    switch (_currentIndex) {
      case 0:
        return 'Song Library';
      case 1:
        return 'Playlists';
      case 2:
        return 'Albums';
      case 3:
        return 'Artists';
    }

    int idx = 4;

    // Social (only if enabled)
    if (Settings.isPublicSharingEnabled) {
      if (_currentIndex == idx) return 'Social';
      idx++;
    }

    // enableTesting: Server
    if (enableTesting) {
      if (_currentIndex == idx) return 'Stream';
      idx++;
    }

    // Desktop downloader
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    if (isDesktop && _currentIndex == idx) {
      return 'Downloader';
    }

    return 'Blossom';
  }

  double _getPlayerBottomOffset() {
    if (_showWelcomePage) return 10;
    
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    if (isDesktop) {
      return 80; 
    } else {
      return 80 + bottomPadding;
    }
  }

  List<_ModernNavItem> _getNavItems() {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    final items = <_ModernNavItem>[
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

    if (Settings.isPublicSharingEnabled) {
      items.add(
        _ModernNavItem(
          icon: Icons.people_outline_rounded,
          activeIcon: Icons.people_rounded,
          label: 'Social',
          index: items.length, 
        ),
      );
    }

    if (enableTesting) {
      items.add(
        _ModernNavItem(
          icon: Icons.wifi_rounded,
          activeIcon: Icons.wifi,
          label: 'Server',
          index: items.length,
        ),
      );
    }

    if (isDesktop) {
      items.add(
        _ModernNavItem(
          icon: Icons.download_rounded,
          activeIcon: Icons.download,
          label: 'Download',
          index: items.length,
        ),
      );
    }

    return items;
  }

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
              height: 50, 
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

    if (_currentIndex >= pages.length) {
      _currentIndex = 0;
      _pageController.jumpToPage(0);
    }

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
              // Safely handle index out of bounds
              if (index >= pages.length) return const SizedBox.shrink();
              
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
          // Player widget
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
                  height: 50, 
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
