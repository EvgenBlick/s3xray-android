class CabinetPurchaseResult {
  const CabinetPurchaseResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;

  factory CabinetPurchaseResult.fromJson(Map<String, Object?> json) {
    return CabinetPurchaseResult(
      success: json['success'] != false,
      message: (json['message'] as String? ?? '').trim(),
    );
  }
}
