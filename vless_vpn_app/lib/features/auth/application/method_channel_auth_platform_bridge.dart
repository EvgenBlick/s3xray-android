import 'dart:async';

import 'package:flutter/services.dart';

import 'auth_platform_bridge.dart';

class MethodChannelAuthPlatformBridge implements AuthPlatformBridge {
  MethodChannelAuthPlatformBridge({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel =
           methodChannel ?? const MethodChannel('stockvpn/auth_platform'),
       _eventChannel =
           eventChannel ?? const EventChannel('stockvpn/auth_platform/events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  @override
  Stream<Uri> get callbackLinks => _eventChannel
      .receiveBroadcastStream()
      .where((Object? event) => event is String && event.trim().isNotEmpty)
      .map((Object? event) => Uri.parse((event! as String).trim()));

  @override
  Future<Uri?> consumePendingCallbackLink() async {
    final String? rawUri = await _methodChannel.invokeMethod<String>(
      'consumePendingCallbackLink',
    );
    if (rawUri == null || rawUri.trim().isEmpty) {
      return null;
    }
    return Uri.parse(rawUri.trim());
  }

  @override
  Future<void> openExternalUrl(Uri uri) {
    return _methodChannel.invokeMethod<void>(
      'openExternalUrl',
      <String, Object?>{'url': uri.toString()},
    );
  }
}
