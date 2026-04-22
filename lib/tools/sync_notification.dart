import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:blossom/tools/nextcloud_sync.dart';


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SyncNotificationManager
//
// Manages a persistent Android notification that mirrors NextcloudSync
// progress in real-time. Compatible with flutter_local_notifications ^21.0.0.
//
// The notification:
//   • Shows an indeterminate bar while checking for changes.
//   • Shows a determinate byte-level progress bar while syncing, with the
//     current filename, file count, speed, and ETA.
//   • Is pinned (ongoing=true) — cannot be swiped away mid-sync.
//   • Uses Importance.low — completely silent, no heads-up, no vibration,
//     so it never interrupts music playback.
//   • Shows a brief success/error summary on completion, then auto-dismisses
//     after 4 seconds.
//   • Android-only — does nothing on other platforms.
//
// ── Setup ────────────────────────────────────────────────────────────────────
//
// 1. pubspec.yaml:
//      flutter_local_notifications: ^21.0.0
//
// 2. android/app/src/main/AndroidManifest.xml — inside <manifest>:
//      <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
//
//    And inside <application> (required for v16+ foreground service support):
//      <service
//          android:name="com.dexterous.flutterlocalnotifications.ForegroundService"
//          android:exported="false"
//          android:stopWithTask="true"
//          android:foregroundServiceType="dataSync"/>
//
// 3. Add a white-on-transparent notification icon as a drawable resource named
//    "ic_sync" (see Android docs / Image Asset Studio). Falls back to the
//    app launcher icon if omitted, but that looks wrong on Android.
//
// 4. Request notification permission on Android 13+ (call once, e.g. after
//    the first sync is triggered so there's clear context for the user):
//      await SyncNotificationManager.instance.requestPermissionIfNeeded();
//
// 5. In main():
//      await SyncNotificationManager.instance.initialize();
//
// 6. After NPlayer + NextcloudSync are ready:
//      SyncNotificationManager.instance.attachTo(NextcloudSync());
// ─────────────────────────────────────────────────────────────────────────────


class SyncNotificationManager {
  SyncNotificationManager._();
  static final SyncNotificationManager instance = SyncNotificationManager._();

  // Unique notification ID — hex spelling of "BLOSSOM".
  static const int    _notificationId = 0xB10550C;
  static const String _channelId      = 'nc_sync_progress';
  static const String _channelName    = 'Nextcloud Sync';
  static const String _channelDesc    = 'Shows progress while syncing music with Nextcloud';
  // Must match a drawable resource in android/app/src/main/res/drawable*/
  static const String _iconName       = 'ic_sync';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool            _initialized = false;
  NextcloudSync?  _sync;
  SyncStatus      _lastStatus  = SyncStatus.idle;


  // ── Public API ─────────────────────────────────────────────────────────────

  /// Initialises the plugin and creates the notification channel.
  /// Call once, before [attachTo], ideally in main() after
  /// WidgetsFlutterBinding.ensureInitialized().
  Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(_iconName);

await _plugin.initialize(
  settings: const InitializationSettings(android: androidSettings),
);
    await _createChannel();

