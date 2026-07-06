class CabinetEmailAuthConfig {
  const CabinetEmailAuthConfig({
    required this.enabled,
  });

  final bool enabled;

  factory CabinetEmailAuthConfig.fromJson(Map<String, Object?> json) {
    return CabinetEmailAuthConfig(
      enabled: json['enabled'] == true,
    );
  }
}
