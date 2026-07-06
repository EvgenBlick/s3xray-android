class SupportConfig {
  const SupportConfig({
    required this.ticketsEnabled,
    required this.supportType,
    this.supportUrl,
    this.supportUsername,
  });

  final bool ticketsEnabled;
  final String supportType;
  final String? supportUrl;
  final String? supportUsername;

  bool get usesTickets =>
      ticketsEnabled && supportType.trim().toLowerCase() == 'tickets';

  factory SupportConfig.fromJson(Map<String, Object?> json) {
    return SupportConfig(
      ticketsEnabled: json['tickets_enabled'] == true,
      supportType: (json['support_type'] as String? ?? 'profile').trim(),
      supportUrl: json['support_url'] as String?,
      supportUsername: json['support_username'] as String?,
    );
  }
}
