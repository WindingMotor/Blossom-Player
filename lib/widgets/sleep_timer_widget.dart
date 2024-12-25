import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import '../sheets/sleep_timer_sheet.dart';

class SleepTimerWidget extends StatelessWidget {
  const SleepTimerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, player, child) {
        if (player.sleepTimerMinutes == null) {
          return IconButton(
            icon: const Icon(Icons.bedtime_outlined),
            onPressed: () => _showSleepTimerSheet(context),
            tooltip: 'Set sleep timer',
          );
        }

        return GestureDetector(
          onTap: () => _showSleepTimerSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bedtime, size: 16),
                const SizedBox(width: 4),
                Text('${player.sleepTimerMinutes}m'),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => player.cancelSleepTimer(),
                  child: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSleepTimerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SleepTimerSheet(),
    );
  }
}
