class CabinetTopUpPayment {
  const CabinetTopUpPayment({
    required this.paymentId,
    required this.paymentUrl,
    required this.amountKopeks,
    required this.amountRubles,
    required this.status,
    required this.paymentMethodId,
    required this.paymentMethodName,
  });

  final String paymentId;
  final Uri paymentUrl;
  final int amountKopeks;
  final double amountRubles;
  final String status;
  final String paymentMethodId;
  final String paymentMethodName;

  factory CabinetTopUpPayment.fromJson(
    Map<String, Object?> json, {
    required String paymentMethodId,
    required String paymentMethodName,
  }) {
    return CabinetTopUpPayment(
      paymentId: (json['payment_id'] as String? ?? '').trim(),
      paymentUrl: Uri.parse((json['payment_url'] as String? ?? '').trim()),
      amountKopeks: (json['amount_kopeks'] as num?)?.toInt() ?? 0,
      amountRubles: (json['amount_rubles'] as num?)?.toDouble() ?? 0,
      status: (json['status'] as String? ?? '').trim(),
      paymentMethodId: paymentMethodId,
      paymentMethodName: paymentMethodName,
    );
  }
}
