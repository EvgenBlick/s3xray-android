enum CabinetPurchaseMode { classic, tariffs }

class CabinetPurchaseOptions {
  const CabinetPurchaseOptions({
    required this.mode,
    required this.balanceKopeks,
    required this.balanceLabel,
    this.currentTariffId,
    this.hasSubscription,
    this.subscriptionStatus,
    this.subscriptionIsExpired,
    this.tariffs = const <CabinetTariffOption>[],
    this.classic,
  });

  final CabinetPurchaseMode mode;
  final int balanceKopeks;
  final String balanceLabel;
  final int? currentTariffId;
  final bool? hasSubscription;
  final String? subscriptionStatus;
  final bool? subscriptionIsExpired;
  final List<CabinetTariffOption> tariffs;
  final CabinetClassicPurchaseOptions? classic;

  bool get isTariffsMode => mode == CabinetPurchaseMode.tariffs;

  factory CabinetPurchaseOptions.fromJson(Map<String, Object?> json) {
    final String salesMode = (json['sales_mode'] as String? ?? 'classic')
        .trim();
    if (salesMode == 'tariffs') {
      final List<Object?> rawTariffs =
          (json['tariffs'] as List<Object?>?) ?? const <Object?>[];
      return CabinetPurchaseOptions(
        mode: CabinetPurchaseMode.tariffs,
        balanceKopeks: (json['balance_kopeks'] as num?)?.toInt() ?? 0,
        balanceLabel: (json['balance_label'] as String? ?? '').trim(),
        currentTariffId: (json['current_tariff_id'] as num?)?.toInt(),
        hasSubscription: json['has_subscription'] as bool?,
        subscriptionStatus: json['subscription_status'] as String?,
        subscriptionIsExpired: json['subscription_is_expired'] as bool?,
        tariffs: rawTariffs
            .whereType<Map<Object?, Object?>>()
            .map(
              (Map<Object?, Object?> item) =>
                  CabinetTariffOption.fromJson(item.cast<String, Object?>()),
            )
            .toList(),
      );
    }

    return CabinetPurchaseOptions(
      mode: CabinetPurchaseMode.classic,
      balanceKopeks: (json['balance_kopeks'] as num?)?.toInt() ?? 0,
      balanceLabel: (json['balance_label'] as String? ?? '').trim(),
      classic: CabinetClassicPurchaseOptions.fromJson(json),
    );
  }
}

class CabinetTariffOption {
  const CabinetTariffOption({
    required this.id,
    required this.name,
    required this.description,
    required this.trafficLimitGb,
    required this.trafficLimitLabel,
    required this.isUnlimitedTraffic,
    required this.deviceLimit,
    required this.baseDeviceLimit,
    required this.maxDeviceLimit,
    required this.extraDevicesCount,
    required this.devicePriceKopeks,
    required this.isCurrent,
    required this.isAvailable,
    required this.isDaily,
    required this.periods,
  });

  final int id;
  final String name;
  final String? description;
  final int trafficLimitGb;
  final String trafficLimitLabel;
  final bool isUnlimitedTraffic;
  final int deviceLimit;
  final int baseDeviceLimit;
  final int? maxDeviceLimit;
  final int extraDevicesCount;
  final int devicePriceKopeks;
  final bool isCurrent;
  final bool isAvailable;
  final bool isDaily;
  final List<CabinetTariffPeriodOption> periods;

  factory CabinetTariffOption.fromJson(Map<String, Object?> json) {
    final List<Object?> rawPeriods =
        (json['periods'] as List<Object?>?) ?? const <Object?>[];
    return CabinetTariffOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String? ?? '').trim(),
      description: json['description'] as String?,
      trafficLimitGb: (json['traffic_limit_gb'] as num?)?.toInt() ?? 0,
      trafficLimitLabel: (json['traffic_limit_label'] as String? ?? '').trim(),
      isUnlimitedTraffic: json['is_unlimited_traffic'] == true,
      deviceLimit: (json['device_limit'] as num?)?.toInt() ?? 1,
      baseDeviceLimit: (json['base_device_limit'] as num?)?.toInt() ?? 1,
      maxDeviceLimit: (json['max_device_limit'] as num?)?.toInt(),
      extraDevicesCount: (json['extra_devices_count'] as num?)?.toInt() ?? 0,
      devicePriceKopeks: (json['device_price_kopeks'] as num?)?.toInt() ?? 0,
      isCurrent: json['is_current'] == true,
      isAvailable: json['is_available'] == true,
      isDaily: json['is_daily'] == true,
      periods: rawPeriods
          .whereType<Map<Object?, Object?>>()
          .map(
            (Map<Object?, Object?> item) => CabinetTariffPeriodOption.fromJson(
              item.cast<String, Object?>(),
            ),
          )
          .toList(),
    );
  }
}

class CabinetTariffPeriodOption {
  const CabinetTariffPeriodOption({
    required this.days,
    required this.months,
    required this.label,
    required this.priceKopeks,
    required this.priceLabel,
    this.pricePerMonthKopeks,
    required this.pricePerMonthLabel,
    this.extraDevicesCount,
    this.extraDevicesCostKopeks,
    this.baseTariffPriceKopeks,
    this.originalPriceKopeks,
    this.originalPriceLabel,
    this.originalPerMonthKopeks,
    this.originalPerMonthLabel,
    this.discountPercent,
    this.discountLabel,
  });

