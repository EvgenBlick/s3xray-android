import 'package:flutter/services.dart';

import '../domain/cabinet_session.dart';
import 'cabinet_session_storage.dart';

class MethodChannelCabinetSessionStorage implements CabinetSessionStorage {
  const MethodChannelCabinetSessionStorage();

  static const MethodChannel _channel = MethodChannel('stockvpn/cabinet_session');

  @override
  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clearSession');
    } on PlatformException {
      return;
    }
  }

  @override
  Future<CabinetSession?> load() async {
    try {
      final Map<Object?, Object?>? result =
          await _channel.invokeMapMethod<Object?, Object?>('getSession');
      if (result == null || result.isEmpty) {
        return null;
      }

      final String accessToken = (result['accessToken'] ?? '') as String;
      final String refreshToken = (result['refreshToken'] ?? '') as String;
      final String expiresAt = (result['expiresAt'] ?? '') as String;
      if (accessToken.trim().isEmpty ||
          refreshToken.trim().isEmpty ||
          expiresAt.trim().isEmpty) {
        return null;
      }

      return CabinetSession.fromMap(result);
    } on PlatformException {
      return null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(CabinetSession session) async {
    try {
      await _channel.invokeMethod<void>('setSession', session.toMap());
    } on PlatformException {
      return;
    }
  }
}
