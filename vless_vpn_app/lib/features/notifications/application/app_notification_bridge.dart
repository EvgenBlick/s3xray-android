import 'package:flutter/services.dart';

class AppNotificationBridge {
  const AppNotificationBridge({
    MethodChannel methodChannel = const MethodChannel('stockvpn/notifications'),
  }) : _methodChannel = methodChannel;

  final MethodChannel _methodChannel;

  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await _methodChannel.invokeMethod<bool>(
        'showNotification',
        <String, Object?>{'id': id, 'title': title, 'body': body},
      );
    } on PlatformException {
      // Notifications are optional and must never break purchase/update flows.
    } on MissingPluginException {
      // Tests and non-Android builds do not expose this channel.
    }
  }
}
