import 'package:flutter/services.dart';

import '../domain/local_app_info.dart';
import 'app_update_platform_bridge.dart';

class MethodChannelAppUpdatePlatformBridge implements AppUpdatePlatformBridge {
  const MethodChannelAppUpdatePlatformBridge();

  static const MethodChannel _channel = MethodChannel('stockvpn/app_update');

  @override
  Future<LocalAppInfo> getLocalAppInfo() async {
    final Map<Object?, Object?>? payload =
        await _channel.invokeMapMethod<Object?, Object?>('getAppInfo');
    if (payload == null) {
      throw const FormatException('missing_app_info_payload');
    }
    return LocalAppInfo.fromJson(payload);
  }

  @override
  Future<String> getUpdateDirectoryPath() async {
    final String? path = await _channel.invokeMethod<String>('getUpdateDirectory');
    if (path == null || path.trim().isEmpty) {
      throw const FormatException('missing_update_directory');
    }
    return path;
  }

  @override
  Future<AppUpdateInstallResult> installApk(String apkPath) async {
    final String? result = await _channel.invokeMethod<String>(
      'installApk',
      <String, Object?>{'path': apkPath},
    );
    switch (result) {
      case 'permission_required':
        return AppUpdateInstallResult.permissionRequired;
      case 'install_started':
        return AppUpdateInstallResult.installStarted;
      default:
        throw FormatException('unknown_install_result:$result');
    }
  }
}