  final int days;
  final int months;
  final String label;
  final int priceKopeks;
  final String priceLabel;
  final int? pricePerMonthKopeks;
  final String pricePerMonthLabel;
  final int? extraDevicesCount;
  final int? extraDevicesCostKopeks;
  final int? baseTariffPriceKopeks;
  final int? originalPriceKopeks;
  final String? originalPriceLabel;
  final int? originalPerMonthKopeks;
  final String? originalPerMonthLabel;
  final int? discountPercent;
  final String? discountLabel;

  factory CabinetTariffPeriodOption.fromJson(Map<String, Object?> json) {
    return CabinetTariffPeriodOption(
      days: (json['days'] as num?)?.toInt() ?? 0,
      months: (json['months'] as num?)?.toInt() ?? 0,
      label: (json['label'] as String? ?? '').trim(),
      priceKopeks: (json['price_kopeks'] as num?)?.toInt() ?? 0,
      priceLabel: (json['price_label'] as String? ?? '').trim(),
      pricePerMonthKopeks: (json['price_per_month_kopeks'] as num?)?.toInt(),
      pricePerMonthLabel: (json['price_per_month_label'] as String? ?? '')
          .trim(),
      extraDevicesCount: (json['extra_devices_count'] as num?)?.toInt(),
      extraDevicesCostKopeks: (json['extra_devices_cost_kopeks'] as num?)
          ?.toInt(),
      baseTariffPriceKopeks: (json['base_tariff_price_kopeks'] as num?)
          ?.toInt(),
      originalPriceKopeks: (json['original_price_kopeks'] as num?)?.toInt(),
      originalPriceLabel: (json['original_price_label'] as String?)?.trim(),
      originalPerMonthKopeks: (json['original_per_month_kopeks'] as num?)
          ?.toInt(),
      originalPerMonthLabel: (json['original_per_month_label'] as String?)
          ?.trim(),
      discountPercent: (json['discount_percent'] as num?)?.toInt(),
      discountLabel: (json['discount_label'] as String?)?.trim(),
    );
  }
}

class CabinetClassicPurchaseOptions {
  const CabinetClassicPurchaseOptions({
    required this.subscriptionId,
    required this.periods,
    required this.selection,
  });

  final int? subscriptionId;
  final List<CabinetClassicPeriodOption> periods;
  final CabinetClassicSelection selection;

  factory CabinetClassicPurchaseOptions.fromJson(Map<String, Object?> json) {
    final List<Object?> rawPeriods =
        (json['periods'] as List<Object?>?) ?? const <Object?>[];
    return CabinetClassicPurchaseOptions(
      subscriptionId: (json['subscription_id'] as num?)?.toInt(),
      periods: rawPeriods
          .whereType<Map<Object?, Object?>>()
          .map(
            (Map<Object?, Object?> item) => CabinetClassicPeriodOption.fromJson(
              item.cast<String, Object?>(),
            ),
          )
          .toList(),
      selection: CabinetClassicSelection.fromJson(
        (json['selection'] as Map<Object?, Object?>? ??
                const <Object?, Object?>{})
            .cast<String, Object?>(),
      ),
    );
  }
}

class CabinetClassicPeriodOption {
  const CabinetClassicPeriodOption({
    required this.id,
    required this.periodDays,
    required this.label,
    required this.priceLabel,
    required this.isAvailable,
    required this.defaultTrafficValue,
    required this.defaultServers,
    required this.defaultDevices,
  });

  final String id;
  final int periodDays;
  final String label;
  final String priceLabel;
  final bool isAvailable;
  final int defaultTrafficValue;
  final List<String> defaultServers;
  final int defaultDevices;

  factory CabinetClassicPeriodOption.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> traffic =
        (json['traffic'] as Map<Object?, Object?>? ??
                const <Object?, Object?>{})
            .cast<String, Object?>();
    final Map<String, Object?> servers =
        (json['servers'] as Map<Object?, Object?>? ??
                const <Object?, Object?>{})
            .cast<String, Object?>();
    final Map<String, Object?> devices =
        (json['devices'] as Map<Object?, Object?>? ??
                const <Object?, Object?>{})
            .cast<String, Object?>();
    final List<Object?> rawServerSelection =
        (servers['selected'] as List<Object?>?) ??
        (servers['default'] as List<Object?>?) ??
        const <Object?>[];

    return CabinetClassicPeriodOption(
      id: (json['id'] as String? ?? '').trim(),
      periodDays: (json['period_days'] as num?)?.toInt() ?? 0,
      label: (json['label'] as String? ?? '').trim(),
      priceLabel: (json['price_label'] as String? ?? '').trim(),
      isAvailable: json['is_available'] == true,
      defaultTrafficValue:
          (traffic['current'] as num?)?.toInt() ??
          (traffic['default'] as num?)?.toInt() ??
          0,
      defaultServers: rawServerSelection
          .whereType<String>()
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .toList(),
      defaultDevices:
          (devices['current'] as num?)?.toInt() ??
          (devices['default'] as num?)?.toInt() ??
          1,
    );
  }
}

class CabinetClassicSelection {
  const CabinetClassicSelection({
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

  factory CabinetClassicSelection.fromJson(Map<String, Object?> json) {
    final List<Object?> rawServers =
        (json['servers'] as List<Object?>?) ?? const <Object?>[];
    return CabinetClassicSelection(
      periodId: (json['period_id'] as String? ?? '').trim(),
      periodDays: (json['period_days'] as num?)?.toInt() ?? 0,
      trafficValue: (json['traffic_value'] as num?)?.toInt() ?? 0,
      servers: rawServers
          .whereType<String>()
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .toList(),
      devices: (json['devices'] as num?)?.toInt() ?? 1,
    );
  }
}
