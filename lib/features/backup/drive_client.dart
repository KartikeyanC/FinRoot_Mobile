import 'dart:convert';

import 'package:http/http.dart' as http;

/// Only files this app creates — not the rest of the person's Drive.
const driveFileScope = 'https://www.googleapis.com/auth/drive.file';

const backupFolderName = 'FinRoot Backups';

class DriveFile {
  const DriveFile({required this.id, required this.name, required this.modified, this.size});
  final String id;
  final String name;
  final DateTime modified;
  final int? size;
}

/// Drive's refusal, in words that say what to do. The commonest setup gap,
/// the Drive API left switched off in the Cloud project, comes back as a 403
/// whose message names the project; say how to switch it on.
String driveErrorMessage(int status, String body) {
  String? google;
  try {
    final e = (jsonDecode(body) as Map)['error'];
    if (e is Map && e['message'] is String) google = e['message'] as String;
  } on Object {
    // not JSON: keep the status
  }
  final l = (google ?? '').toLowerCase();
  if (status == 403 &&
      (l.contains('has not been used') || l.contains('is disabled') || l.contains('accessnotconfigured'))) {
    return 'The Google Drive API is switched off for FinRoot. In Google Cloud, open '
        'APIs & Services → Library → Google Drive API → Enable, wait a few minutes, '
        'then try again.';
  }
  if (status == 401) return 'Google sign-in expired. Try again.';
  return google == null ? 'Google Drive said $status.' : 'Google Drive: $google';
}

class DriveException implements Exception {
  const DriveException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// The few Drive v3 REST calls a backup needs, with a bearer token from
/// Google sign-in. Plain HTTP so it can be tested with a fake client.
class DriveClient {
  DriveClient(this._token, {http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final String _token;
  final http.Client _http;

  static const _api = 'https://www.googleapis.com/drive/v3/files';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3/files';

  Map<String, String> get _auth => {'Authorization': 'Bearer $_token'};

  Future<Map<String, dynamic>> _json(http.Response r) async {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return r.body.isEmpty ? const {} : jsonDecode(r.body) as Map<String, dynamic>;
    }
    throw DriveException(driveErrorMessage(r.statusCode, r.body), status: r.statusCode);
  }

  /// The "FinRoot Backups" folder, created on first use.
  Future<String> ensureFolder() async {
    const q = "name = '$backupFolderName' and mimeType = 'application/vnd.google-apps.folder' "
        'and trashed = false';
    final found = await _json(await _http.get(
      Uri.parse(_api).replace(queryParameters: {'q': q, 'fields': 'files(id)', 'spaces': 'drive'}),
      headers: _auth,
    ));
    final files = found['files'] as List<dynamic>? ?? const [];
    if (files.isNotEmpty) return (files.first as Map)['id'] as String;
    final created = await _json(await _http.post(
      Uri.parse(_api).replace(queryParameters: {'fields': 'id'}),
      headers: {..._auth, 'Content-Type': 'application/json'},
      body: jsonEncode({'name': backupFolderName, 'mimeType': 'application/vnd.google-apps.folder'}),
    ));
    return created['id'] as String;
  }

  /// Uploads [content] as a JSON file named [name] into [folderId].
  Future<DriveFile> upload(String folderId, String name, String content) async {
    const boundary = 'finroot-backup-boundary';
    final body = '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '${jsonEncode({'name': name, 'parents': [folderId], 'mimeType': 'application/json'})}\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json\r\n\r\n'
        '$content\r\n'
        '--$boundary--';
    final r = await _json(await _http.post(
      Uri.parse(_upload).replace(queryParameters: {
        'uploadType': 'multipart',
        'fields': 'id,name,modifiedTime,size',
      }),
      headers: {..._auth, 'Content-Type': 'multipart/related; boundary=$boundary'},
      body: utf8.encode(body),
    ));
    return _file(r);
  }

  /// Backups in [folderId], newest first.
  Future<List<DriveFile>> list(String folderId) async {
    final r = await _json(await _http.get(
      Uri.parse(_api).replace(queryParameters: {
        'q': "'$folderId' in parents and trashed = false",
        'orderBy': 'modifiedTime desc',
        'fields': 'files(id,name,modifiedTime,size)',
        'pageSize': '100',
      }),
      headers: _auth,
    ));
    return [for (final f in (r['files'] as List<dynamic>? ?? const [])) _file(f as Map<String, dynamic>)];
  }

  Future<String> download(String fileId) async {
    final r = await _http.get(
      Uri.parse('$_api/$fileId').replace(queryParameters: {'alt': 'media'}),
      headers: _auth,
    );
    if (r.statusCode != 200) await _json(r);
    return utf8.decode(r.bodyBytes);
  }

  Future<void> delete(String fileId) async {
    final r = await _http.delete(Uri.parse('$_api/$fileId'), headers: _auth);
    if (r.statusCode != 204 && r.statusCode != 200) await _json(r);
  }

  static DriveFile _file(Map<String, dynamic> f) => DriveFile(
        id: f['id'] as String,
        name: f['name'] as String? ?? '',
        modified: DateTime.tryParse(f['modifiedTime'] as String? ?? '') ?? DateTime.now(),
        size: int.tryParse('${f['size'] ?? ''}'),
      );
}
