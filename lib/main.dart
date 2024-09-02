import 'dart:io';

import 'package:blossom/custom/custom_appbar.dart';
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black.withOpacity(0.8),
        cardColor: Colors.grey.shade900.withOpacity(0.2),
        appBarTheme: AppBarTheme(color: Colors.black.withOpacity(0.8)),
        popupMenuTheme: PopupMenuThemeData(color: Colors.black.withOpacity(0.8)),
        splashColor: Colors.pink.shade300.withOpacity(0.5),
        colorScheme: const ColorScheme.dark(
          primary: Colors.pink,
          secondary: Colors.pinkAccent,
        ),
      ),
      home: LoadingPage(
        child: const MainStructure(),
      ),
    );
  }
}

class MainStructure extends StatefulWidget {
  const MainStructure({super.key});

  @override
  _MainStructureState createState() => _MainStructureState();
}

class _MainStructureState extends State<MainStructure> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;

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
    setState(() => _currentIndex = index);
  }

List<Widget> _getPages() {
  List<Widget> pages = [
    const SongLibrary(),
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
      return 'Downloader';
    default:
      return 'Blossom';
  }
}
  
 @override
  Widget build(BuildContext context) {
    final pages = _getPages();

    return Scaffold(
      appBar: !Platform.isIOS && !Platform.isAndroid
          ? CustomAppBar(
              titleWidget: Text(
                _getAppBarTitle(),
                style: const TextStyle(
                  fontFamily: 'Magic Retro',
                  fontSize: 28,
                  color: Color(0xFFF06292),
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          // Optimized PageView for better performance
          PageView.builder(
            controller: _pageController,
            itemCount: pages.length,
            itemBuilder: (context, index) => pages[index],
            onPageChanged: _onPageChanged,
            physics: const ClampingScrollPhysics(),
          ),
          // Floating NPlayerWidget
          const Positioned(
            left: 0,
            right: 0,
            bottom: 45,
            child: NPlayerWidget(),
          ),
        ],
      ),
    );
  }

}
