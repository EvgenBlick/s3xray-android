class CabinetSubscriptionStatus {
  const CabinetSubscriptionStatus({
    required this.hasSubscription,
    required this.subscriptionUrl,
    required this.hideSubscriptionLink,
    required this.isActive,
    required this.daysLeft,
    required this.timeLeftDisplay,
    required this.trafficUsedGb,
    required this.trafficLimitGb,
    required this.deviceLimit,
  });

  final bool hasSubscription;
  final String? subscriptionUrl;
  final bool hideSubscriptionLink;
  final bool isActive;
  final int daysLeft;
  final String? timeLeftDisplay;
  final double? trafficUsedGb;
  final double? trafficLimitGb;
  final int? deviceLimit;

  factory CabinetSubscriptionStatus.fromJson(Map<String, Object?> json) {
    final Map<String, Object?>? subscription =
        json['subscription'] as Map<String, Object?>?;

    return CabinetSubscriptionStatus(
      hasSubscription: json['has_subscription'] == true,
      subscriptionUrl: subscription?['subscription_url'] as String?,
      hideSubscriptionLink: subscription?['hide_subscription_link'] == true,
      isActive: subscription?['is_active'] == true,
      daysLeft: (subscription?['days_left'] as num?)?.toInt() ?? 0,
      timeLeftDisplay: subscription?['time_left_display'] as String?,
      trafficUsedGb: (subscription?['traffic_used_gb'] as num?)?.toDouble(),
      trafficLimitGb: (subscription?['traffic_limit_gb'] as num?)?.toDouble(),
      deviceLimit: (subscription?['device_limit'] as num?)?.toInt(),
    );
  }
}
