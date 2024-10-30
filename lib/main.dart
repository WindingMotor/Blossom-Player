import 'dart:io';

import 'package:blossom/audio/nplayer_widget_desktop.dart';
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
import 'audio/nplayer_widget.dart';
import 'pages/library_page.dart';

Future<void> requestPermissions() async {
  if (Platform.isAndroid) {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();

    if (statuses[Permission.storage] != PermissionStatus.granted ||
        statuses[Permission.manageExternalStorage] !=
            PermissionStatus.granted) {
      print('Storage permission not granted');
    }
  } else if (Platform.isIOS) {
    PermissionStatus status = await Permission.photos.request();
    if (status != PermissionStatus.granted) {
      print('Photos permission not granted');
    } else {
      print('Photos permission granted!');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MetadataGod.initialize();
  await Settings.init();
  await PlaylistManager.load();

  await requestPermissions();

  final songDir = Settings.getSongDir();
  print("SONG SETTINGS DIRECTORY: $songDir");

  final applicationsDir = await getApplicationDocumentsDirectory();
  print("APPLICATIONS DIRECTORY: $applicationsDir");

  final hasStorageAccess =
      Platform.isAndroid ? await Permission.storage.isGranted : true;
  if (!hasStorageAccess) {
    await Permission.storage.request();
    if (!await Permission.storage.isGranted) {
      return;
    }
  }

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => NPlayer(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: getThemeData(Settings.appTheme),
        home: LoadingPage(
          child: const MainStructure(),
          theme: getThemeData(Settings.appTheme),
        ));
  }

}

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
  final bool enableTesting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _showWelcomePage = !Settings.hasSeenWelcomePage;
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape &&
           (Platform.isAndroid || Platform.isIOS);
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  double _getPlayerBottomPosition() {
    if (Platform.isAndroid || Platform.isIOS) {
      return 10;
    } else {
      return 0;
    }
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
                  fontFamily: 'Magic Retro',
                  fontSize: 25,
                ),
              ),
            )
          : null,
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
          Positioned(
            left: 0,
            right: 0,
            bottom: _getPlayerBottomPosition(),
            child: _isLandscape(context)
                ? const SizedBox.shrink()
                : isDesktop
                    ? const NPlayerWidgetDesktop()
                    : const NPlayerWidget(),
          ),
        ],
      ),
      bottomNavigationBar: _showWelcomePage ? null : BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (mounted) {
            setState(() => _currentIndex = index);
            _pageController.jumpToPage(index);
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.library_music),
            label: 'Library',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.playlist_play),
            label: 'Playlists',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.album),
            label: 'Albums',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Artists',
          ),
          if (enableTesting)
            const BottomNavigationBarItem(
              icon: Icon(Icons.wifi),
              label: 'Server Scan',
            ),
          if (isDesktop)
            const BottomNavigationBarItem(
              icon: Icon(Icons.download),
              label: 'Downloader',
            ),
        ],
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        selectedItemColor: Theme.of(context).colorScheme.secondary,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}