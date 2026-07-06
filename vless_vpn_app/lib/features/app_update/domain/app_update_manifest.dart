class AppUpdateManifest {
  const AppUpdateManifest({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.checksumSha256,
    this.changelog,
    this.forceUpdate = false,
    this.publishedAt,
  });

  factory AppUpdateManifest.fromJson(
    Map<String, Object?> json, {
    required Uri sourceUri,
  }) {
    final Object? versionCodeValue = json['versionCode'];
    final Object? versionNameValue = json['versionName'];
    final Object? apkUrlValue = json['apkUrl'];
    final Object? checksumValue = json['checksumSha256'];

    if (versionCodeValue is! num) {
      throw const FormatException('versionCode_is_required');
    }
    if (versionNameValue is! String || versionNameValue.trim().isEmpty) {
      throw const FormatException('versionName_is_required');
    }
    if (apkUrlValue is! String || apkUrlValue.trim().isEmpty) {
      throw const FormatException('apkUrl_is_required');
    }
    if (checksumValue is! String || checksumValue.trim().isEmpty) {
      throw const FormatException('checksumSha256_is_required');
    }

    final Uri apkUri = sourceUri.resolve(apkUrlValue.trim());
    if (!_isSecureHttpsUri(sourceUri) || !_isSecureHttpsUri(apkUri)) {
      throw const FormatException('update_manifest_requires_https');
    }
    final String? changelog = _readOptionalString(json['changelog']);
    final String checksumSha256 = checksumValue.trim().toLowerCase();
    if (!_isValidSha256(checksumSha256)) {
      throw const FormatException('checksumSha256_must_be_64_char_hex');
    }
    final String? publishedAtValue = _readOptionalString(json['publishedAt']);

    return AppUpdateManifest(
      versionCode: versionCodeValue.toInt(),
      versionName: versionNameValue.trim(),
      apkUrl: apkUri,
      changelog: changelog,
      forceUpdate: json['forceUpdate'] == true,
      checksumSha256: checksumSha256,
      publishedAt: publishedAtValue == null
          ? null
          : DateTime.tryParse(publishedAtValue)?.toUtc(),
    );
  }

  final int versionCode;
  final String versionName;
  final Uri apkUrl;
  final String checksumSha256;
  final String? changelog;
  final bool forceUpdate;
  final DateTime? publishedAt;
}

bool _isSecureHttpsUri(Uri uri) => uri.scheme == 'https';
bool _isValidSha256(String value) =>
    RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

String? _readOptionalString(Object? value) {
  if (value is! String) {
    return null;
  }

  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
