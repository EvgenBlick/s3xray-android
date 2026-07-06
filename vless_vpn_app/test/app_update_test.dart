import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vless_vpn_app/features/app_update/application/app_update_controller.dart';
import 'package:vless_vpn_app/features/app_update/application/app_update_platform_bridge.dart';
import 'package:vless_vpn_app/features/app_update/application/app_update_repository.dart';
import 'package:vless_vpn_app/features/app_update/domain/app_update_manifest.dart';
import 'package:vless_vpn_app/features/app_update/domain/local_app_info.dart';

void main() {
  test('parses update manifest and resolves relative apk url', () {
    final AppUpdateManifest manifest = AppUpdateManifest.fromJson(
      <String, Object?>{
        'versionCode': 3,
        'versionName': '1.0.2',
        'apkUrl': 'app-release.apk',
        'checksumSha256':
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'changelog': 'Bugfixes',
      },
      sourceUri: Uri.parse('https://pedzeo.ru/updates/latest.json'),
    );

    expect(manifest.versionCode, 3);
    expect(manifest.versionName, '1.0.2');
    expect(
      manifest.apkUrl.toString(),
      'https://pedzeo.ru/updates/app-release.apk',
    );
    expect(manifest.changelog, 'Bugfixes');
    expect(
      manifest.checksumSha256,
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
  });

  test('controller reports available update when manifest version is newer', () async {
    final AppUpdateController controller = AppUpdateController(
      manifestUri: Uri.parse('https://example.com/latest.json'),
      repository: AppUpdateRepository(
        manifestFetcher: (_) async => '''
          {
            "versionCode": 7,
            "versionName": "1.0.7",
            "apkUrl": "https://example.com/app-release.apk",
            "checksumSha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
          }
        ''',
      ),
      platformBridge: _FakeAppUpdatePlatformBridge(),
    );

    await controller.initialize();

    expect(controller.snapshot.status, AppUpdateStatus.available);
    expect(controller.snapshot.manifest?.versionCode, 7);
    expect(controller.snapshot.localAppInfo?.versionCode, 1);
  });

  test('controller invalidates cached apk when manifest changes', () async {
    final _FakeAppUpdateRepository repository = _FakeAppUpdateRepository(
      manifests: <AppUpdateManifest>[
        AppUpdateManifest.fromJson(
          <String, Object?>{
            'versionCode': 7,
            'versionName': '1.0.7',
            'apkUrl': 'https://example.com/app-release-7.apk',
            'checksumSha256':
                'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          },
          sourceUri: Uri.parse('https://example.com/latest.json'),
        ),
        AppUpdateManifest.fromJson(
          <String, Object?>{
            'versionCode': 8,
            'versionName': '1.0.8',
            'apkUrl': 'https://example.com/app-release-8.apk',
            'checksumSha256':
                'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          },
          sourceUri: Uri.parse('https://example.com/latest.json'),
        ),
      ],
    );

    final AppUpdateController controller = AppUpdateController(
      manifestUri: Uri.parse('https://example.com/latest.json'),
      repository: repository,
      platformBridge: _FakeAppUpdatePlatformBridge(
        onGetUpdateDirectoryPath: () async => '/tmp',
        onInstallApk: (_) async => AppUpdateInstallResult.permissionRequired,
      ),
    );

    await controller.initialize();
    await controller.downloadAndInstall();
    await controller.checkForUpdates();
    await controller.downloadAndInstall();

    expect(repository.downloadCount, 2);
  });

  test('rejects insecure update manifest urls', () {
    expect(
      () => AppUpdateManifest.fromJson(
        <String, Object?>{
          'versionCode': 3,
          'versionName': '1.0.2',
          'apkUrl': 'http://example.com/app-release.apk',
          'checksumSha256':
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        },
        sourceUri: Uri.parse('http://example.com/latest.json'),
      ),
      throwsFormatException,
    );
  });

  test('rejects invalid checksum values', () {
    expect(
      () => AppUpdateManifest.fromJson(
        <String, Object?>{
          'versionCode': 3,
          'versionName': '1.0.2',
          'apkUrl': 'https://example.com/app-release.apk',
          'checksumSha256': 'deadbeef',
        },
        sourceUri: Uri.parse('https://example.com/latest.json'),
      ),
      throwsFormatException,
    );
  });
}

class _FakeAppUpdatePlatformBridge implements AppUpdatePlatformBridge {
  const _FakeAppUpdatePlatformBridge({
    this.onGetUpdateDirectoryPath,
    this.onInstallApk,
  });

  final Future<String> Function()? onGetUpdateDirectoryPath;
  final Future<AppUpdateInstallResult> Function(String apkPath)? onInstallApk;

  @override
  Future<LocalAppInfo> getLocalAppInfo() async {
    return const LocalAppInfo(
      packageName: 'com.stockvpn.vless_vpn_app',
      versionName: '1.0.0',
      versionCode: 1,
    );
  }

  @override
  Future<String> getUpdateDirectoryPath() async {
    if (onGetUpdateDirectoryPath != null) {
      return onGetUpdateDirectoryPath!.call();
    }
    return '/tmp';
  }

  @override
  Future<AppUpdateInstallResult> installApk(String apkPath) async {
    if (onInstallApk != null) {
      return onInstallApk!.call(apkPath);
    }
    return AppUpdateInstallResult.installStarted;
  }
}

class _FakeAppUpdateRepository extends AppUpdateRepository {
  _FakeAppUpdateRepository({
    required List<AppUpdateManifest> manifests,
  }) : _manifests = manifests;

  final List<AppUpdateManifest> _manifests;
  int _manifestIndex = 0;
  int downloadCount = 0;

  @override
  Future<AppUpdateManifest> fetchManifest(Uri manifestUri) {
    final int safeIndex = _manifestIndex.clamp(0, _manifests.length - 1);
    final AppUpdateManifest manifest = _manifests[safeIndex];
    if (_manifestIndex < _manifests.length - 1) {
      _manifestIndex++;
    }
    return Future<AppUpdateManifest>.value(manifest);
  }

  @override
  Future<File> downloadApk({
    required Uri apkUri,
    required String expectedSha256,
    required String targetDirectoryPath,
    required String fileName,
    UpdateProgressCallback? onProgress,
  }) async {
    downloadCount++;
    return File('$targetDirectoryPath/$fileName');
  }
}
