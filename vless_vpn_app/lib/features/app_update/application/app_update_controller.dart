import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/app_update_manifest.dart';
import '../domain/local_app_info.dart';
import 'app_update_platform_bridge.dart';
import 'app_update_repository.dart';
import 'method_channel_app_update_platform_bridge.dart';

enum AppUpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  installing,
  installPermissionRequired,
  error,
}

class AppUpdateSnapshot {
  const AppUpdateSnapshot({
    required this.status,
    this.localAppInfo,
    this.manifest,
    this.downloadProgress,
    this.errorMessage,
  });

  final AppUpdateStatus status;
  final LocalAppInfo? localAppInfo;
  final AppUpdateManifest? manifest;
  final double? downloadProgress;
  final String? errorMessage;

  bool get hasAvailableUpdate => status == AppUpdateStatus.available;

  AppUpdateSnapshot copyWith({
    AppUpdateStatus? status,
    LocalAppInfo? localAppInfo,
    AppUpdateManifest? manifest,
    double? downloadProgress,
    String? errorMessage,
    bool clearManifest = false,
    bool clearProgress = false,
    bool clearError = false,
  }) {
    return AppUpdateSnapshot(
      status: status ?? this.status,
      localAppInfo: localAppInfo ?? this.localAppInfo,
      manifest: clearManifest ? null : (manifest ?? this.manifest),
      downloadProgress: clearProgress
          ? null
          : (downloadProgress ?? this.downloadProgress),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AppUpdateController extends ChangeNotifier {
  AppUpdateController({
    required Uri manifestUri,
    AppUpdateRepository repository = const AppUpdateRepository(),
    AppUpdatePlatformBridge platformBridge =
        const MethodChannelAppUpdatePlatformBridge(),
  }) : _manifestUri = manifestUri,
       _repository = repository,
       _platformBridge = platformBridge;

  final Uri _manifestUri;
  final AppUpdateRepository _repository;
  final AppUpdatePlatformBridge _platformBridge;

  AppUpdateSnapshot _snapshot = const AppUpdateSnapshot(
    status: AppUpdateStatus.idle,
  );
  String? _downloadedApkPath;
  bool _initialized = false;

  AppUpdateSnapshot get snapshot => _snapshot;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await checkForUpdates();
  }

  Future<void> checkForUpdates() async {
    _setSnapshot(
      _snapshot.copyWith(
        status: AppUpdateStatus.checking,
        clearError: true,
        clearProgress: true,
      ),
    );

    try {
      final LocalAppInfo localAppInfo = await _platformBridge.getLocalAppInfo();
      final AppUpdateManifest manifest = await _repository.fetchManifest(_manifestUri);
      if (_shouldInvalidateDownloadedApk(manifest)) {
        _downloadedApkPath = null;
      }
      final bool hasUpdate = manifest.versionCode > localAppInfo.versionCode;

      _setSnapshot(
        _snapshot.copyWith(
          status: hasUpdate ? AppUpdateStatus.available : AppUpdateStatus.upToDate,
          localAppInfo: localAppInfo,
          manifest: manifest,
          clearProgress: true,
          clearError: true,
        ),
      );
    } catch (error) {
      _setSnapshot(
        _snapshot.copyWith(
          status: AppUpdateStatus.error,
          errorMessage: error.toString(),
          clearProgress: true,
        ),
      );
    }
  }

  bool _shouldInvalidateDownloadedApk(AppUpdateManifest nextManifest) {
    final AppUpdateManifest? currentManifest = _snapshot.manifest;
    if (currentManifest == null) {
      return false;
    }

    return currentManifest.versionCode != nextManifest.versionCode ||
        currentManifest.apkUrl != nextManifest.apkUrl ||
        currentManifest.checksumSha256 != nextManifest.checksumSha256;
  }

  Future<void> downloadAndInstall() async {
    final AppUpdateManifest? manifest = _snapshot.manifest;
    if (manifest == null) {
      await checkForUpdates();
      if (_snapshot.manifest == null) {
        return;
      }
    }

    final AppUpdateManifest updateManifest = _snapshot.manifest!;
    final String apkPath = _downloadedApkPath ?? await _downloadUpdate(updateManifest);
    await _installDownloadedApk(apkPath);
  }

  Future<String> _downloadUpdate(AppUpdateManifest manifest) async {
    _setSnapshot(
      _snapshot.copyWith(
        status: AppUpdateStatus.downloading,
        downloadProgress: 0,
        clearError: true,
      ),
    );

    final String updateDirectoryPath = await _platformBridge.getUpdateDirectoryPath();
    final file = await _repository.downloadApk(
      apkUri: manifest.apkUrl,
      expectedSha256: manifest.checksumSha256,
      targetDirectoryPath: updateDirectoryPath,
      fileName: 'samurai-service-${manifest.versionCode}.apk',
      onProgress: (int receivedBytes, int totalBytes) {
        final double? progress = totalBytes <= 0
            ? null
            : receivedBytes / totalBytes;
        _setSnapshot(
          _snapshot.copyWith(
            status: AppUpdateStatus.downloading,
            downloadProgress: progress,
            clearError: true,
          ),
        );
      },
    );

    _downloadedApkPath = file.path;
    return file.path;
  }

  Future<void> _installDownloadedApk(String apkPath) async {
    _setSnapshot(
      _snapshot.copyWith(
        status: AppUpdateStatus.installing,
        clearError: true,
      ),
    );

    try {
      final AppUpdateInstallResult result = await _platformBridge.installApk(apkPath);
      final AppUpdateStatus nextStatus = switch (result) {
        AppUpdateInstallResult.installStarted => AppUpdateStatus.installing,
        AppUpdateInstallResult.permissionRequired =>
          AppUpdateStatus.installPermissionRequired,
      };

      _setSnapshot(
        _snapshot.copyWith(
          status: nextStatus,
          clearError: true,
        ),
      );
    } catch (error) {
      _setSnapshot(
        _snapshot.copyWith(
          status: AppUpdateStatus.error,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  void _setSnapshot(AppUpdateSnapshot snapshot) {
    _snapshot = snapshot;
    notifyListeners();
  }
}
