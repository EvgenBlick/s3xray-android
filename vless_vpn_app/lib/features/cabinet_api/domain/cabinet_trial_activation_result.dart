class CabinetTrialActivationResult {
  const CabinetTrialActivationResult({
    required this.isTrial,
    required this.isActive,
  });

  final bool isTrial;
  final bool isActive;

  factory CabinetTrialActivationResult.fromJson(Map<String, Object?> json) {
    return CabinetTrialActivationResult(
      isTrial: json['is_trial'] == true,
      isActive: json['is_active'] == true,
    );
  }
}