    _initialized = true;
    _log('Initialized (flutter_local_notifications ^21)');
  }

  /// Requests the POST_NOTIFICATIONS permission on Android 13+.
  /// Safe to call on older versions — it's a no-op there.
  /// Call this at a point where the user has context for why you need it,
  /// e.g. just before the first sync begins.
  Future<bool> requestPermissionIfNeeded() async {
    if (!Platform.isAndroid) return true;

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl == null) return false;

    // requestNotificationsPermission() returns true if already granted or
    // just granted, false if denied. Returns null on pre-API-33 devices
    // (permission not required there), so we treat null as granted.
    final granted = await androidImpl.requestNotificationsPermission();
    _log('POST_NOTIFICATIONS permission: ${granted ?? true}');
    return granted ?? true;
  }

  /// Attaches the manager to a [NextcloudSync] instance.
  /// Removes the previous listener automatically if called again.
  void attachTo(NextcloudSync sync) {
    if (!Platform.isAndroid) return;
    _sync?.removeListener(_onSyncChanged);
    _sync = sync;
    sync.addListener(_onSyncChanged);
    _log('Attached to NextcloudSync');
  }

  /// Detaches listener and releases the reference.
  void dispose() {
    _sync?.removeListener(_onSyncChanged);
    _sync = null;
  }


  // ── ChangeNotifier Listener ────────────────────────────────────────────────

  void _onSyncChanged() {
    final sync = _sync;
    if (sync == null || !_initialized) return;

    final status   = sync.status;
    final progress = sync.progress;

    switch (status) {
      case SyncStatus.checking:
        _showChecking();

      case SyncStatus.syncing:
        progress != null ? _showProgress(progress) : _showChecking();

      case SyncStatus.success:
        if (_wasActive(_lastStatus)) {
          _showFinished(success: true, message: sync.statusMessage);
        }

      case SyncStatus.error:
        if (_wasActive(_lastStatus)) {
          _showFinished(success: false, message: sync.statusMessage);
        }

      case SyncStatus.idle:
        if (_wasActive(_lastStatus)) _cancel();
    }

    _lastStatus = status;
  }

  bool _wasActive(SyncStatus s) =>
      s == SyncStatus.syncing || s == SyncStatus.checking;


  // ── Notification Builders ──────────────────────────────────────────────────

  Future<void> _showChecking() async {
    await _plugin.show(
      id: _notificationId,
      title: 'Nextcloud Sync',
      body: 'Checking for changes…',
      notificationDetails: _details(
        progress:      0,
        maxProgress:   0,
        indeterminate: true,
        ongoing:       true,
        subText:       null,
        autoCancel:    false,
        showWhen:      false,
      ),
    );
  }

  Future<void> _showProgress(SyncProgress p) async {
    // Use 0–1000 for finer progress bar granularity than 0–100.
    final pct      = (p.bytesFraction * 1000).round().clamp(0, 1000);
    final fileName = p.currentFile.isNotEmpty ? p.currentFile : 'Syncing…';
    final body     = '$fileName  (${p.completed}/${p.total} files)';
    final subText  = '${p.speedLabel}  ·  ETA ${p.etaLabel}';

    await _plugin.show(
      id: _notificationId,
      title: 'Syncing with Nextcloud',
      body: body,
      notificationDetails: _details(
        progress:      pct,
        maxProgress:   1000,
        indeterminate: false,
        ongoing:       true,
        subText:       subText,
        autoCancel:    false,
        showWhen:      false,
      ),
    );
  }

  Future<void> _showFinished({
    required bool   success,
    required String message,
  }) async {
    await _plugin.show(
      id: _notificationId,
      title: success ? 'Sync complete ✓' : 'Sync error',
      body: message,
      notificationDetails: _details(
        progress:      success ? 1000 : 0,
        maxProgress:   1000,
        indeterminate: false,
        ongoing:       false,
        subText:       null,
        autoCancel:    true,
        showWhen:      true,
      ),
    );

    // Auto-dismiss after 4 seconds so the drawer doesn't clutter.
    Future.delayed(const Duration(seconds: 4), _cancel);
  }

  Future<void> _cancel() async {
    await _plugin.cancel(id: _notificationId);
  }


  // ── AndroidNotificationDetails Factory ────────────────────────────────────

  NotificationDetails _details({
    required int     progress,
    required int     maxProgress,
    required bool    indeterminate,
    required bool    ongoing,
    required String? subText,
    required bool    autoCancel,
    required bool    showWhen,
  }) {
    final android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,

      // ── Appearance ──────────────────────────────────────────────────────
      icon:            _iconName,
      importance:      Importance.low,   // silent — no heads-up interruption
      priority:        Priority.low,
      visibility:      NotificationVisibility.public,
      category:        AndroidNotificationCategory.progress,

      // ── Progress bar ────────────────────────────────────────────────────
      showProgress:  true,
      maxProgress:   maxProgress,
      progress:      progress,
      indeterminate: indeterminate,

      // ── Behaviour ───────────────────────────────────────────────────────
      ongoing:         ongoing,
      autoCancel:      autoCancel,
      onlyAlertOnce:   true,   // don't re-alert on every progress update
      showWhen:        showWhen,
      channelShowBadge: false,

      // ── Silence completely ──────────────────────────────────────────────
      playSound:        false,
      enableVibration:  false,
      enableLights:     false,
      sound:            null,

      // ── Speed + ETA line below the main body ───────────────────────────
      subText: subText,
    );

    return NotificationDetails(android: android);
  }


  // ── Channel Creation ───────────────────────────────────────────────────────

  Future<void> _createChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description:     _channelDesc,
      importance:      Importance.low,
      playSound:       false,
      enableVibration: false,
      showBadge:       false,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _log('Notification channel ready: $_channelId');
  }


  // ── Logging ────────────────────────────────────────────────────────────────

  void _log(String msg) {
    if (kDebugMode) print('[SyncNotification] $msg');
  }
}