class CabinetOAuthAuthorizeResponse {
  const CabinetOAuthAuthorizeResponse({
    required this.authorizeUrl,
    required this.state,
  });

  final Uri authorizeUrl;
  final String state;

  factory CabinetOAuthAuthorizeResponse.fromJson(Map<String, Object?> json) {
    return CabinetOAuthAuthorizeResponse(
      authorizeUrl: Uri.parse((json['authorize_url'] ?? '') as String),
      state: ((json['state'] ?? '') as String).trim(),
    );
  }
}
