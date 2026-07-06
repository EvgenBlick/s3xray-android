import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vless_platform_interface/flutter_vless_platform_interface.dart';

/// iOS implementation of [VlessPlatform] using MethodChannel.
class FlutterVlessIOS extends VlessPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_vless');

  /// The event channel for status updates.
  final eventChannel = const EventChannel('flutter_vless/status');

  StreamSubscription<dynamic>? _statusSubscription;

  /// Registers this class as the platform implementation.
  static void registerWith() {
    VlessPlatform.instance = FlutterVlessIOS();
  }

  @override
  Future<void> initializeVless({
    required void Function(VlessStatus status) onStatusChanged,
    required String notificationIconResourceType,
    required String notificationIconResourceName,
    required String providerBundleIdentifier,
    required String groupIdentifier,
  }) async {
    await _statusSubscription?.cancel();
    _statusSubscription = eventChannel
        .receiveBroadcastStream()
        .distinct()
        .listen((dynamic event) {
          if (event != null) {
            onStatusChanged.call(_statusFromEvent(event));
          }
        });

    await methodChannel.invokeMethod('initializeVless', {
      "notificationIconResourceType": notificationIconResourceType,
      "notificationIconResourceName": notificationIconResourceName,
      "providerBundleIdentifier": providerBundleIdentifier,
      "groupIdentifier": groupIdentifier,
    });
  }

  @override
  Future<void> startVless({
    required String remark,
    required String config,
    required String notificationDisconnectButtonName,
    List<String>? blockedApps,
    List<String>? bypassSubnets,
    bool proxyOnly = false,
  }) async {
    await methodChannel.invokeMethod('startVless', {
      "remark": remark,
      "config": config,
      "blocked_apps": blockedApps,
      "bypass_subnets": bypassSubnets,
      "proxy_only": proxyOnly,
      "notificationDisconnectButtonName": notificationDisconnectButtonName,
    });
  }

  @override
  Future<void> stopVless() async {
    await methodChannel.invokeMethod('stopVless');
  }

  @override
  void disposeVless() {
    _statusSubscription?.cancel();
    _statusSubscription = null;
  }

  @override
  Future<int> getServerDelay({
    required String config,
    required String url,
  }) async {
    return await methodChannel.invokeMethod('getServerDelay', {
      "config": config,
      "url": url,
    });
  }

  @override
  Future<int> getConnectedServerDelay(String url) async {
    return await methodChannel.invokeMethod('getConnectedServerDelay', {
      "url": url,
    });
  }

  @override
  Future<bool> requestPermission() async {
    return (await methodChannel.invokeMethod('requestPermission')) ?? false;
  }

  @override
  Future<String> getCoreVersion() async {
    return await methodChannel.invokeMethod('getCoreVersion');
  }

  VlessStatus _statusFromEvent(dynamic event) {
    final List<dynamic> values = List<dynamic>.from(event as Iterable<dynamic>);
    return VlessStatus(
      duration: int.parse(values[0].toString()),
      uploadSpeed: int.parse(values[1].toString()),
      downloadSpeed: int.parse(values[2].toString()),
      upload: int.parse(values[3].toString()),
      download: int.parse(values[4].toString()),
      state: values[5].toString(),
    );
  }
}
