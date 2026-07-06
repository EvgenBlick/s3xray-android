import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../domain/app_update_manifest.dart';

typedef UpdateManifestFetcher = Future<String> Function(Uri uri);
typedef UpdateProgressCallback = void Function(int receivedBytes, int totalBytes);

class AppUpdateRepository {
  const AppUpdateRepository({
    UpdateManifestFetcher? manifestFetcher,
  }) : _manifestFetcher = manifestFetcher;

  final UpdateManifestFetcher? _manifestFetcher;

  Future<AppUpdateManifest> fetchManifest(Uri manifestUri) async {
    final String body;
    if (_manifestFetcher != null) {
      body = await _manifestFetcher.call(manifestUri);
    } else {
      body = await _fetchManifest(manifestUri);
    }

    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('update_manifest_must_be_object');
    }

    return AppUpdateManifest.fromJson(decoded, sourceUri: manifestUri);
  }

  Future<File> downloadApk({
    required Uri apkUri,
    required String expectedSha256,
    required String targetDirectoryPath,
    required String fileName,
    UpdateProgressCallback? onProgress,
  }) async {
    final Directory targetDirectory = Directory(targetDirectoryPath);
    if (!targetDirectory.existsSync()) {
      await targetDirectory.create(recursive: true);
    }

    final File targetFile = File('${targetDirectory.path}/$fileName');
    if (targetFile.existsSync()) {
      await targetFile.delete();
    }

    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(apkUri);
      final HttpClientResponse response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'apk_download_failed:${response.statusCode}',
          uri: apkUri,
        );
      }

      final IOSink sink = targetFile.openWrite();
      int receivedBytes = 0;
      final int totalBytes = response.contentLength;

      await for (final List<int> chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress?.call(receivedBytes, totalBytes);
      }

      await sink.flush();
      await sink.close();
      await _verifyChecksum(
        file: targetFile,
        expectedSha256: expectedSha256,
      );
      return targetFile;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _fetchManifest(Uri manifestUri) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(manifestUri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final HttpClientResponse response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'manifest_fetch_failed:${response.statusCode}',
          uri: manifestUri,
        );
      }

      return response.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _verifyChecksum({
    required File file,
    required String expectedSha256,
  }) async {
    final Digest digest = await sha256.bind(file.openRead()).first;
    final String actualSha256 = digest.toString().toLowerCase();
    if (actualSha256 != expectedSha256.toLowerCase()) {
      await file.delete();
      throw const FormatException('apk_checksum_mismatch');
    }
  }
}
