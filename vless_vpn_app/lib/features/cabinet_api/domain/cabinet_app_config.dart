class CabinetAppConfig {
  const CabinetAppConfig({
    required this.hasSubscription,
    required this.subscriptionUrl,
    required this.hideLink,
    required this.brandingName,
    required this.supportUrl,
  });

  final bool hasSubscription;
  final String? subscriptionUrl;
  final bool hideLink;
  final String? brandingName;
  final String? supportUrl;

  factory CabinetAppConfig.fromJson(Map<String, Object?> json) {
    final Map<String, Object?>? branding =
        json['branding'] as Map<String, Object?>?;

    return CabinetAppConfig(
      hasSubscription: json['hasSubscription'] == true,
      subscriptionUrl: json['subscriptionUrl'] as String?,
      hideLink: json['hideLink'] == true,
      brandingName: branding?['name'] as String?,
      supportUrl: branding?['supportUrl'] as String?,
    );
  }
}
