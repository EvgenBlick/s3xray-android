class CabinetTrialInfo {
  const CabinetTrialInfo({
    required this.isAvailable,
    required this.durationDays,
    required this.trafficLimitGb,
    required this.deviceLimit,
    required this.requiresPayment,
    required this.priceKopeks,
    required this.priceRubles,
    required this.reasonUnavailable,
  });

  final bool isAvailable;
  final int durationDays;
  final int trafficLimitGb;
  final int deviceLimit;
  final bool requiresPayment;
  final int priceKopeks;
  final double priceRubles;
  final String? reasonUnavailable;

  factory CabinetTrialInfo.fromJson(Map<String, Object?> json) {
    return CabinetTrialInfo(
      isAvailable: json['is_available'] == true,
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 0,
      trafficLimitGb: (json['traffic_limit_gb'] as num?)?.toInt() ?? 0,
      deviceLimit: (json['device_limit'] as num?)?.toInt() ?? 0,
      requiresPayment: json['requires_payment'] == true,
      priceKopeks: (json['price_kopeks'] as num?)?.toInt() ?? 0,
      priceRubles: (json['price_rubles'] as num?)?.toDouble() ?? 0,
      reasonUnavailable: json['reason_unavailable'] as String?,
    );
  }
}
