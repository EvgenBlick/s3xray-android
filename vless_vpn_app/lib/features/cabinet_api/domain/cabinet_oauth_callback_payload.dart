class CabinetOAuthCallbackPayload {
  const CabinetOAuthCallbackPayload({
    required this.code,
    required this.state,
    this.deviceId,
    this.responseType,
  });

  final String code;
  final String state;
  final String? deviceId;
  final String? responseType;

  factory CabinetOAuthCallbackPayload.fromUri(Uri uri) {
    return CabinetOAuthCallbackPayload(
      code: (uri.queryParameters['code'] ?? '').trim(),
      state: (uri.queryParameters['state'] ?? '').trim(),
      deviceId: uri.queryParameters['device_id']?.trim(),
      responseType: uri.queryParameters['type']?.trim(),
    );
  }

  bool get isValid => code.isNotEmpty && state.isNotEmpty;
}
