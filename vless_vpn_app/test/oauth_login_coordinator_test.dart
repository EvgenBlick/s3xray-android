import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vless_vpn_app/features/auth/application/auth_platform_bridge.dart';
import 'package:vless_vpn_app/features/auth/application/oauth_login_coordinator.dart';
import 'package:vless_vpn_app/features/auth/application/pending_oauth_request_repository.dart';
import 'package:vless_vpn_app/features/auth/domain/pending_oauth_request.dart';
import 'package:vless_vpn_app/features/cabinet_api/application/cabinet_auth_repository.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_auth_provider.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_email_auth_config.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_oauth_authorize_response.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_oauth_callback_payload.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_session.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_user.dart';

void main() {
  test('starts browser flow and persists pending oauth request', () async {
    final _FakeCabinetAuthRepository authRepository =
        _FakeCabinetAuthRepository();
    final _FakeAuthPlatformBridge platformBridge = _FakeAuthPlatformBridge();
    final _FakePendingOAuthRequestRepository pendingRequestRepository =
        _FakePendingOAuthRequestRepository();
    final OAuthLoginCoordinator coordinator = OAuthLoginCoordinator(
      authRepository: authRepository,
      platformBridge: platformBridge,
      pendingRequestRepository: pendingRequestRepository,
    );

    await coordinator.start(
      const CabinetAuthProvider(name: 'yandex', displayName: 'Yandex'),
    );

    expect(
      platformBridge.openedUrls.single.toString(),
      'https://oauth.example.test/authorize?state=expected-state&redirect_uri=https%3A%2F%2Fweb.ultimteam.ru%2Fauth%2Foauth%2Fcallback%3Fapp%3D1',
    );
    expect(pendingRequestRepository.savedRequest?.provider, 'yandex');
    expect(pendingRequestRepository.savedRequest?.state, 'expected-state');
  });
}

class _FakeCabinetAuthRepository implements CabinetAuthRepository {
  static final CabinetSession _session = CabinetSession(
    accessToken: 'access',
    refreshToken: 'refresh',
    tokenType: 'bearer',
    expiresAt: DateTime.utc(2030),
  );
  @override
  Future<CabinetSession?> bootstrapSession() async => null;

  @override
  Future<void> clearSession() async {}

  @override
  Future<List<CabinetAuthProvider>> getAvailableAuthProviders() async {
    return const <CabinetAuthProvider>[];
  }

  @override
  Future<CabinetEmailAuthConfig> getEmailAuthConfig() async {
    return const CabinetEmailAuthConfig(enabled: true);
  }

  @override
  Future<CabinetUser> getCurrentUser(CabinetSession session) {
    throw UnimplementedError();
  }

  @override
  Future<CabinetOAuthAuthorizeResponse> getOAuthAuthorizeUrl(
    String provider,
  ) async {
    return CabinetOAuthAuthorizeResponse(
      authorizeUrl: Uri.parse(
        'https://oauth.example.test/authorize?state=expected-state&redirect_uri=https%3A%2F%2Fweb.ultimteam.ru%2Fauth%2Foauth%2Fcallback',
      ),
      state: 'expected-state',
    );
  }

  @override
  Future<CabinetSession> loginWithEmail({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<CabinetSession?> loadStoredSession() async => null;

  @override
  Future<void> persistSession(CabinetSession session) async {}

  @override
  Future<CabinetSession> loginWithOAuth({
    required String provider,
    required CabinetOAuthCallbackPayload payload,
  }) async {
    return _session;
  }
}

class _FakeAuthPlatformBridge implements AuthPlatformBridge {
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();
  final List<Uri> openedUrls = <Uri>[];

  @override
  Stream<Uri> get callbackLinks => _controller.stream;

  @override
  Future<Uri?> consumePendingCallbackLink() async => null;

  void emitCallback(Uri uri) {
    _controller.add(uri);
  }

  @override
  Future<void> openExternalUrl(Uri uri) async {
    openedUrls.add(uri);
  }
}

class _FakePendingOAuthRequestRepository extends PendingOAuthRequestRepository {
  PendingOAuthRequest? savedRequest;

  @override
  Future<void> clear() async {
    savedRequest = null;
  }

  @override
  Future<PendingOAuthRequest?> load() async => savedRequest;

  @override
  Future<void> save(PendingOAuthRequest request) async {
    savedRequest = request;
  }
}
