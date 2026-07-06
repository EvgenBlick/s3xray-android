import '../domain/cabinet_auth_provider.dart';
import '../domain/cabinet_email_auth_config.dart';
import '../domain/cabinet_oauth_authorize_response.dart';
import '../domain/cabinet_oauth_callback_payload.dart';
import '../domain/cabinet_session.dart';
import '../domain/cabinet_user.dart';

abstract class CabinetAuthRepository {
  Future<CabinetSession?> loadStoredSession();

  Future<CabinetSession?> bootstrapSession();

  Future<void> persistSession(CabinetSession session);

  Future<void> clearSession();

  Future<CabinetUser> getCurrentUser(CabinetSession session);

  Future<List<CabinetAuthProvider>> getAvailableAuthProviders();

  Future<CabinetEmailAuthConfig> getEmailAuthConfig();

  Future<CabinetOAuthAuthorizeResponse> getOAuthAuthorizeUrl(String provider);

  Future<CabinetSession> loginWithEmail({
    required String email,
    required String password,
  });

  Future<CabinetSession> loginWithOAuth({
    required String provider,
    required CabinetOAuthCallbackPayload payload,
  });
}
