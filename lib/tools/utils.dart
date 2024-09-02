import 'package:intl/intl.dart';

class Utils {
  static String formatDuration(int durationInSeconds) {
    Duration duration = Duration(seconds: durationInSeconds);
    String twoDigitMinutes =
        (duration.inMinutes % 60).toString().padLeft(2, '0');
    String twoDigitSeconds =
        (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  static String formatMilliseconds(int milliseconds) {
    final formatter = NumberFormat('00');
    final duration = Duration(milliseconds: milliseconds);
    return '${formatter.format(duration.inMinutes)}:${formatter.format(duration.inSeconds % 60)}';
  }
}
