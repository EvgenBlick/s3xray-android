class CabinetPurchasePreview {
  const CabinetPurchasePreview({
    required this.totalPriceLabel,
    required this.perMonthPriceLabel,
    required this.balanceLabel,
    required this.canPurchase,
    this.missingAmountLabel,
    this.statusMessage,
  });

  final String totalPriceLabel;
  final String perMonthPriceLabel;
  final String balanceLabel;
  final bool canPurchase;
  final String? missingAmountLabel;
  final String? statusMessage;

  factory CabinetPurchasePreview.fromJson(Map<String, Object?> json) {
    return CabinetPurchasePreview(
      totalPriceLabel: (json['total_price_label'] as String? ?? '').trim(),
      perMonthPriceLabel: (json['per_month_price_label'] as String? ?? '').trim(),
      balanceLabel: (json['balance_label'] as String? ?? '').trim(),
      canPurchase: json['can_purchase'] == true,
      missingAmountLabel: json['missing_amount_label'] as String?,
      statusMessage: json['status_message'] as String?,
    );
  }
}
