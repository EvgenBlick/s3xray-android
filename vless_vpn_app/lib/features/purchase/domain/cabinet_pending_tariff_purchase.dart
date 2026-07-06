class CabinetPendingTariffPurchase {
  const CabinetPendingTariffPurchase({
    required this.tariffId,
    required this.periodDays,
    this.deviceLimit,
    required this.createdAtMillis,
  });

  final int tariffId;
  final int periodDays;
  final int? deviceLimit;
  final int createdAtMillis;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'tariffId': tariffId,
      'periodDays': periodDays,
      if (deviceLimit != null) 'deviceLimit': deviceLimit,
      'createdAtMillis': createdAtMillis,
    };
  }

  factory CabinetPendingTariffPurchase.fromJson(Map<String, Object?> json) {
    return CabinetPendingTariffPurchase(
      tariffId: (json['tariffId'] as num?)?.toInt() ?? 0,
      periodDays: (json['periodDays'] as num?)?.toInt() ?? 0,
      deviceLimit: (json['deviceLimit'] as num?)?.toInt(),
      createdAtMillis: (json['createdAtMillis'] as num?)?.toInt() ?? 0,
    );
  }
}
