import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import '../sheets/sleep_timer_sheet.dart';

class SleepTimerCountdown extends StatefulWidget {
  const SleepTimerCountdown({super.key});

  @override
  State<SleepTimerCountdown> createState() => _SleepTimerCountdownState();
}

class _SleepTimerCountdownState extends State<SleepTimerCountdown> with TickerProviderStateMixin {
  Offset position = const Offset(16, 70);
  late AnimationController _fadeController;
  late AnimationController _ringController;
  bool _isClosing = false;
  bool _isRinging = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _ringController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _ringController.reverse();
      } else if (status == AnimationStatus.dismissed && _isRinging) {
        _ringController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return "0:00";
    
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (minutes > 0) {
      return '$minutes:${twoDigits(seconds)}';
    }
    return '0:${twoDigits(seconds)}';
  }

  void _startCloseAnimation() async {
    // Start ringing animation
    setState(() => _isRinging = true);
    _ringController.forward();
    
    // Ring for 1 second (4 cycles)
    await Future.delayed(const Duration(seconds: 1));
    
    if (!mounted) return;
    
    // Stop ringing and start fade out
    setState(() {
      _isRinging = false;
      _isClosing = true;
    });
    _ringController.stop();
    
    // Wait for fade animation to complete
    await _fadeController.forward();
    
    if (!mounted) return;
    
    // Reset the sleep timer in NPlayer which will trigger widget removal
    Provider.of<NPlayer>(context, listen: false).cancelSleepTimer();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Consumer<NPlayer>(
      builder: (context, player, child) {
        if (player.sleepTimerMinutes == null && !_isClosing && !_isRinging) {
          return const SizedBox.shrink();
        }

        if (player.remainingTime?.inSeconds == 0 && !_isClosing && !_isRinging) {
          _startCloseAnimation();
        }

        return Positioned(
          left: position.dx,
          top: position.dy + topPadding,
          child: AnimatedBuilder(
            animation: _fadeController,
            builder: (context, child) {
              final scale = 1 - (_fadeController.value * 0.3);
              final opacity = 1 - _fadeController.value;
              
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  final newPosition = position + details.delta;
                  position = Offset(
                    newPosition.dx.clamp(0, screenSize.width - 160),
                    newPosition.dy.clamp(0, screenSize.height - topPadding - 60),
                  );
                });
              },
              child: _buildTimerWidget(context, player, colorScheme),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimerWidget(BuildContext context, NPlayer player, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const SleepTimerSheet(),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.surface.withOpacity(0.85),
          border: Border.all(
            color: colorScheme.primary.withOpacity(0.2),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicWidth(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.drag_indicator,
                size: 18,
                color: colorScheme.primary.withOpacity(0.7),
              ),
              const SizedBox(width: 4),
              if (_isRinging)
                AnimatedBuilder(
                  animation: _ringController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _ringController.value * 0.4 - 0.2,
                      child: Icon(
                        Icons.alarm_on,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    );
                  },
                )
              else
                Icon(
                  Icons.bedtime,
                  size: 18,
                  color: colorScheme.primary,
                ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(player.remainingTime),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => player.cancelSleepTimer(),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
