class LocalAppInfo {
  const LocalAppInfo({
    required this.packageName,
    required this.versionName,
    required this.versionCode,
  });

  factory LocalAppInfo.fromJson(Map<Object?, Object?> json) {
    final Object? packageNameValue = json['packageName'];
    final Object? versionNameValue = json['versionName'];
    final Object? versionCodeValue = json['versionCode'];

    if (packageNameValue is! String ||
        versionNameValue is! String ||
        versionCodeValue is! num) {
      throw const FormatException('invalid_local_app_info');
    }

    return LocalAppInfo(
      packageName: packageNameValue,
      versionName: versionNameValue,
      versionCode: versionCodeValue.toInt(),
    );
  }

  final String packageName;
  final String versionName;
  final int versionCode;
}
