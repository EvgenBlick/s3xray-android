class CabinetSession {
  static const Duration refreshLeeway = Duration(minutes: 5);

  const CabinetSession({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final DateTime expiresAt;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());

  bool shouldRefreshSoon([Duration leeway = refreshLeeway]) {
    return !expiresAt.isAfter(DateTime.now().toUtc().add(leeway));
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'tokenType': tokenType,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
    };
  }

  factory CabinetSession.fromMap(Map<Object?, Object?> map) {
    return CabinetSession(
      accessToken: (map['accessToken'] ?? '') as String,
      refreshToken: (map['refreshToken'] ?? '') as String,
      tokenType: ((map['tokenType'] ?? 'bearer') as String).trim(),
      expiresAt: DateTime.parse((map['expiresAt'] ?? '') as String).toUtc(),
    );
  }

  CabinetSession copyWith({
    String? accessToken,
    String? refreshToken,
    String? tokenType,
    DateTime? expiresAt,
  }) {
    return CabinetSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenType: tokenType ?? this.tokenType,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
