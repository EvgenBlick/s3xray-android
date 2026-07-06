import 'package:flutter_test/flutter_test.dart';
import 'package:vless_vpn_app/features/cabinet_api/application/cabinet_auth_repository.dart';
import 'package:vless_vpn_app/features/cabinet_api/application/cabinet_bootstrap_controller.dart';
import 'package:vless_vpn_app/features/cabinet_api/application/cabinet_bootstrap_snapshot.dart';
import 'package:vless_vpn_app/features/cabinet_api/application/cabinet_subscription_repository.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_app_config.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_auth_provider.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_email_auth_config.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_connection_link.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_oauth_authorize_response.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_oauth_callback_payload.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_session.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_subscription_status.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_trial_activation_result.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_trial_info.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_user.dart';

void main() {
  test('bootstraps cabinet session and resolves import link', () async {
    final controller = CabinetBootstrapController(
      authRepository: _FakeCabinetAuthRepository(),
      subscriptionRepository: _FakeCabinetSubscriptionRepository(),
    );

    final CabinetBootstrapSnapshot snapshot = await controller.initialize();

    expect(snapshot.state, CabinetBootstrapState.ready);
    expect(snapshot.user, isNotNull);
    expect(snapshot.subscriptionStatus, isNotNull);
    expect(snapshot.importLink, 'https://sub.pedze.ru/GMfWZNmbtqyR4fgk');
  });

  test('auto-activates trial for new cabinet account and resolves import link', () async {
    final _FakeTrialCabinetSubscriptionRepository repository =
        _FakeTrialCabinetSubscriptionRepository();
    final controller = CabinetBootstrapController(
      authRepository: _FakeCabinetAuthRepository(),
      subscriptionRepository: repository,
    );

    final CabinetBootstrapSnapshot snapshot = await controller.initialize();

    expect(snapshot.state, CabinetBootstrapState.ready);
    expect(snapshot.activatedTrialDuringBootstrap, isTrue);
    expect(snapshot.subscriptionStatus?.hasSubscription, isTrue);
    expect(snapshot.importLink, 'https://sub.pedze.ru/new-trial-link');
    expect(repository.activationCount, 1);
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
  Future<CabinetSession?> bootstrapSession() async => _session;

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
  Future<CabinetOAuthAuthorizeResponse> getOAuthAuthorizeUrl(
    String provider,
  ) async {
    return CabinetOAuthAuthorizeResponse(
      authorizeUrl: Uri.parse('https://web.ultimteam.ru/auth/oauth/callback'),
      state: 'state',
    );
  }

  @override
  Future<CabinetUser> getCurrentUser(CabinetSession session) async {
    return const CabinetUser(
      id: 1,
      email: 'user@example.com',
      firstName: 'Test',
      lastName: 'User',
      username: 'tester',
      balanceKopeks: 1000,
      language: 'ru',
    );
  }

  @override
  Future<CabinetSession> loginWithEmail({
    required String email,
    required String password,
  }) async => _session;

  @override
  Future<CabinetSession> loginWithOAuth({
    required String provider,
    required CabinetOAuthCallbackPayload payload,
  }) async => _session;

  @override
  Future<CabinetSession?> loadStoredSession() async => _session;

  @override
  Future<void> persistSession(CabinetSession session) async {}
}

class _FakeCabinetSubscriptionRepository
    implements CabinetSubscriptionRepository {
  @override
  Future<CabinetAppConfig> getAppConfig(CabinetSession session) async {
    return const CabinetAppConfig(
      hasSubscription: true,
      subscriptionUrl: null,
      hideLink: false,
      brandingName: 'Ultimteam',
      supportUrl: null,
    );
  }

  @override
  Future<CabinetConnectionLink> getConnectionLink(CabinetSession session) async {
    return const CabinetConnectionLink(
      subscriptionUrl: 'https://sub.pedze.ru/GMfWZNmbtqyR4fgk',
      displayLink: null,
      happRedirectLink: null,
      happSchemeLink: null,
      hideLink: false,
    );
  }

  @override
  Future<String?> resolveImportLink(CabinetSession session) async {
    return 'https://sub.pedze.ru/GMfWZNmbtqyR4fgk';
  }

  @override
  Future<CabinetSubscriptionStatus> getSubscriptionStatus(
    CabinetSession session,
  ) async {
    return const CabinetSubscriptionStatus(
      hasSubscription: true,
      subscriptionUrl: 'https://sub.pedze.ru/GMfWZNmbtqyR4fgk',
      hideSubscriptionLink: false,
      isActive: true,
      daysLeft: 30,
      timeLeftDisplay: '30 дней',
      trafficUsedGb: 12.5,
      trafficLimitGb: 100,
      deviceLimit: 3,
    );
  }

  @override
  Future<CabinetTrialActivationResult> activateTrial(
    CabinetSession session,
  ) async {
    return const CabinetTrialActivationResult(isTrial: true, isActive: true);
  }

  @override
  Future<CabinetTrialInfo> getTrialInfo(CabinetSession session) async {
    return const CabinetTrialInfo(
      isAvailable: false,
      durationDays: 7,
      trafficLimitGb: 0,
      deviceLimit: 1,
      requiresPayment: false,
      priceKopeks: 0,
      priceRubles: 0,
      reasonUnavailable: 'Trial already used',
    );
  }
}

class _FakeTrialCabinetSubscriptionRepository
    implements CabinetSubscriptionRepository {
  int activationCount = 0;
  bool _activated = false;

  @override
  Future<CabinetTrialActivationResult> activateTrial(
    CabinetSession session,
  ) async {
    activationCount += 1;
    _activated = true;
    return const CabinetTrialActivationResult(isTrial: true, isActive: true);
  }

  @override
  Future<CabinetAppConfig> getAppConfig(CabinetSession session) async {
    return const CabinetAppConfig(
      hasSubscription: true,
      subscriptionUrl: null,
      hideLink: false,
      brandingName: 'Ultimteam',
      supportUrl: null,
    );
  }

  @override
  Future<CabinetConnectionLink> getConnectionLink(CabinetSession session) async {
    return const CabinetConnectionLink(
      subscriptionUrl: 'https://sub.pedze.ru/new-trial-link',
      displayLink: null,
      happRedirectLink: null,
      happSchemeLink: null,
      hideLink: false,
    );
  }

  @override
  Future<CabinetSubscriptionStatus> getSubscriptionStatus(
    CabinetSession session,
  ) async {
    if (!_activated) {
      return const CabinetSubscriptionStatus(
        hasSubscription: false,
        subscriptionUrl: null,
        hideSubscriptionLink: false,
        isActive: false,
        daysLeft: 0,
        timeLeftDisplay: null,
        trafficUsedGb: null,
        trafficLimitGb: null,
        deviceLimit: null,
      );
    }

    return const CabinetSubscriptionStatus(
      hasSubscription: true,
      subscriptionUrl: 'https://sub.pedze.ru/new-trial-link',
      hideSubscriptionLink: false,
      isActive: true,
      daysLeft: 7,
      timeLeftDisplay: '7 дней',
      trafficUsedGb: 0,
      trafficLimitGb: 0,
      deviceLimit: 1,
    );
  }

  @override
  Future<CabinetTrialInfo> getTrialInfo(CabinetSession session) async {
    return const CabinetTrialInfo(
      isAvailable: true,
      durationDays: 7,
      trafficLimitGb: 0,
      deviceLimit: 1,
      requiresPayment: false,
      priceKopeks: 0,
      priceRubles: 0,
      reasonUnavailable: null,
    );
  }

  @override
  Future<String?> resolveImportLink(CabinetSession session) async {
    return _activated ? 'https://sub.pedze.ru/new-trial-link' : null;
  }
}
