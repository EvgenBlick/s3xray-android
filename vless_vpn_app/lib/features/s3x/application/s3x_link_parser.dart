import 'dart:convert';

class S3xProfile {
  const S3xProfile({required this.remark, required this.runtimeConfig});

  final String remark;
  final String runtimeConfig;
}

class S3xLinkParser {
  const S3xLinkParser();

  S3xProfile parse(String rawLink) {
    final Uri uri = Uri.parse(rawLink.trim());
    if (uri.scheme != 's3x') {
      throw const FormatException('Unsupported S3X scheme');
    }

    final String payload = _extractPayload(uri, rawLink);
    final String decoded = utf8.decode(base64Url.decode(_normalize(payload)));
    final Object? parsed = jsonDecode(decoded);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('S3X payload must be a JSON object');
    }

    final Map<String, dynamic> config = Map<String, dynamic>.from(parsed);
    final String remark = _extractRemark(config);
    config.putIfAbsent('log', () => <String, dynamic>{'loglevel': 'info'});
    if (config['outbounds'] is! List) {
      throw const FormatException('S3X config must contain outbounds');
    }

    return S3xProfile(remark: remark, runtimeConfig: jsonEncode(config));
  }

  String _extractPayload(Uri uri, String rawLink) {
    final String? queryPayload =
        uri.queryParameters['data'] ?? uri.queryParameters['config'];
    if (queryPayload != null && queryPayload.trim().isNotEmpty) {
      return queryPayload.trim();
    }

    final String withoutScheme = rawLink.trim().replaceFirst('s3x://', '');
    final int queryIndex = withoutScheme.indexOf('?');
    final String payload = queryIndex >= 0
        ? withoutScheme.substring(0, queryIndex)
        : withoutScheme;
    return payload.replaceAll('/', '').trim();
  }

  String _normalize(String payload) {
    final String cleaned = payload.replaceAll(RegExp(r'\s+'), '');
    final int padding = cleaned.length % 4;
    if (padding == 0) {
      return cleaned;
    }
    return cleaned.padRight(cleaned.length + 4 - padding, '=');
  }

  String _extractRemark(Map<String, dynamic> config) {
    final Object? explicitRemark =
        config['remark'] ?? config['remarks'] ?? config['name'];
    final String remark = '$explicitRemark'.trim();
    if (remark.isNotEmpty && remark != 'null') {
      return remark;
    }
    return 'S3XRAY';
  }
}
