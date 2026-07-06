import 'package:flutter/services.dart';

import '../domain/pending_oauth_request.dart';

class PendingOAuthRequestRepository {
  const PendingOAuthRequestRepository();

  static const MethodChannel _channel = MethodChannel(
    'stockvpn/auth_pending_request',
  );

  Future<void> save(PendingOAuthRequest request) async {
    try {
      await _channel.invokeMethod<void>('setPendingRequest', <String, Object?>{
        'provider': request.provider,
        'state': request.state,
      });
    } on PlatformException {
      return;
    }
  }

  Future<PendingOAuthRequest?> load() async {
    try {
      final Map<Object?, Object?>? raw = await _channel
          .invokeMethod<Map<Object?, Object?>>('getPendingRequest');
      if (raw == null) {
        return null;
      }

      final String provider = (raw['provider'] as String? ?? '').trim();
      final String state = (raw['state'] as String? ?? '').trim();
      if (provider.isEmpty || state.isEmpty) {
        return null;
      }

      return PendingOAuthRequest(provider: provider, state: state);
    } on PlatformException {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clearPendingRequest');
    } on PlatformException {
      return;
    }
  }
}
