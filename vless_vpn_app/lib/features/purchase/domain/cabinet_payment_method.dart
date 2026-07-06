class CabinetPaymentMethodOption {
  const CabinetPaymentMethodOption({
    required this.id,
    required this.name,
    this.description,
  });

  final String id;
  final String name;
  final String? description;

  factory CabinetPaymentMethodOption.fromJson(Map<String, Object?> json) {
    return CabinetPaymentMethodOption(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      description: (json['description'] as String?)?.trim(),
    );
  }
}

class CabinetPaymentMethod {
  const CabinetPaymentMethod({
    required this.id,
    required this.name,
    required this.description,
    required this.minAmountKopeks,
    required this.maxAmountKopeks,
    required this.isAvailable,
    required this.isDefaultForSubscription,
    required this.options,
  });

  final String id;
  final String name;
  final String? description;
  final int minAmountKopeks;
  final int maxAmountKopeks;
  final bool isAvailable;
  final bool isDefaultForSubscription;
  final List<CabinetPaymentMethodOption> options;

  factory CabinetPaymentMethod.fromJson(Map<String, Object?> json) {
    final List<Object?> rawOptions =
        (json['options'] as List<Object?>?) ?? const <Object?>[];
    return CabinetPaymentMethod(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      description: (json['description'] as String?)?.trim(),
      minAmountKopeks: (json['min_amount_kopeks'] as num?)?.toInt() ?? 1,
      maxAmountKopeks: (json['max_amount_kopeks'] as num?)?.toInt() ?? 0,
      isAvailable: json['is_available'] == true,
      isDefaultForSubscription: json['is_default_for_subscription'] == true,
      options: rawOptions
          .whereType<Map<Object?, Object?>>()
          .map(
            (Map<Object?, Object?> item) => CabinetPaymentMethodOption.fromJson(
              item.cast<String, Object?>(),
            ),
          )
          .toList(),
    );
  }
}
