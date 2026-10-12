import 'package:blossom/tools/logger.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.readonly',
    ],
  );

  static GoogleSignInAccount? _currentUser;
  static GoogleSignInAccount? get currentUser => _currentUser;

  static Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        _currentUser = account;
        return true;
      }
      return false;
    } catch (error) {
      Log.e(LogTag.ui, 'Error signing in: $error');
      return false;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  static Future<drive.DriveApi?> getDriveApi() async {
    if (_currentUser == null) return null;

    final headers = await _currentUser!.authHeaders;
    final client = GoogleAuthClient(headers);
    return drive.DriveApi(client);
  }

  static Future<List<drive.File>> listAudioFiles() async {
    final session = await _createDriveSession();
    if (session == null) return [];

    try {
      final files = <drive.File>[];
      String? pageToken;
      do {
        final fileList = await session.api.files.list(
          q: "mimeType contains 'audio/' and trashed = false",
          spaces: 'drive',
          pageToken: pageToken,
          pageSize: 1000,
          $fields: 'nextPageToken, files(id, name, mimeType, size)',
        );
        files.addAll(fileList.files ?? const []);
        pageToken = fileList.nextPageToken;
      } while (pageToken != null && pageToken.isNotEmpty);
      return files;
    } catch (e) {
      Log.e(LogTag.ui, 'Error listing audio files: $e');
      return [];
    } finally {
      session.client.close();
    }
  }

  static Future<bool> downloadFile(drive.File file) async {
    final session = await _createDriveSession();
    if (session == null) return false;

    File? partialFile;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${appDir.path}/Blossom/Music');
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      final safeName = _safeFileName(file.name);
      if (safeName.isEmpty) {
        throw const FormatException('Invalid Drive filename');
      }
      final saveFile = await _availableFile(musicDir, safeName);
      partialFile = File('${saveFile.path}.blossom-part-'
          '${DateTime.now().microsecondsSinceEpoch}');

      final response = await session.api.files.get(
        file.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final sink = partialFile.openWrite();
      try {
        await sink.addStream(response.stream);
      } finally {
        await sink.close();
      }
      final written = await partialFile.length();
      final expected = int.tryParse(file.size ?? '');
      if (written <= 0 || (expected != null && expected != written)) {
        throw FileSystemException(
            'Incomplete Drive download (expected $expected, got $written)');
      }
      await partialFile.rename(saveFile.path);
      partialFile = null;
      return true;
    } catch (e) {
      Log.e(LogTag.ui, 'Error downloading file: $e');
      return false;
    } finally {
      session.client.close();
      if (partialFile != null && await partialFile.exists()) {
        try {
          await partialFile.delete();
        } catch (_) {}
      }
    }
  }

  static Future<({GoogleAuthClient client, drive.DriveApi api})?>
      _createDriveSession() async {
    if (_currentUser == null) return null;
    final client = GoogleAuthClient(await _currentUser!.authHeaders);
    return (client: client, api: drive.DriveApi(client));
  }

  static String _safeFileName(String? name) {
    if (name == null) return '';
    return name
        .replaceAll(RegExp(r'[\\/]'), '_')
        .replaceAll(RegExp(r'[\x00-\x1f]'), '')
        .replaceAll(RegExp(r'^\.+$'), '')
        .trim();
  }

  static Future<File> _availableFile(Directory dir, String name) async {
    var candidate = File('${dir.path}/$name');
    if (!await candidate.exists()) return candidate;
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final extension = dot > 0 ? name.substring(dot) : '';
    for (var suffix = 1; suffix < 10000; suffix++) {
      candidate = File('${dir.path}/$stem ($suffix)$extension');
      if (!await candidate.exists()) return candidate;
    }
    throw const FileSystemException('Too many files with the same name');
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() => _client.close();
}
