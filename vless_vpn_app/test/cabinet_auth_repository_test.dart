import 'package:flutter_test/flutter_test.dart';
import 'package:vless_vpn_app/features/cabinet_api/application/cabinet_api_exception.dart';
import 'package:vless_vpn_app/features/cabinet_api/application/cabinet_http_client.dart';
import 'package:vless_vpn_app/features/cabinet_api/application/cabinet_session_storage.dart';
import 'package:vless_vpn_app/features/cabinet_api/application/http_cabinet_auth_repository.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_session.dart';

void main() {
  group('HttpCabinetAuthRepository.bootstrapSession', () {
    test('preserves stored session on transient refresh failure', () async {
      final CabinetSession expiredSession = CabinetSession(
        accessToken: 'access-old',
        refreshToken: 'refresh-old',
        tokenType: 'bearer',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      );
      final _FakeSessionStorage storage = _FakeSessionStorage(expiredSession);
      final HttpCabinetAuthRepository repository = HttpCabinetAuthRepository(
        httpClient: _FakeCabinetHttpClient(
          postHandler:
              (String path, Map<String, Object?> body, String? token) async {
                expect(path, '/cabinet/auth/refresh');
                throw const CabinetApiException('Network error: timeout');
              },
        ),
        sessionStorage: storage,
      );

      final CabinetSession? session = await repository.bootstrapSession();

      expect(session, isNotNull);
      expect(session!.accessToken, expiredSession.accessToken);
      expect(storage.cleared, isFalse);
    });

    test('clears stored session when refresh token is rejected', () async {
      final CabinetSession expiredSession = CabinetSession(
        accessToken: 'access-old',
        refreshToken: 'refresh-old',
        tokenType: 'bearer',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      );
      final _FakeSessionStorage storage = _FakeSessionStorage(expiredSession);
      final HttpCabinetAuthRepository repository = HttpCabinetAuthRepository(
        httpClient: _FakeCabinetHttpClient(
          postHandler:
              (String path, Map<String, Object?> body, String? token) async {
                throw const CabinetUnauthorizedException();
              },
        ),
        sessionStorage: storage,
      );

      final CabinetSession? session = await repository.bootstrapSession();

      expect(session, isNull);
      expect(storage.cleared, isTrue);
    });

    test('refreshes slightly before expiry to avoid forced re-login', () async {
      final CabinetSession nearExpirySession = CabinetSession(
        accessToken: 'access-old',
        refreshToken: 'refresh-old',
        tokenType: 'bearer',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 3)),
      );
      final _FakeSessionStorage storage = _FakeSessionStorage(
        nearExpirySession,
      );
      final HttpCabinetAuthRepository repository = HttpCabinetAuthRepository(
        httpClient: _FakeCabinetHttpClient(
          postHandler:
              (String path, Map<String, Object?> body, String? token) async {
                return <String, Object?>{
                  'access_token': 'access-new',
                  'refresh_token': 'refresh-new',
                  'token_type': 'bearer',
                  'expires_in': 3600,
                };
              },
        ),
        sessionStorage: storage,
      );

      final CabinetSession? session = await repository.bootstrapSession();

      expect(session, isNotNull);
      expect(session!.accessToken, 'access-new');
      expect(storage.saved?.accessToken, 'access-new');
      expect(storage.cleared, isFalse);
    });
  });
}

class _FakeSessionStorage implements CabinetSessionStorage {
  _FakeSessionStorage(this._session);

  CabinetSession? _session;
  CabinetSession? saved;
  bool cleared = false;

  @override
  Future<void> clear() async {
    cleared = true;
    _session = null;
  }

  @override
  Future<CabinetSession?> load() async => _session;

  @override
  Future<void> save(CabinetSession session) async {
    saved = session;
    _session = session;
  }
}

class _FakeCabinetHttpClient extends CabinetHttpClient {
  _FakeCabinetHttpClient({this.postHandler})
    : super(baseUri: Uri.parse('https://example.com'));

  final Future<Map<String, Object?>> Function(
    String path,
    Map<String, Object?> body,
    String? bearerToken,
  )?
  postHandler;

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    String? bearerToken,
    Map<String, Object?> body = const <String, Object?>{},
  }) async {
    if (postHandler == null) {
      throw UnimplementedError('postJson not configured for $path');
    }
    return postHandler!(path, body, bearerToken);
  }
}
