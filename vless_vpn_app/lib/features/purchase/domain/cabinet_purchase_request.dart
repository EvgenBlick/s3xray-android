class CabinetClassicPurchaseRequest {
  const CabinetClassicPurchaseRequest({
    required this.periodId,
    required this.periodDays,
    required this.trafficValue,
    required this.servers,
    required this.devices,
  });

  final String periodId;
  final int periodDays;
  final int trafficValue;
  final List<String> servers;
  final int devices;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'selection': <String, Object?>{
        'period_id': periodId,
        'period_days': periodDays,
        'traffic_value': trafficValue,
        'servers': servers,
        'devices': devices,
      },
    };
  }
}

class CabinetTariffPurchaseRequest {
  const CabinetTariffPurchaseRequest({
    required this.tariffId,
    required this.periodDays,
    this.trafficGb,
    this.deviceLimit,
  });

  final int tariffId;
  final int periodDays;
  final int? trafficGb;
  final int? deviceLimit;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'tariff_id': tariffId,
      'period_days': periodDays,
      if (trafficGb != null) 'traffic_gb': trafficGb,
      if (deviceLimit != null) 'device_limit': deviceLimit,
    };
  }
}
