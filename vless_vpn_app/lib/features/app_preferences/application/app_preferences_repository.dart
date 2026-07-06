import 'package:flutter/services.dart';

class AppPreferencesRepository {
  const AppPreferencesRepository();

  static const MethodChannel _channel = MethodChannel('stockvpn/app_preferences');

  Future<String?> loadLastImportLink() async {
    try {
      final String? value = await _channel.invokeMethod<String>('getLastImportLink');
      if (value == null || value.trim().isEmpty) {
        return null;
      }
      return value.trim();
    } on PlatformException {
      return null;
    }
  }

  Future<void> saveLastImportLink(String link) async {
    try {
      await _channel.invokeMethod<void>('setLastImportLink', <String, Object?>{
        'link': link.trim(),
      });
    } on PlatformException {
      return;
    }
  }

  Future<bool> loadGuestModeEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('getGuestModeEnabled') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> saveGuestModeEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setGuestModeEnabled', <String, Object?>{
        'enabled': enabled,
      });
    } on PlatformException {
      return;
    }
  }
}
