import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/shell.dart';

class iOS_Binder {
  static const String _mountDir = "~/Music/BlossomMount";
  static const String _blossomId = "com.wmstudios.blossom";

 static Future<bool>? _initialCheckFuture;

  static Future<bool> getInitialCheck() {
    _initialCheckFuture ??= _performInitialCheck();
    return _initialCheckFuture!;
  }

  static Future<bool> _performInitialCheck() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return true; // Skip check on mobile platforms
    }
    
    final binder = iOS_Binder();
    String platform;
    
    if (Platform.isLinux) {
      platform = 'linux';
    } else if (Platform.isMacOS) {
      platform = 'macos';
    } else if (Platform.isWindows) {
      platform = 'windows';
    } else {
      return false;
    }

    return await binder.checkForIDevice(platform: platform);
  }

  Future<String> _getScriptPath() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final scriptDir = Directory('${appDocDir.path}/blossom_venv/scripts');
    
    if (!await scriptDir.exists()) {
      print('Creating scripts directory: ${scriptDir.path}');
      await scriptDir.create(recursive: true);
    }
    
    String scriptName;
    if (Platform.isLinux) {
      scriptName = 'bmount_linux.sh';
    } else if (Platform.isMacOS) {
      scriptName = 'bmount_macos.sh';
    } else if (Platform.isWindows) {
      scriptName = 'bmount_windows.sh';
    } else {
      throw UnsupportedError('Platform ${Platform.operatingSystem} is not supported');
    }

    return '${scriptDir.path}/$scriptName';
  }

    Future<bool> checkForIDevice({required String platform}) async {
    print('Checking for iOS device on $platform');
    try {
      final scriptPath = await _getScriptPath();
      print('Using mount script: $scriptPath');

      if (!File(scriptPath).existsSync()) {
        print('Error: Mount script not found at $scriptPath');
        return false;
      }

      // Make script executable on Unix systems
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', scriptPath]);
        print('Made script executable');
      }

      // Run the appropriate script
      final shell = Shell(throwOnError: false);
      final results = await shell.run(scriptPath);
      
      print('Script output: ${results.first.stdout}');
      print('Script errors: ${results.first.stderr}');

      // Check if mount was successful
      final mountDir = _mountDir.replaceFirst('~', Platform.environment['HOME']!);
      final mounted = await Directory(mountDir).exists();
      
      print(mounted ? 'Device mounted successfully' : 'Device mount failed');
      return mounted;

    } catch (e) {
      print('Error during device mount: $e');
      return false;
    }
  }

  Future<Map<String, int>> getSpaceInfo() async {
    print('Getting space information');
    final mountDir = _mountDir.replaceFirst('~', Platform.environment['HOME']!);
    try {
      final result = await Process.run('df', ['-k', mountDir]);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        if (lines.length >= 2) {
          final values = lines[1].split(RegExp(r'\s+'));
          final space = {
            'total': int.parse(values[1]) ~/ (1024 * 1024),
            'available': int.parse(values[3]) ~/ (1024 * 1024),
          };
          print('Space info: $space');
          return space;
        }
      }
    } catch (e) {
      print('Error getting space info: $e');
    }
    return {'total': 0, 'available': 0};
  }

  Future<bool> checkMountStatus() async {
    final mountDir = _mountDir.replaceFirst('~', Platform.environment['HOME']!);
    try {
      final directory = Directory(mountDir);
      final exists = await directory.exists();
      print('Mount status: ${exists ? "mounted" : "not mounted"}');
      return exists;
    } catch (e) {
      print('Error checking mount status: $e');
      return false;
    }
  }
}
