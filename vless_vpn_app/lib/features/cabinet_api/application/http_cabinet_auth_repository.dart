import '../domain/cabinet_auth_provider.dart';
import '../domain/cabinet_email_auth_config.dart';
import '../domain/cabinet_oauth_authorize_response.dart';
import '../domain/cabinet_oauth_callback_payload.dart';
import '../domain/cabinet_session.dart';
import '../domain/cabinet_user.dart';
import 'cabinet_api_exception.dart';
import 'cabinet_http_client.dart';
import 'cabinet_session_storage.dart';
import 'cabinet_auth_repository.dart';

class HttpCabinetAuthRepository implements CabinetAuthRepository {
  HttpCabinetAuthRepository({
    required CabinetHttpClient httpClient,
    required CabinetSessionStorage sessionStorage,
  }) : _httpClient = httpClient,
       _sessionStorage = sessionStorage;

  final CabinetHttpClient _httpClient;
  final CabinetSessionStorage _sessionStorage;

  @override
  Future<void> clearSession() {
    return _sessionStorage.clear();
  }

  @override
  Future<List<CabinetAuthProvider>> getAvailableAuthProviders() async {
    final Map<String, Object?> json = await _httpClient.getJson(
      '/cabinet/auth/oauth/providers',
    );
    final List<Object?> rawProviders =
        (json['providers'] as List<Object?>?) ?? const <Object?>[];

    return rawProviders
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> item) {
          return CabinetAuthProvider.fromJson(item.cast<String, Object?>());
        })
        .where(
          (CabinetAuthProvider provider) =>
              provider.name.trim().isNotEmpty &&
              provider.displayName.trim().isNotEmpty,
        )
        .toList();
  }

  @override
  Future<CabinetEmailAuthConfig> getEmailAuthConfig() async {
    try {
      final Map<String, Object?> json = await _httpClient.getJson(
        '/cabinet/branding/email-auth',
      );
      return CabinetEmailAuthConfig.fromJson(json);
    } on CabinetApiException {
      return const CabinetEmailAuthConfig(enabled: true);
    }
  }

  @override
  Future<CabinetOAuthAuthorizeResponse> getOAuthAuthorizeUrl(
    String provider,
  ) async {
    final Map<String, Object?> json = await _httpClient.getJson(
      '/cabinet/auth/oauth/${Uri.encodeComponent(provider)}/authorize',
    );
    return CabinetOAuthAuthorizeResponse.fromJson(json);
  }

  @override
  Future<CabinetUser> getCurrentUser(CabinetSession session) async {
    final Map<String, Object?> json = await _httpClient.getJson(
      '/cabinet/auth/me',
      bearerToken: session.accessToken,
    );
    return CabinetUser.fromJson(json);
  }

  @override
  Future<CabinetSession?> loadStoredSession() {
    return _sessionStorage.load();
  }

  @override
  Future<CabinetSession> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final Map<String, Object?> json = await _httpClient.postJson(
      '/cabinet/auth/email/login',
      body: <String, Object?>{'email': email.trim(), 'password': password},
    );
    final CabinetSession session = _sessionFromAuthJson(json);
    await _sessionStorage.save(session);
    return session;
  }

  @override
  Future<CabinetSession> loginWithOAuth({
    required String provider,
    required CabinetOAuthCallbackPayload payload,
  }) async {
    final Map<String, Object?> json = await _httpClient.postJson(
      '/cabinet/auth/oauth/${Uri.encodeComponent(provider)}/callback',
      body: <String, Object?>{
        'code': payload.code,
        'state': payload.state,
        'device_id': payload.deviceId,
        'type': payload.responseType,
      },
    );
    final CabinetSession session = _sessionFromAuthJson(json);
    await _sessionStorage.save(session);
    return session;
  }

  @override
  Future<void> persistSession(CabinetSession session) {
    return _sessionStorage.save(session);
  }

  @override
  Future<CabinetSession?> bootstrapSession() async {
    final CabinetSession? storedSession = await _sessionStorage.load();
    if (storedSession == null) {
      return null;
    }

    if (storedSession.shouldRefreshSoon()) {
      try {
        final CabinetSession refreshedSession = await _refreshSession(
          storedSession.refreshToken,
        );
        await _sessionStorage.save(refreshedSession);
        return refreshedSession;
      } on CabinetUnauthorizedException {
        await _sessionStorage.clear();
        return null;
      } on CabinetApiException {
        return storedSession;
      }
    }

    try {
      await getCurrentUser(storedSession);
      return storedSession;
    } on CabinetUnauthorizedException {
      try {
        final CabinetSession refreshedSession = await _refreshSession(
          storedSession.refreshToken,
        );
        await _sessionStorage.save(refreshedSession);
        return refreshedSession;
      } on CabinetUnauthorizedException {
        await _sessionStorage.clear();
        return null;
      } on CabinetApiException {
        return storedSession;
      }
    } on CabinetApiException {
      return storedSession;
    }
  }

  Future<CabinetSession> _refreshSession(String refreshToken) async {
    final Map<String, Object?> json = await _httpClient.postJson(
      '/cabinet/auth/refresh',
      body: <String, Object?>{'refresh_token': refreshToken},
    );
    return _sessionFromAuthJson(json);
  }

  CabinetSession _sessionFromAuthJson(Map<String, Object?> json) {
    final int expiresInSeconds = (json['expires_in'] as num?)?.toInt() ?? 0;
    return CabinetSession(
      accessToken: (json['access_token'] ?? '') as String,
      refreshToken: (json['refresh_token'] ?? '') as String,
      tokenType: ((json['token_type'] ?? 'bearer') as String).trim(),
      expiresAt: DateTime.now().toUtc().add(
        Duration(seconds: expiresInSeconds),
      ),
    );
  }
}
