class CabinetAuthProvider {
  const CabinetAuthProvider({
    required this.name,
    required this.displayName,
  });

  final String name;
  final String displayName;

  factory CabinetAuthProvider.fromJson(Map<String, Object?> json) {
    return CabinetAuthProvider(
      name: (json['name'] ?? '') as String,
      displayName: (json['display_name'] ?? '') as String,
    );
  }
}
