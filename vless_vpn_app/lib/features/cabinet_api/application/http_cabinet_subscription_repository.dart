import '../domain/cabinet_app_config.dart';
import '../domain/cabinet_connection_link.dart';
import '../domain/cabinet_session.dart';
import '../domain/cabinet_subscription_status.dart';
import '../domain/cabinet_trial_activation_result.dart';
import '../domain/cabinet_trial_info.dart';
import 'cabinet_http_client.dart';
import 'cabinet_subscription_repository.dart';

class HttpCabinetSubscriptionRepository implements CabinetSubscriptionRepository {
  HttpCabinetSubscriptionRepository({
    required CabinetHttpClient httpClient,
  }) : _httpClient = httpClient;

  final CabinetHttpClient _httpClient;

  @override
  Future<CabinetAppConfig> getAppConfig(CabinetSession session) async {
    final Map<String, Object?> json = await _httpClient.getJson(
      '/cabinet/subscription/app-config',
      bearerToken: session.accessToken,
    );
    return CabinetAppConfig.fromJson(json);
  }

  @override
  Future<CabinetConnectionLink> getConnectionLink(CabinetSession session) async {
    final Map<String, Object?> json = await _httpClient.getJson(
      '/cabinet/subscription/connection-link',
      bearerToken: session.accessToken,
    );
    return CabinetConnectionLink.fromJson(json);
  }

  @override
  Future<CabinetSubscriptionStatus> getSubscriptionStatus(
    CabinetSession session,
  ) async {
    final Map<String, Object?> json = await _httpClient.getJson(
      '/cabinet/subscription',
      bearerToken: session.accessToken,
    );
    return CabinetSubscriptionStatus.fromJson(json);
  }

  @override
  Future<CabinetTrialInfo> getTrialInfo(CabinetSession session) async {
    final Map<String, Object?> json = await _httpClient.getJson(
      '/cabinet/subscription/trial',
      bearerToken: session.accessToken,
    );
    return CabinetTrialInfo.fromJson(json);
  }

  @override
  Future<CabinetTrialActivationResult> activateTrial(
    CabinetSession session,
  ) async {
    final Map<String, Object?> json = await _httpClient.postJson(
      '/cabinet/subscription/trial',
      bearerToken: session.accessToken,
    );
    return CabinetTrialActivationResult.fromJson(json);
  }

  @override
  Future<String?> resolveImportLink(CabinetSession session) async {
    final CabinetConnectionLink connectionLink = await getConnectionLink(
      session,
    );
    final String? resolvedConnectionLink = _sanitizeImportLink(
      connectionLink.subscriptionUrl,
      hideLink: connectionLink.hideLink,
    );
    if (resolvedConnectionLink != null) {
      return resolvedConnectionLink;
    }

    final CabinetAppConfig appConfig = await getAppConfig(session);
    final String? resolvedAppConfigLink = _sanitizeImportLink(
      appConfig.subscriptionUrl,
      hideLink: appConfig.hideLink,
    );
    if (resolvedAppConfigLink != null) {
      return resolvedAppConfigLink;
    }

    final CabinetSubscriptionStatus subscriptionStatus =
        await getSubscriptionStatus(session);
    return _sanitizeImportLink(
      subscriptionStatus.subscriptionUrl,
      hideLink: subscriptionStatus.hideSubscriptionLink,
    );
  }

  String? _sanitizeImportLink(String? value, {required bool hideLink}) {
    if (hideLink) {
      return null;
    }
    final String trimmedValue = (value ?? '').trim();
    if (trimmedValue.isEmpty) {
      return null;
    }
    return trimmedValue;
  }
}
