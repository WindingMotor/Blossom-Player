import 'package:flutter/material.dart';
import 'package:blossom/pages/settings_page.dart';
import 'package:provider/provider.dart';
import 'package:blossom/audio/nplayer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<NPlayer>(context);
    final albumArt =
        player.allSongs.where((song) => song.picture != null).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Scrolling album art background
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                    -_controller.value * MediaQuery.of(context).size.width, 0),
                child: child,
              );
            },
            child: Row(
              children: [
                for (int i = 0; i < 2; i++)
                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1,
                      ),
                      itemCount: albumArt.length,
                      itemBuilder: (context, index) {
                        return Image.memory(
                          albumArt[index].picture!,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          // Overlay to make content more readable
          Container(
            color: Colors.black.withOpacity(0.6),
          ),
          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Blossom',
                  style: TextStyle(
                    fontFamily: 'Magic Retro',
                    fontSize: 38,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatInkwell(
                        context, 'Songs', player.allSongs.length.toString()),
                    _buildStatInkwell(
                        context,
                        'Albums',
                        player.allSongs
                            .map((s) => s.album)
                            .toSet()
                            .length
                            .toString()),
                    _buildStatInkwell(
                        context,
                        'Artists',
                        player.allSongs
                            .map((s) => s.artist)
                            .toSet()
                            .length
                            .toString()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatInkwell(BuildContext context, String label, String value) {
    return InkWell(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
