import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';

class SleepTimerSheet extends StatefulWidget {
  const SleepTimerSheet({super.key});

  @override
  State<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<SleepTimerSheet> {
  final List<int> _presets = [1, 5, 15, 30, 45, 60, 90];
  late PageController _pageController;
  int _selectedIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.3,
      initialPage: _selectedIndex,
    );
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, player, child) {
        // Find the current timer index if set
        if (player.sleepTimerMinutes != null) {
          final index = _presets.indexOf(player.sleepTimerMinutes!);
          if (index != -1 && index != _selectedIndex) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              );
            });
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sheet handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 24),
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Timer carousel
                SizedBox(
                  height: 140,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _selectedIndex = index);
                    },
                    itemCount: _presets.length,
                    itemBuilder: (context, index) {
                      final minutes = _presets[index];
                      final isSelected = index == _selectedIndex;
                      
                      return InkWell(
                        highlightColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        onTap: () {
                          Navigator.pop(context);
                          final player = context.read<NPlayer>();
                          player.startSleepTimer(_presets[index]);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          margin: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: isSelected ? 16 : 32,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: isSelected ? 48 : 32,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected 
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.5),
                                ),
                                child: Text('$minutes'),
                              ),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: isSelected ? 16 : 14,
                                  color: isSelected 
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                                ),
                                child: const Text('min'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
