import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart';
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
      print('Error signing in: $error');
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
    final driveApi = await getDriveApi();
    if (driveApi == null) return [];

    try {
      final fileList = await driveApi.files.list(
        q: "mimeType contains 'audio/'",
        spaces: 'drive',
        $fields: 'files(id, name, mimeType, size)',
      );

      return fileList.files ?? [];
    } catch (e) {
      print('Error listing audio files: $e');
      return [];
    }
  }

  static Future<bool> downloadFile(drive.File file) async {
    final driveApi = await getDriveApi();
    if (driveApi == null) return false;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${appDir.path}/Blossom/Music');
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      final savePath = '${musicDir.path}/${file.name}';
      final saveFile = File(savePath);
      
      final response = await driveApi.files.get(
        file.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> dataStore = [];
      await response.stream.forEach((data) {
        dataStore.insertAll(dataStore.length, data);
      });

      await saveFile.writeAsBytes(dataStore);
      return true;
    } catch (e) {
      print('Error downloading file: $e');
      return false;
    }
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
}
