import 'package:flutter/foundation.dart';

/// Log levels from least to most severe.
enum LogLevel { verbose, debug, info, warning, error }

/// Component tags for filtering output in the console.
enum LogTag {
  playback,
  audioHandler,
  songLoading,
  songCache,
  playlist,
  settings,
  nextcloud,
  syncNotification,
  server,
  social,
  ui,
}

/// Central logger for Blossom Player.
///
/// Release builds: only [LogLevel.warning] and [LogLevel.error] are emitted,
/// regardless of [enabled] or [minLevel] — no cost from debug chatter.
///
/// Debug builds: controlled by [enabled] and [minLevel].
/// Default level is [LogLevel.info] so verbose/debug noise is off unless
/// you explicitly lower the level via [setMinLevel].
///
/// Settings calls [setEnabled] at startup to honour the user's debug toggle.
///
/// Output format:
///   I/PLAYBACK     Playing album: Dark Side of the Moon
///   W/AUDIO        Could not gain audio focus after 3 attempts
///   E/CACHE        Error initializing
///     ↳ FileSystemException: Cannot open file, path = '...'
class Log {
  static bool enabled = kDebugMode;
  static LogLevel minLevel = LogLevel.info;

  static void setEnabled(bool value) => enabled = value;
  static void setMinLevel(LogLevel level) => minLevel = level;

  static void v(LogTag tag, String message) =>
      _emit(LogLevel.verbose, tag, message);
  static void d(LogTag tag, String message) =>
      _emit(LogLevel.debug, tag, message);
  static void i(LogTag tag, String message) =>
      _emit(LogLevel.info, tag, message);
  static void w(LogTag tag, String message) =>
      _emit(LogLevel.warning, tag, message);
  static void e(LogTag tag, String message, [Object? error]) =>
      _emit(LogLevel.error, tag, message, error);

  static void _emit(LogLevel level, LogTag tag, String message,
      [Object? error]) {
    // Hard gate: nothing below warning leaves a release build.
    if (!kDebugMode && level.index < LogLevel.warning.index) return;
    if (!enabled) return;
    if (level.index < minLevel.index) return;

    final out = StringBuffer('${_levelChar(level)}/${_tagStr(tag)}$message');
    if (error != null) out.write('\n  ↳ $error');
    debugPrint(out.toString());
  }

  static String _levelChar(LogLevel l) => switch (l) {
        LogLevel.verbose => 'V',
        LogLevel.debug => 'D',
        LogLevel.info => 'I',
        LogLevel.warning => 'W',
        LogLevel.error => 'E',
      };

  static String _tagStr(LogTag tag) => switch (tag) {
        LogTag.playback => 'PLAYBACK     ',
        LogTag.audioHandler => 'AUDIO        ',
        LogTag.songLoading => 'LOADER       ',
        LogTag.songCache => 'CACHE        ',
        LogTag.playlist => 'PLAYLIST     ',
        LogTag.settings => 'SETTINGS     ',
        LogTag.nextcloud => 'NEXTCLOUD    ',
        LogTag.syncNotification => 'SYNC         ',
        LogTag.server => 'SERVER       ',
        LogTag.social => 'SOCIAL       ',
        LogTag.ui => 'UI           ',
      };
}
