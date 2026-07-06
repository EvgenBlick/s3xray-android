import 'dart:async';

abstract class AuthPlatformBridge {
  Stream<Uri> get callbackLinks;

  Future<void> openExternalUrl(Uri uri);

  Future<Uri?> consumePendingCallbackLink();
}
