import 'dart:async';

import 'package:flutter/services.dart';

class S3xDeepLinkBridge {
  const S3xDeepLinkBridge();

  static const MethodChannel _methodChannel = MethodChannel('s3x/deeplink');
  static const EventChannel _eventChannel = EventChannel('s3x/deeplink/events');

  Stream<String> get links => _eventChannel
      .receiveBroadcastStream()
      .where((Object? event) => event is String && event.trim().isNotEmpty)
      .cast<String>();

  Future<String?> consumePendingLink() async {
    final String? link = await _methodChannel.invokeMethod<String>(
      'consumePendingLink',
    );
    if (link == null || link.trim().isEmpty) {
      return null;
    }
    return link;
  }
}
