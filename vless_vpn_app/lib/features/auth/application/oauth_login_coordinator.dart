import 'dart:async';

import '../../cabinet_api/application/cabinet_auth_repository.dart';
import '../../cabinet_api/domain/cabinet_auth_provider.dart';
import '../domain/pending_oauth_request.dart';
import 'auth_platform_bridge.dart';
import 'pending_oauth_request_repository.dart';

class OAuthLoginCoordinator {
  OAuthLoginCoordinator({
    required CabinetAuthRepository authRepository,
    required AuthPlatformBridge platformBridge,
    required PendingOAuthRequestRepository pendingRequestRepository,
  }) : _authRepository = authRepository,
       _platformBridge = platformBridge,
       _pendingRequestRepository = pendingRequestRepository;

  final CabinetAuthRepository _authRepository;
  final AuthPlatformBridge _platformBridge;
  final PendingOAuthRequestRepository _pendingRequestRepository;

  Uri _withMobileAppCallbackMarker(Uri authorizeUri) {
    final String? redirectUriValue = authorizeUri.queryParameters['redirect_uri'];
    if (redirectUriValue == null || redirectUriValue.isEmpty) {
      return authorizeUri;
    }

    final Uri redirectUri = Uri.parse(redirectUriValue);
    final Map<String, String> redirectQuery = <String, String>{
      ...redirectUri.queryParameters,
      'app': '1',
    };

    final Uri markedRedirectUri = redirectUri.replace(queryParameters: redirectQuery);
    final Map<String, String> authorizeQuery = <String, String>{
      ...authorizeUri.queryParameters,
      'redirect_uri': markedRedirectUri.toString(),
    };

    return authorizeUri.replace(queryParameters: authorizeQuery);
  }

  Future<void> start(CabinetAuthProvider provider) async {
    final authorizeResponse = await _authRepository.getOAuthAuthorizeUrl(
      provider.name,
    );
    final Uri expectedAuthorizeUri = _withMobileAppCallbackMarker(
      authorizeResponse.authorizeUrl,
    );
    final String expectedState = authorizeResponse.state;

    await _pendingRequestRepository.save(
      PendingOAuthRequest(provider: provider.name, state: expectedState),
    );
    await _platformBridge.consumePendingCallbackLink();
    await _platformBridge.openExternalUrl(expectedAuthorizeUri);
  }
}
