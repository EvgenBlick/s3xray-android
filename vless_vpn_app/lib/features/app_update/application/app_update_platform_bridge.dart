import '../domain/local_app_info.dart';

enum AppUpdateInstallResult {
  installStarted,
  permissionRequired,
}

abstract class AppUpdatePlatformBridge {
  Future<LocalAppInfo> getLocalAppInfo();

  Future<String> getUpdateDirectoryPath();

  Future<AppUpdateInstallResult> installApk(String apkPath);
}
