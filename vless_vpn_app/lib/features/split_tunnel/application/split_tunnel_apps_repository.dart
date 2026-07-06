import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/split_tunnel_app.dart';

class SplitTunnelAppsRepository {
  const SplitTunnelAppsRepository({
    bool? supportsNativeApps,
  }) : _supportsNativeAppsOverride = supportsNativeApps;

  static const MethodChannel _channel = MethodChannel('stockvpn/split_tunnel');
  final bool? _supportsNativeAppsOverride;

  Future<List<SplitTunnelApp>> listApps() async {
    if (!_supportsNativeApps) {
      return const <SplitTunnelApp>[];
    }

    final List<Object?> rawApps;
    try {
      rawApps =
          await _channel.invokeListMethod<Object?>('listApps') ??
          const <Object?>[];
    } on PlatformException {
      return const <SplitTunnelApp>[];
    }

    final List<SplitTunnelApp> apps = rawApps
        .whereType<Map<Object?, Object?>>()
        .map(SplitTunnelApp.fromMap)
        .where((SplitTunnelApp app) => app.packageName.isNotEmpty)
        .toList();

    apps.sort((SplitTunnelApp a, SplitTunnelApp b) {
      if (a.isSystemApp != b.isSystemApp) {
        return a.isSystemApp ? 1 : -1;
      }
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return apps;
  }

  Future<Set<String>> loadBlockedPackages() async {
    if (!_supportsNativeApps) {
      return <String>{};
    }

    final List<Object?> rawPackages;
    try {
      rawPackages =
          await _channel.invokeListMethod<Object?>('getBlockedApps') ??
          const <Object?>[];
    } on PlatformException {
      return <String>{};
    }

    return rawPackages.map((Object? item) => item.toString()).toSet();
  }

  Future<void> saveBlockedPackages(Set<String> packages) async {
    if (!_supportsNativeApps) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('setBlockedApps', <String, Object?>{
        'packages': packages.toList()..sort(),
      });
    } on PlatformException {
      return;
    }
  }

  bool get _supportsNativeApps =>
      _supportsNativeAppsOverride ??
      (!kIsWeb && Platform.isAndroid);
}
