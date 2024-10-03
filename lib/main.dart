import 'dart:io';

import 'package:blossom/audio/nplayer_widget_desktop.dart';
import 'package:blossom/custom/custom_appbar.dart';
import 'package:blossom/pages/server_page.dart';
import 'package:blossom/tools/downloader.dart';
import 'package:blossom/pages/loading_page.dart';
import 'package:blossom/audio/nplaylist.dart';
import 'package:blossom/tools/settings.dart';
import 'package:blossom/pages/albums_page.dart';
import 'package:blossom/pages/artists_page.dart';
import 'package:blossom/pages/playlist_page.dart';
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
    Settings.init().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _getThemeData(Settings.appTheme),
        home: LoadingPage(
          child: const MainStructure(),
          theme: _getThemeData(Settings.appTheme),
        ));
  }

  ThemeData _getThemeData(String appTheme) {
    switch (appTheme) {
      case 'light':
        return ThemeData(
          brightness: Brightness.light,
          primarySwatch: Colors.pink,
          scaffoldBackgroundColor: Colors.grey[100],
          colorScheme: ColorScheme.light(
            primary: Colors.pink,
            secondary: Colors.pinkAccent,
            surface: Colors.white,
            onSurface: Colors.black87,
          ),
          cardColor: Colors.white,
          chipTheme: ChipThemeData(
            backgroundColor: Colors.grey[200],
            disabledColor: Colors.grey[300],
            selectedColor: Colors.pinkAccent,
            secondarySelectedColor: Colors.pinkAccent,
            labelStyle: TextStyle(color: Colors.black87),
            secondaryLabelStyle: TextStyle(color: Colors.black87),
            brightness: Brightness.light,
          ),
        );

      case 'dark':
        return ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.pink,
          scaffoldBackgroundColor: Colors.grey[900],
          colorScheme: ColorScheme.dark(
            primary: Colors.pink,
            secondary: Colors.pinkAccent,
            surface: Colors.grey[850]!,
            onSurface: Colors.white,
          ),
          cardColor: Colors.grey[850],
          chipTheme: ChipThemeData(
            backgroundColor: Colors.grey[800],
            disabledColor: Colors.grey[700],
            selectedColor: Colors.pinkAccent,
            secondarySelectedColor: Colors.pinkAccent,
            labelStyle: TextStyle(color: Colors.white),
            secondaryLabelStyle: TextStyle(color: Colors.white),
            brightness: Brightness.dark,
          ),
        );

      case 'slate':
        return ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.blueGrey[900],
          colorScheme: ColorScheme.dark(
            primary: Colors.blue[400]!,
            secondary: Colors.lightBlue[300]!,
            surface: Colors.blueGrey[800]!,
            onSurface: Colors.white,
          ),
          cardColor: Colors.blueGrey[800],
          chipTheme: ChipThemeData(
            backgroundColor: Colors.blueGrey[700],
            disabledColor: Colors.blueGrey[600],
            selectedColor: Colors.lightBlue[300],
            secondarySelectedColor: Colors.lightBlue[300],
            labelStyle: TextStyle(color: Colors.white),
            secondaryLabelStyle: TextStyle(color: Colors.white),
            brightness: Brightness.dark,
          ),
        );

      case 'algae':
        return ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.green,
          scaffoldBackgroundColor: Color(0xFF1E3B2F),
          colorScheme: ColorScheme.dark(
            primary: Color(0xFF4CAF50),
            secondary: Color(0xFF81C784),
            surface: Color(0xFF2E4B3E),
            onSurface: Colors.white,
          ),
          cardColor: Color(0xFF2E4B3E),
          chipTheme: ChipThemeData(
            backgroundColor: Color(0xFF3E5B4E),
            disabledColor: Color(0xFF324B42),
            selectedColor: Color(0xFF81C784),
            secondarySelectedColor: Color(0xFF81C784),
            labelStyle: TextStyle(color: Colors.white),
            secondaryLabelStyle: TextStyle(color: Colors.white),
            brightness: Brightness.dark,
          ),
        );

      case 'rose':
        return ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.red,
          scaffoldBackgroundColor: Color(0xFF3B1E1E),
          colorScheme: ColorScheme.dark(
            primary: Color(0xFFE57373),
            secondary: Color(0xFFFFCDD2),
            surface: Color(0xFF4B2E2E),
            onSurface: Colors.white,
          ),
          cardColor: Color(0xFF4B2E2E),
          chipTheme: ChipThemeData(
            backgroundColor: Color(0xFF5B3E3E),
            disabledColor: Color(0xFF4B3232),
            selectedColor: Color(0xFFFFCDD2),
            secondarySelectedColor: Color(0xFFFFCDD2),
            labelStyle: TextStyle(color: Colors.white),
            secondaryLabelStyle: TextStyle(color: Colors.white),
            brightness: Brightness.dark,
          ),
        );
      case 'oled':
        return ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.grey,
          scaffoldBackgroundColor: Colors.black,
          colorScheme: ColorScheme.dark(
            primary: Colors.white,
            secondary: Colors.grey[800]!,
            surface: Colors.black,
            onSurface: Colors.white,
          ),
          cardColor: Colors.black,
          chipTheme: ChipThemeData(
            backgroundColor: Colors.grey[900]!,
            disabledColor: Colors.grey[800]!,
            selectedColor: Colors.white,
            secondarySelectedColor: Colors.white,
            labelStyle: TextStyle(color: Colors.white),
            secondaryLabelStyle: TextStyle(color: Colors.white),
            brightness: Brightness.dark,
          ),
        );
      case 'sunset':
        return ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.orange,
          scaffoldBackgroundColor: Color(0xFF2C1E30),
          colorScheme: ColorScheme.dark(
            primary: Color(0xFFFF9800),
            secondary: Color(0xFFFFAB40),
            surface: Color(0xFF3C2E40),
            onSurface: Colors.white,
          ),
          cardColor: Color(0xFF3C2E40),
          chipTheme: ChipThemeData(
            backgroundColor: Color(0xFF4C3E50),
            disabledColor: Color(0xFF3C2E40),
            selectedColor: Color(0xFFFFAB40),
            secondarySelectedColor: Color(0xFFFFAB40),
            labelStyle: TextStyle(color: Colors.white),
            secondaryLabelStyle: TextStyle(color: Colors.white),
            brightness: Brightness.dark,
          ),
        );

      case 'ocean':
        return ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Color(0xFF0A192F),
          colorScheme: ColorScheme.dark(
            primary: Color(0xFF64FFDA),
            secondary: Color(0xFF48D1CC),
            surface: Color(0xFF172A45),
            onSurface: Colors.white,
          ),
          cardColor: Color(0xFF172A45),
          chipTheme: ChipThemeData(
            backgroundColor: Color(0xFF1D3A5C),
            disabledColor: Color(0xFF13253A),
            selectedColor: Color(0xFF64FFDA),
            secondarySelectedColor: Color(0xFF64FFDA),
            labelStyle: TextStyle(color: Colors.white),
            secondaryLabelStyle: TextStyle(color: Colors.white),
            brightness: Brightness.dark,
          ),
        );
      case 'forest':
        return ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.green,
          scaffoldBackgroundColor: Color(0xFF2C1E0F),
          colorScheme: ColorScheme.dark(
            primary: Color(0xFF4CAF50),
            secondary: Color(0xFFA5D6A7),
            surface: Color(0xFF3C2A1A),
            onSurface: Colors.white,
          ),
          cardColor: Color(0xFF3C2A1A),
          chipTheme: ChipThemeData(
            backgroundColor: Color(0xFF4C3A2A),
            disabledColor: Color(0xFF3C2A1A),
            selectedColor: Color(0xFFA5D6A7),
            secondarySelectedColor: Color(0xFFA5D6A7),
            labelStyle: TextStyle(color: Colors.white),
            secondaryLabelStyle: TextStyle(color: Colors.white),
            brightness: Brightness.dark,
          ),
        );
      case 'pink':
        return ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.pink,
          scaffoldBackgroundColor: Color(0xFF1A0F13),
          colorScheme: ColorScheme.dark(
            primary: Color(0xFFFF69B4),
            secondary: Color(0xFFFF1493),
            surface: Color(0xFF2C1A24),
            onSurface: Colors.white,
          ),
          cardColor: Color(0xFF3D2433),
          chipTheme: ChipThemeData(
            backgroundColor: Color(0xFF4D2D3F),
            disabledColor: Color(0xFF3D2433),
            selectedColor: Color(0xFFFF1493),
            secondarySelectedColor: Color(0xFFFF1493),
            labelStyle: TextStyle(color: Colors.white),
            secondaryLabelStyle: TextStyle(color: Colors.white),
            brightness: Brightness.dark,
          ),
        );

      case 'lavender':
        return ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.purple,
          scaffoldBackgroundColor: Color(0xFF1A1A2E),
          colorScheme: ColorScheme.dark(
            primary: Color(0xFF9370DB),
            secondary: Color(0xFF8A2BE2),
            surface: Color(0xFF2C2C45),
            onSurface: Colors.white,
          ),
          cardColor: Color(0xFF3D3D5C),
          chipTheme: ChipThemeData(
            backgroundColor: Color(0xFF4D4D6D),
            disabledColor: Color(0xFF3D3D5C),
            selectedColor: Color(0xFF8A2BE2),
            secondarySelectedColor: Color(0xFF8A2BE2),
            labelStyle: TextStyle(color: Colors.white),
            secondaryLabelStyle: TextStyle(color: Colors.white),
            brightness: Brightness.dark,
          ),
        );

      case 'orange':
        return ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.orange,
          scaffoldBackgroundColor: Color(0xFF1A130F),
          colorScheme: ColorScheme.dark(
            primary: Color(0xFFFF8C00),
            secondary: Color(0xFFFF4500),
            surface: Color(0xFF2C2118),
            onSurface: Colors.white,
          ),
          cardColor: Color(0xFF3D2E21),
          chipTheme: ChipThemeData(
            backgroundColor: Color(0xFF4D3B2A),
            disabledColor: Color(0xFF3D2E21),
            selectedColor: Color(0xFFFF4500),
            secondarySelectedColor: Color(0xFFFF4500),
            labelStyle: TextStyle(color: Colors.white),
            secondaryLabelStyle: TextStyle(color: Colors.white),
            brightness: Brightness.dark,
          ),
        );

      default:
        // 'dark' theme
        return ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.pink,
          scaffoldBackgroundColor: Colors.grey[900],
          colorScheme: ColorScheme.dark(
            primary: Colors.pink,
            secondary: Colors.pinkAccent,
            surface: Colors.grey[850]!,
            onSurface: Colors.white,
          ),
          cardColor: Colors.grey[850],
          chipTheme: ChipThemeData(
            backgroundColor: Colors.grey[800],
            disabledColor: Colors.grey[700],
            selectedColor: Colors.pinkAccent,
            secondarySelectedColor: Colors.pinkAccent,
            labelStyle: TextStyle(color: Colors.white),
            secondaryLabelStyle: TextStyle(color: Colors.white),
            brightness: Brightness.dark,
          ),
        );
    }
  }
}

class MainStructure extends StatefulWidget {
  const MainStructure({super.key});

  @override
  _MainStructureState createState() => _MainStructureState();
}

class _MainStructureState extends State<MainStructure>
    with SingleTickerProviderStateMixin {
  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  int _currentIndex = 0;
  late PageController _pageController;
  final bool enableTesting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
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

  List<Widget> _getPages() {
    List<Widget> pages = [
      SongLibrary(onThemeChanged: _onThemeChanged),
      const PlaylistPage(),
      const SongAlbums(),
      const ArtistsPage(),
    ];

    if (enableTesting) {
      pages.add(const ServerPage());
    }

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
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

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
          Positioned(
            left: 0,
            right: 0,
            bottom: _getPlayerBottomPosition(),
            child: isDesktop
                ? const NPlayerWidgetDesktop()
                : const NPlayerWidget(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
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
