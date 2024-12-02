import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';

class FloatingBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavigationBarItem> items;

  const FloatingBottomNavigationBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width > 600;

    return Consumer<NPlayer>(
      builder: (context, player, child) {
        final currentSong = player.getCurrentSong();

        return Container(
          height: isDesktop ? 70 : 60,
          margin: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24 : 16,
            vertical: isDesktop ? 16 : 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isDesktop ? 35 : 30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isDesktop ? 35 : 30),
            child: Stack(
              children: [
                if (currentSong?.picture != null)
                  Positioned.fill(
                    child: Image.memory(
                      currentSong!.picture!,
                      fit: BoxFit.cover,
                    ),
                  ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                ),
                SizedBox(
                  height: isDesktop ? 70 : 60,
                  child: BottomNavigationBar(
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    unselectedItemColor: Colors.grey,
                    currentIndex: currentIndex,
                    onTap: onTap,
                    items: items,
                    type: BottomNavigationBarType.fixed,
                    selectedFontSize: 12,
                    unselectedFontSize: 12,
                    iconSize: 24,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
