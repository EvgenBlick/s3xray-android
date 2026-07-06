import 'dart:io';

import 'package:flutter/services.dart';

class SubscriptionRequestHeadersProvider {
  static const MethodChannel _channel = MethodChannel(
    'stockvpn/subscription_device',
  );

  Future<Map<String, String>> buildHeaders() async {
    final Map<String, String> headers = <String, String>{};

    if (!Platform.isAndroid) {
      return headers;
    }

    try {
      final Map<Object?, Object?>? result =
          await _channel.invokeMethod<Map<Object?, Object?>>('getHeaders');
      if (result == null) {
        return headers;
      }

      final String hwid = '${result['hwid'] ?? ''}'.trim();
      final String deviceOs = '${result['deviceOs'] ?? 'Android'}'.trim();
      final String osVersion = '${result['osVersion'] ?? ''}'.trim();
      final String deviceModel = '${result['deviceModel'] ?? ''}'.trim();

      if (hwid.isNotEmpty) {
        headers['x-hwid'] = hwid;
      }
      if (deviceOs.isNotEmpty) {
        headers['x-device-os'] = deviceOs;
      }
      if (osVersion.isNotEmpty) {
        headers['x-ver-os'] = osVersion;
      }
      if (deviceModel.isNotEmpty) {
        headers['x-device-model'] = deviceModel;
      }
    } catch (_) {
      return headers;
    }

    return headers;
  }
}
