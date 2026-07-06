class CabinetUser {
  const CabinetUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.balanceKopeks,
    required this.language,
  });

  final int id;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? username;
  final int balanceKopeks;
  final String language;

  factory CabinetUser.fromJson(Map<String, Object?> json) {
    return CabinetUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      username: json['username'] as String?,
      balanceKopeks: (json['balance_kopeks'] as num?)?.toInt() ?? 0,
      language: (json['language'] as String?)?.trim().isNotEmpty == true
          ? json['language'] as String
          : 'ru',
    );
  }
}
