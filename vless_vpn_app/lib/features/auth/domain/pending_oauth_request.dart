class PendingOAuthRequest {
  const PendingOAuthRequest({
    required this.provider,
    required this.state,
  });

  final String provider;
  final String state;
}
