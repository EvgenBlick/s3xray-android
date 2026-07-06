import 'vless_profile.dart';

enum VlessParseError {
  emptyLink,
  invalidScheme,
  missingUuid,
  missingEndpoint,
}

class VlessParseResult {
  const VlessParseResult({
    this.profile,
    this.error,
  });

  final VlessProfile? profile;
  final VlessParseError? error;
}

class VlessUriParser {
  const VlessUriParser();

  VlessParseResult parse(String raw) {
    if (raw.isEmpty) {
      return const VlessParseResult(error: VlessParseError.emptyLink);
    }

    final Uri? uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'vless') {
      return const VlessParseResult(error: VlessParseError.invalidScheme);
    }

    if (uri.userInfo.isEmpty) {
      return const VlessParseResult(error: VlessParseError.missingUuid);
    }

    if (uri.host.isEmpty || uri.port == 0) {
      return const VlessParseResult(error: VlessParseError.missingEndpoint);
    }

    return VlessParseResult(
      profile: VlessProfile(
        uuid: uri.userInfo,
        host: uri.host,
        port: uri.port,
        security: _readQuery(uri, 'security', fallback: 'none'),
        transport: _readQuery(uri, 'type', fallback: 'tcp'),
        encryption: _readQuery(uri, 'encryption', fallback: 'none'),
        flow: uri.queryParameters['flow'],
        fingerprint: uri.queryParameters['fp'],
        publicKey: uri.queryParameters['pbk'],
        shortId: uri.queryParameters['sid'],
        spiderX: uri.queryParameters['spx'],
        serverName: uri.queryParameters['sni'],
        remark: uri.fragment.isEmpty ? null : Uri.decodeComponent(uri.fragment),
      ),
    );
  }

  String _readQuery(
    Uri uri,
    String key, {
    required String fallback,
  }) {
    final String? value = uri.queryParameters[key];
    if (value == null || value.isEmpty) {
      return fallback;
    }

    return value;
  }
}
