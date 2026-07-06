class SplitTunnelApp {
  const SplitTunnelApp({
    required this.packageName,
    required this.label,
    required this.isSystemApp,
  });

  final String packageName;
  final String label;
  final bool isSystemApp;

  factory SplitTunnelApp.fromMap(Map<Object?, Object?> map) {
    return SplitTunnelApp(
      packageName: map['packageName']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      isSystemApp: map['isSystemApp'] == true,
    );
  }
}
