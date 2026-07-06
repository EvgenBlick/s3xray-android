import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import '../domain/import_link_error.dart';
import '../domain/resolved_import_link.dart';
import '../domain/resolved_profile_group.dart';
import '../domain/resolved_profile_link.dart';
import '../domain/resolved_subscription_info.dart';
import '../../s3x/application/s3x_link_parser.dart';
import '../../vless/domain/vless_profile.dart';
import '../../vless/domain/vless_uri_parser.dart';

class ImportLinkResult {
  const ImportLinkResult({this.link, this.error});

  final ResolvedImportLink? link;
  final ImportLinkError? error;
}

class RemoteLinkResponse {
  const RemoteLinkResponse({required this.body, required this.headers});

  final String body;
  final Map<String, String> headers;
}

typedef RemoteLinkFetcher =
    Future<RemoteLinkResponse> Function(Uri uri, Map<String, String> headers);
typedef SubscriptionHeadersProvider = Future<Map<String, String>> Function();

class ImportLinkResolver {
  ImportLinkResolver({
    VlessUriParser parser = const VlessUriParser(),
    RemoteLinkFetcher? fetcher,
    SubscriptionHeadersProvider? headersProvider,
  }) : _parser = parser,
       _fetcher = fetcher ?? _defaultFetcher,
       _headersProvider = headersProvider ?? _emptyHeadersProvider;

  final VlessUriParser _parser;
  final S3xLinkParser _s3xLinkParser = const S3xLinkParser();
  final RemoteLinkFetcher _fetcher;
  final SubscriptionHeadersProvider _headersProvider;

  Future<ImportLinkResult> resolve(String raw) async {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const ImportLinkResult(error: ImportLinkError.emptyLink);
    }

    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme.isEmpty) {
      return const ImportLinkResult(error: ImportLinkError.invalidScheme);
    }

    if (uri.scheme == 'vless') {
      return _resolveDirect(trimmed);
    }

    if (uri.scheme == 's3x') {
      return _resolveS3x(trimmed);
    }

    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return _resolveRemote(uri);
    }

    return const ImportLinkResult(error: ImportLinkError.invalidScheme);
  }

  ImportLinkResult _resolveDirect(String raw) {
    final VlessParseResult result = _parser.parse(raw);
    if (result.error != null) {
      return ImportLinkResult(error: _mapParseError(result.error!));
    }

    return ImportLinkResult(
      link: ResolvedImportLink(
        sourceLink: raw,
        profiles: <ResolvedProfileLink>[
          ResolvedProfileLink(resolvedLink: raw, profile: result.profile!),
        ],
        groups: const <ResolvedProfileGroup>[],
        isRemote: false,
        subscriptionInfo: null,
      ),
    );
  }

  ImportLinkResult _resolveS3x(String raw) {
    try {
      final S3xProfile profile = _s3xLinkParser.parse(raw);
      final ResolvedProfileLink profileLink = ResolvedProfileLink(
        resolvedLink: raw,
        profile: VlessProfile(
          uuid: '00000000-0000-0000-0000-000000000000',
          host: 'vk-cloud-s3',
          port: 443,
          security: 's3',
          transport: 'fedarisha',
          encryption: 'none',
          remark: profile.remark,
        ),
      );
      return ImportLinkResult(
        link: ResolvedImportLink(
          sourceLink: raw,
          profiles: <ResolvedProfileLink>[profileLink],
          groups: <ResolvedProfileGroup>[
            ResolvedProfileGroup(
              name: profile.remark,
              profiles: <ResolvedProfileLink>[profileLink],
              runtimeConfig: profile.runtimeConfig,
            ),
          ],
          isRemote: false,
          subscriptionInfo: null,
        ),
      );
    } catch (_) {
      return const ImportLinkResult(error: ImportLinkError.invalidScheme);
    }
  }

  Future<ImportLinkResult> _resolveRemote(Uri uri) async {
    final Map<String, String> baseHeaders = await _headersProvider();
    const List<Map<String, String>> headerProfiles = <Map<String, String>>[
      <String, String>{
        'User-Agent': 'HApp/1.0 Android',
        'Accept': 'application/json, application/yaml, text/plain, */*',
      },
      <String, String>{
        'User-Agent': 'clash-verge/2.1.2',
        'Accept': 'application/json, application/yaml, text/plain, */*',
      },
      <String, String>{
        'User-Agent': 'v2rayNG/1.10.8',
        'Accept': 'application/json, text/plain, */*',
      },
      <String, String>{'Accept': 'application/json, text/plain, */*'},
    ];

    bool unsupportedApp = false;
    bool deviceLimitReached = false;

    for (final Map<String, String> headerProfile in headerProfiles) {
      final Map<String, String> headers = <String, String>{
        ...baseHeaders,
        ...headerProfile,
      };
      final Map<String, ResolvedProfileLink> responseProfiles =
          <String, ResolvedProfileLink>{};
      final Map<String, ResolvedProfileLink> responseProfilesByName =
          <String, ResolvedProfileLink>{};
      try {
        final RemoteLinkResponse response = await _fetcher(uri, headers);
        final ResolvedSubscriptionInfo subscriptionInfo =
            _parseSubscriptionInfo(response.headers);
        final ResolvedImportLink? runtimeImportLink =
            _tryResolveRuntimeJsonImportLink(
              response.body,
              uri,
              subscriptionInfo,
            );
        if (runtimeImportLink != null) {
          return ImportLinkResult(link: runtimeImportLink);
        }

        final _PayloadExtraction extraction = _extractCandidateLinks(
          response.body,
          response.headers,
        );

        if (extraction.unsupportedApp) {
          unsupportedApp = true;
        }
        if (extraction.deviceLimitReached) {
          deviceLimitReached = true;
        }

        for (final String candidate in extraction.links) {
          final ImportLinkResult result = _resolveDirect(candidate);
          if (result.link == null) {
            continue;
          }

          final ResolvedProfileLink profileLink = result.link!.profiles.first;
          final VlessProfile profile = profileLink.profile;
          if (_isPlaceholderProfile(profile)) {
            unsupportedApp = true;
            continue;
          }

          responseProfiles[_profileSignature(profile)] = profileLink;
          final String profileName = (profile.remark ?? '').trim();
          if (profileName.isNotEmpty) {
            responseProfilesByName[profileName] = profileLink;
          }
        }

        if (responseProfiles.isNotEmpty) {
          final List<ResolvedProfileGroup> groups = extraction.groups
              .map(
                (_ExtractedProxyGroup group) => ResolvedProfileGroup(
                  name: group.name,
                  profiles: group.proxies
                      .map((String name) => responseProfilesByName[name])
                      .whereType<ResolvedProfileLink>()
                      .toList(),
                ),
              )
              .where((ResolvedProfileGroup group) => group.profiles.isNotEmpty)
              .toList();

          return ImportLinkResult(
            link: ResolvedImportLink(
              sourceLink: uri.toString(),
              profiles: responseProfiles.values.toList(),
              groups: groups,
              isRemote: true,
              subscriptionInfo: subscriptionInfo,
            ),
          );
        }
      } catch (_) {
        continue;
      }
    }

    if (deviceLimitReached) {
      return const ImportLinkResult(
        error: ImportLinkError.remoteDeviceLimitReached,
      );
    }

    if (unsupportedApp) {
      return const ImportLinkResult(
        error: ImportLinkError.remoteUnsupportedApp,
      );
    }

    try {
      await _fetcher(uri, <String, String>{
        ...baseHeaders,
        'Accept': 'text/plain, */*',
      });
    } catch (_) {
      return const ImportLinkResult(error: ImportLinkError.remoteFetchFailed);
    }

    return const ImportLinkResult(
      error: ImportLinkError.remoteNoSupportedConfig,
    );
  }

  ResolvedImportLink? _tryResolveRuntimeJsonImportLink(
    String body,
    Uri uri,
    ResolvedSubscriptionInfo subscriptionInfo,
  ) {
    try {
      final Object? parsed = jsonDecode(body);
      if (parsed is! List) {
        return null;
      }

      final List<ResolvedProfileLink> profiles = <ResolvedProfileLink>[];
      final Map<String, ResolvedProfileLink> profilesBySignature =
          <String, ResolvedProfileLink>{};
      final Map<String, ResolvedProfileLink> profilesByRemark =
          <String, ResolvedProfileLink>{};
      final List<ResolvedProfileGroup> groups = <ResolvedProfileGroup>[];

      for (final Object? item in parsed) {
        if (item is! Map<String, dynamic> || !_isRuntimeProfileNode(item)) {
          continue;
        }

        final String remarks = '${item['remarks'] ?? ''}'.trim();
        final Map<String, dynamic> normalizedRuntimeProfile =
            _normalizeRuntimeProfileConfig(item);
        final List<ResolvedProfileLink> groupProfiles =
            _extractResolvedProfilesFromRuntimeProfile(
              normalizedRuntimeProfile,
            );

        for (final ResolvedProfileLink profileLink in groupProfiles) {
          final String signature = _profileSignature(profileLink.profile);
          final ResolvedProfileLink resolvedProfile = profilesBySignature
              .putIfAbsent(signature, () {
                profiles.add(profileLink);
                return profileLink;
              });
          final String remark = (resolvedProfile.profile.remark ?? '').trim();
          if (remark.isNotEmpty) {
            profilesByRemark[remark] = resolvedProfile;
          }
        }

        final List<ResolvedProfileLink> normalizedGroupProfiles = groupProfiles
            .map(
              (ResolvedProfileLink profileLink) =>
                  profilesByRemark[(profileLink.profile.remark ?? '').trim()] ??
                  profileLink,
            )
            .toList();

        if (remarks.isEmpty && normalizedGroupProfiles.isEmpty) {
          continue;
        }

        groups.add(
          ResolvedProfileGroup(
            name: remarks.isEmpty
                ? normalizedGroupProfiles.first.profile.remark ?? 'Subscription'
                : remarks,
            profiles: normalizedGroupProfiles,
            runtimeConfig: jsonEncode(normalizedRuntimeProfile),
          ),
        );
      }

      if (profiles.isEmpty && groups.isEmpty) {
        return null;
      }

      return ResolvedImportLink(
        sourceLink: uri.toString(),
        profiles: profiles,
        groups: groups,
        isRemote: true,
        subscriptionInfo: subscriptionInfo,
      );
    } catch (_) {
      return null;
    }
  }

  ResolvedSubscriptionInfo _parseSubscriptionInfo(Map<String, String> headers) {
    return ResolvedSubscriptionInfo(
      profileTitle: _decodeHeaderBase64(headers['profile-title']),
      announce: _decodeHeaderBase64(headers['announce']),
      profileUpdateIntervalHours: int.tryParse(
        (headers['profile-update-interval'] ?? '').trim(),
      ),
      refillAt: _parseUnixSeconds(headers['subscription-refill-date']),
      expireAt: _parseExpireAt(headers['subscription-userinfo']),
      uploadBytes: _parseUserInfoInt(
        headers['subscription-userinfo'],
        'upload',
      ),
      downloadBytes: _parseUserInfoInt(
        headers['subscription-userinfo'],
        'download',
      ),
      totalBytes: _parseUserInfoInt(headers['subscription-userinfo'], 'total'),
      webPageUrl: _cleanHeaderValue(headers['profile-web-page-url']),
      supportUrl: _cleanHeaderValue(headers['support-url']),
    );
  }

  String? _decodeHeaderBase64(String? value) {
    final String normalized = _cleanHeaderValue(value) ?? '';
    if (normalized.isEmpty) {
      return null;
    }

    final String base64Value = normalized.startsWith('base64:')
        ? normalized.substring(7)
        : normalized;
    try {
      return utf8.decode(base64.decode(base64.normalize(base64Value))).trim();
    } catch (_) {
      return normalized;
    }
  }

  String? _cleanHeaderValue(String? value) {
    final String normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  DateTime? _parseUnixSeconds(String? value) {
    final int? seconds = int.tryParse((value ?? '').trim());
    if (seconds == null || seconds <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ).toLocal();
  }

  DateTime? _parseExpireAt(String? userInfoHeader) {
    final int? seconds = _parseUserInfoInt(userInfoHeader, 'expire');
    if (seconds == null || seconds <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ).toLocal();
  }

  int? _parseUserInfoInt(String? header, String key) {
    final String source = header ?? '';
    if (source.isEmpty) {
      return null;
    }

    final RegExp matchPattern = RegExp('$key=([0-9]+)');
    final RegExpMatch? match = matchPattern.firstMatch(source);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  ImportLinkError _mapParseError(VlessParseError error) {
    switch (error) {
      case VlessParseError.emptyLink:
        return ImportLinkError.emptyLink;
      case VlessParseError.invalidScheme:
        return ImportLinkError.invalidScheme;
      case VlessParseError.missingUuid:
        return ImportLinkError.missingUuid;
      case VlessParseError.missingEndpoint:
        return ImportLinkError.missingEndpoint;
    }
  }

  _PayloadExtraction _extractCandidateLinks(
    String body,
    Map<String, String> headers,
  ) {
    final String normalized = body.trim();
    final List<String> links = <String>[
      ..._extractLinksFromText(normalized),
      ..._extractLinksFromDecodedBase64(normalized),
      ..._extractLinksFromYaml(normalized),
      ..._extractLinksFromJson(normalized),
    ];
    final List<_ExtractedProxyGroup> groups = <_ExtractedProxyGroup>[
      ..._extractGroupsFromYaml(normalized),
      ..._extractGroupsFromJson(normalized),
    ];

    final bool unsupportedByHeader = headers['x-hwid-not-supported'] == 'true';
    final bool deviceLimitReached =
        headers['x-hwid-max-devices-reached'] == 'true' ||
        (headers['x-hwid-limit'] == 'true' && !unsupportedByHeader);
    final bool unsupportedByBody = normalized.toLowerCase().contains(
      'app not supported',
    );

    return _PayloadExtraction(
      links: links.toSet().toList(),
      groups: groups,
      unsupportedApp: unsupportedByHeader || unsupportedByBody,
      deviceLimitReached: deviceLimitReached,
    );
  }

  List<String> _extractLinksFromText(String text) {
    if (text.isEmpty) {
      return const <String>[];
    }

    final RegExp pattern = RegExp(r"""vless://[^\s"']+""");
    return pattern
        .allMatches(text)
        .map((RegExpMatch match) => match.group(0)!)
        .toList();
  }

  List<String> _extractLinksFromDecodedBase64(String text) {
    if (!_looksLikeBase64(text)) {
      return const <String>[];
    }

    try {
      final String decoded = utf8.decode(base64.decode(base64.normalize(text)));
      return _extractLinksFromText(decoded);
    } catch (_) {
      return const <String>[];
    }
  }

  List<String> _extractLinksFromYaml(String text) {
    if (!text.contains('proxies:')) {
      return const <String>[];
    }

    try {
      final Object? parsed = loadYaml(text);
      if (parsed is! YamlMap) {
        return const <String>[];
      }

      final Object? proxies = parsed['proxies'];
      if (proxies is! YamlList) {
        return const <String>[];
      }

      return proxies
          .whereType<YamlMap>()
          .map(_buildVlessLinkFromYamlProxy)
          .whereType<String>()
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }

  List<_ExtractedProxyGroup> _extractGroupsFromYaml(String text) {
    if (!text.contains('proxy-groups:')) {
      return const <_ExtractedProxyGroup>[];
    }

    try {
      final Object? parsed = loadYaml(text);
      if (parsed is! YamlMap) {
        return const <_ExtractedProxyGroup>[];
      }

      final Object? groups = parsed['proxy-groups'];
      if (groups is! YamlList) {
        return const <_ExtractedProxyGroup>[];
      }

      return groups
          .whereType<YamlMap>()
          .map(_buildExtractedGroupFromYaml)
          .whereType<_ExtractedProxyGroup>()
          .toList();
    } catch (_) {
      return const <_ExtractedProxyGroup>[];
    }
  }

  List<String> _extractLinksFromJson(String text) {
    if (text.isEmpty) {
      return const <String>[];
    }

    try {
      final Object? parsed = jsonDecode(text);
      return _extractLinksFromJsonNode(parsed);
    } catch (_) {
      return const <String>[];
    }
  }

  List<String> _extractLinksFromJsonNode(Object? node) {
    if (node is Map<String, dynamic>) {
      if (_isRuntimeProfileNode(node)) {
        return _extractLinksFromRuntimeProfile(node);
      }

      final List<String> links = <String>[];

      final Object? proxies = node['proxies'];
      if (proxies is List) {
        links.addAll(
          proxies
              .whereType<Map<String, dynamic>>()
              .map(_buildVlessLinkFromJsonProxy)
              .whereType<String>(),
        );
      }

      final Object? outbounds = node['outbounds'];
      if (outbounds is List) {
        links.addAll(
          outbounds
              .whereType<Map<String, dynamic>>()
              .map(_buildVlessLinkFromJsonOutbound)
              .whereType<String>(),
        );
      }

      for (final Object? value in node.values) {
        links.addAll(_extractLinksFromJsonNode(value));
      }

      return links;
    }

    if (node is List) {
      return node.expand(_extractLinksFromJsonNode).toList();
    }

    if (node is String) {
      return _extractLinksFromText(node);
    }

    return const <String>[];
  }

  List<_ExtractedProxyGroup> _extractGroupsFromJson(String text) {
    if (text.isEmpty) {
      return const <_ExtractedProxyGroup>[];
    }

    try {
      final Object? parsed = jsonDecode(text);
      return _extractGroupsFromJsonNode(parsed);
    } catch (_) {
      return const <_ExtractedProxyGroup>[];
    }
  }

  List<_ExtractedProxyGroup> _extractGroupsFromJsonNode(Object? node) {
    if (node is Map<String, dynamic>) {
      if (_isRuntimeProfileNode(node)) {
        final _ExtractedProxyGroup? runtimeGroup =
            _buildExtractedGroupFromRuntimeProfile(node);
        return runtimeGroup == null
            ? const <_ExtractedProxyGroup>[]
            : <_ExtractedProxyGroup>[runtimeGroup];
      }

      final List<_ExtractedProxyGroup> groups = <_ExtractedProxyGroup>[];
      final Object? proxyGroups = node['proxy-groups'];
      if (proxyGroups is List) {
        groups.addAll(
          proxyGroups
              .whereType<Map<String, dynamic>>()
              .map(_buildExtractedGroupFromJson)
              .whereType<_ExtractedProxyGroup>(),
        );
      }

      for (final Object? value in node.values) {
        groups.addAll(_extractGroupsFromJsonNode(value));
      }

      return groups;
    }

    if (node is List) {
      return node.expand(_extractGroupsFromJsonNode).toList();
    }

    return const <_ExtractedProxyGroup>[];
  }

  bool _isRuntimeProfileNode(Map<String, dynamic> node) {
    return node['remarks'] is String && node['outbounds'] is List;
  }

  List<String> _extractLinksFromRuntimeProfile(Map<String, dynamic> node) {
    final String remarks = '${node['remarks'] ?? ''}'.trim();
    final Object? outboundsNode = node['outbounds'];
    if (outboundsNode is! List) {
      return const <String>[];
    }

    final List<Map<String, dynamic>> vlessOutbounds = outboundsNode
        .whereType<Map<String, dynamic>>()
        .where(
          (Map<String, dynamic> outbound) =>
              '${outbound['protocol'] ?? ''}'.toLowerCase() == 'vless',
        )
        .toList();
    if (vlessOutbounds.isEmpty) {
      return const <String>[];
    }

    final List<Map<String, dynamic>> namedOutbounds = vlessOutbounds
        .where(
          (Map<String, dynamic> outbound) =>
              !_isGenericProxyTag('${outbound['tag'] ?? ''}'),
        )
        .toList();

    final Iterable<Map<String, dynamic>> preferredOutbounds =
        namedOutbounds.isNotEmpty ? namedOutbounds : vlessOutbounds.take(1);

    return preferredOutbounds
        .map(
          (Map<String, dynamic> outbound) =>
              _buildVlessLinkFromJsonOutbound(outbound, fallbackName: remarks),
        )
        .whereType<String>()
        .toList();
  }

  List<ResolvedProfileLink> _extractResolvedProfilesFromRuntimeProfile(
    Map<String, dynamic> node,
  ) {
    final String remarks = '${node['remarks'] ?? ''}'.trim();
    final Object? outboundsNode = node['outbounds'];
    if (outboundsNode is! List) {
      return const <ResolvedProfileLink>[];
    }

    final List<Map<String, dynamic>> vlessOutbounds = outboundsNode
        .whereType<Map<String, dynamic>>()
        .where(
          (Map<String, dynamic> outbound) =>
              '${outbound['protocol'] ?? ''}'.toLowerCase() == 'vless',
        )
        .toList();
    if (vlessOutbounds.isEmpty) {
      return const <ResolvedProfileLink>[];
    }

    final List<Map<String, dynamic>> namedOutbounds = vlessOutbounds
        .where(
          (Map<String, dynamic> outbound) =>
              !_isGenericProxyTag('${outbound['tag'] ?? ''}'),
        )
        .toList();

    final Iterable<Map<String, dynamic>> preferredOutbounds =
        namedOutbounds.isNotEmpty ? namedOutbounds : vlessOutbounds.take(1);

    return preferredOutbounds
        .map(
          (Map<String, dynamic> outbound) =>
              _buildVlessLinkFromJsonOutbound(outbound, fallbackName: remarks),
        )
        .whereType<String>()
        .map(_resolveDirect)
        .where((ImportLinkResult result) => result.link != null)
        .map((ImportLinkResult result) => result.link!.profiles.first)
        .toList();
  }

  Map<String, dynamic> _normalizeRuntimeProfileConfig(
    Map<String, dynamic> node,
  ) {
    final Map<String, dynamic> normalized =
        (jsonDecode(jsonEncode(node)) as Map).cast<String, dynamic>();
    final Object? inboundsNode = normalized['inbounds'];
    if (inboundsNode is! List) {
      return normalized;
    }

    for (final Object? inboundNode in inboundsNode) {
      if (inboundNode is! Map) {
        continue;
      }

      final Map<dynamic, dynamic> inbound = inboundNode;
      final String protocol = '${inbound['protocol'] ?? ''}'.toLowerCase();
      if (protocol == 'socks') {
        inbound['port'] = 10807;
      } else if (protocol == 'http') {
        inbound['port'] = 10808;
      }
    }

    _injectDirectRouteForRuntimeServers(normalized);

    return normalized;
  }

  void _injectDirectRouteForRuntimeServers(Map<String, dynamic> normalized) {
    final Object? outboundsNode = normalized['outbounds'];
    if (outboundsNode is! List) {
      return;
    }

    final Set<String> domains = <String>{};
    final Set<String> ips = <String>{};

    for (final Object? outboundNode in outboundsNode) {
      if (outboundNode is! Map) {
        continue;
      }

      final Map<dynamic, dynamic> outbound = outboundNode;
      if ('${outbound['protocol'] ?? ''}'.toLowerCase() != 'vless') {
        continue;
      }

      final Object? settingsNode = outbound['settings'];
      if (settingsNode is! Map) {
        continue;
      }

      final Object? vnextNode = settingsNode['vnext'];
      if (vnextNode is! List || vnextNode.isEmpty || vnextNode.first is! Map) {
        continue;
      }

      final Map<dynamic, dynamic> server =
          vnextNode.first as Map<dynamic, dynamic>;
      final String address = '${server['address'] ?? ''}'.trim();
      if (address.isEmpty) {
        continue;
      }

      if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(address)) {
        ips.add(address);
      } else {
        domains.add(address);
      }
    }

    if (domains.isEmpty && ips.isEmpty) {
      return;
    }

    final Map<String, dynamic> routing =
        (normalized['routing'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final List<dynamic> rules =
        (routing['rules'] as List?)?.toList() ?? <dynamic>[];

    final Map<String, dynamic> directRule = <String, dynamic>{
      'type': 'field',
      'outboundTag': 'direct',
    };
    if (domains.isNotEmpty) {
      directRule['domain'] = domains.toList();
    }
    if (ips.isNotEmpty) {
      directRule['ip'] = ips.toList();
    }

    rules.insert(0, directRule);
    routing['rules'] = rules;
    normalized['routing'] = routing;
  }

  _ExtractedProxyGroup? _buildExtractedGroupFromRuntimeProfile(
    Map<String, dynamic> node,
  ) {
    final String groupName = '${node['remarks'] ?? ''}'.trim();
    final Object? outboundsNode = node['outbounds'];
    if (groupName.isEmpty || outboundsNode is! List) {
      return null;
    }

    final List<String> proxyNames = outboundsNode
        .whereType<Map<String, dynamic>>()
        .where(
          (Map<String, dynamic> outbound) =>
              '${outbound['protocol'] ?? ''}'.toLowerCase() == 'vless',
        )
        .map(
          (Map<String, dynamic> outbound) =>
              _resolveOutboundDisplayName(outbound, fallbackName: groupName),
        )
        .where((String name) => name.isNotEmpty && !_isGenericProxyTag(name))
        .toList();

    if (proxyNames.isEmpty) {
      proxyNames.add(groupName);
    }

    return _ExtractedProxyGroup(name: groupName, proxies: proxyNames);
  }

  String? _buildVlessLinkFromYamlProxy(YamlMap proxy) {
    final String type = '${proxy['type'] ?? ''}'.toLowerCase();
    if (type != 'vless') {
      return null;
    }

    final String uuid = '${proxy['uuid'] ?? ''}'.trim();
    final String host = '${proxy['server'] ?? ''}'.trim();
    final int? port = int.tryParse('${proxy['port'] ?? ''}');
    if (uuid.isEmpty || host.isEmpty || port == null || port == 0) {
      return null;
    }

    final String security = _resolveYamlSecurity(proxy);
    final Map<String, String> query = <String, String>{
      'encryption': '${proxy['encryption'] ?? 'none'}',
      'type': '${proxy['network'] ?? 'tcp'}',
      'security': security,
    };

    final String flow = '${proxy['flow'] ?? ''}'.trim();
    if (flow.isNotEmpty) {
      query['flow'] = flow;
    }

    final String fingerprint = '${proxy['client-fingerprint'] ?? ''}'.trim();
    if (fingerprint.isNotEmpty) {
      query['fp'] = fingerprint;
    }

    final String sni = '${proxy['servername'] ?? proxy['sni'] ?? ''}'.trim();
    if (sni.isNotEmpty) {
      query['sni'] = sni;
    }

    final Object? realityOptions = proxy['reality-opts'];
    if (realityOptions is YamlMap) {
      final String publicKey = '${realityOptions['public-key'] ?? ''}'.trim();
      if (publicKey.isNotEmpty) {
        query['pbk'] = publicKey;
      }

      final String shortId =
          '${realityOptions['short-id'] ?? realityOptions['shortId'] ?? ''}'
              .trim();
      if (shortId.isNotEmpty) {
        query['sid'] = shortId;
      }

      final String spiderX =
          '${realityOptions['spider-x'] ?? realityOptions['spiderX'] ?? ''}'
              .trim();
      if (spiderX.isNotEmpty) {
        query['spx'] = spiderX;
      }
    }

    final String name = '${proxy['name'] ?? 'Subscription'}'.trim();
    final Uri uri = Uri(
      scheme: 'vless',
      userInfo: uuid,
      host: host,
      port: port,
      queryParameters: query,
      fragment: name,
    );
    return uri.toString();
  }

  String? _buildVlessLinkFromJsonProxy(Map<String, dynamic> proxy) {
    final String type = '${proxy['type'] ?? ''}'.toLowerCase();
    if (type != 'vless') {
      return null;
    }

    return _buildVlessLink(
      uuid: '${proxy['uuid'] ?? proxy['id'] ?? ''}'.trim(),
      host: '${proxy['server'] ?? proxy['address'] ?? ''}'.trim(),
      port: int.tryParse('${proxy['port'] ?? ''}'),
      encryption: '${proxy['encryption'] ?? 'none'}',
      transport: '${proxy['network'] ?? proxy['type_network'] ?? 'tcp'}',
      security: _resolveJsonSecurity(proxy),
      flow: '${proxy['flow'] ?? ''}'.trim(),
      fingerprint:
          '${proxy['client-fingerprint'] ?? proxy['fingerprint'] ?? proxy['fp'] ?? ''}'
              .trim(),
      sni: '${proxy['servername'] ?? proxy['serverName'] ?? proxy['sni'] ?? ''}'
          .trim(),
      publicKey: _readJsonReality(proxy, const <String>[
        'public-key',
        'publicKey',
        'pbk',
      ]),
      shortId: _readJsonReality(proxy, const <String>[
        'short-id',
        'shortId',
        'sid',
      ]),
      spiderX: _readJsonReality(proxy, const <String>[
        'spider-x',
        'spiderX',
        'spx',
      ]),
      name: '${proxy['name'] ?? proxy['remark'] ?? 'Subscription'}'.trim(),
    );
  }

  _ExtractedProxyGroup? _buildExtractedGroupFromYaml(YamlMap group) {
    final bool hidden = group['hidden'] == true;
    if (hidden) {
      return null;
    }

    final String name = '${group['name'] ?? ''}'.trim();
    final Object? proxies = group['proxies'];
    if (name.isEmpty || proxies is! YamlList) {
      return null;
    }

    final List<String> proxyNames = proxies
        .map((Object? item) => '${item ?? ''}'.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
    if (proxyNames.isEmpty) {
      return null;
    }

    return _ExtractedProxyGroup(name: name, proxies: proxyNames);
  }

  _ExtractedProxyGroup? _buildExtractedGroupFromJson(
    Map<String, dynamic> group,
  ) {
    if (group['hidden'] == true) {
      return null;
    }

    final String name = '${group['name'] ?? ''}'.trim();
    final Object? proxies = group['proxies'];
    if (name.isEmpty || proxies is! List) {
      return null;
    }

    final List<String> proxyNames = proxies
        .map((Object? item) => '${item ?? ''}'.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
    if (proxyNames.isEmpty) {
      return null;
    }

    return _ExtractedProxyGroup(name: name, proxies: proxyNames);
  }

  String? _buildVlessLinkFromJsonOutbound(
    Map<String, dynamic> outbound, {
    String? fallbackName,
  }) {
    final String protocol = '${outbound['protocol'] ?? ''}'.toLowerCase();
    if (protocol != 'vless') {
      return null;
    }

    final Object? settings = outbound['settings'];
    if (settings is! Map<String, dynamic>) {
      return null;
    }

    final Object? vnext = settings['vnext'];
    if (vnext is! List ||
        vnext.isEmpty ||
        vnext.first is! Map<String, dynamic>) {
      return null;
    }

    final Map<String, dynamic> server = vnext.first as Map<String, dynamic>;
    final Object? users = server['users'];
    if (users is! List ||
        users.isEmpty ||
        users.first is! Map<String, dynamic>) {
      return null;
    }

    final Map<String, dynamic> user = users.first as Map<String, dynamic>;
    final Map<String, dynamic> streamSettings =
        (outbound['streamSettings'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final Map<String, dynamic> realitySettings =
        (streamSettings['realitySettings'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final Map<String, dynamic> tlsSettings =
        (streamSettings['tlsSettings'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    final String security =
        '${streamSettings['security'] ?? user['security'] ?? ''}'.trim();
    final String transport = '${streamSettings['network'] ?? 'tcp'}'.trim();

    return _buildVlessLink(
      uuid: '${user['id'] ?? ''}'.trim(),
      host: '${server['address'] ?? ''}'.trim(),
      port: int.tryParse('${server['port'] ?? ''}'),
      encryption: '${user['encryption'] ?? 'none'}',
      transport: transport.isEmpty ? 'tcp' : transport,
      security: security.isEmpty ? 'none' : security,
      flow: '${user['flow'] ?? ''}'.trim(),
      fingerprint:
          '${realitySettings['fingerprint'] ?? tlsSettings['fingerprint'] ?? ''}'
              .trim(),
      sni: '${realitySettings['serverName'] ?? tlsSettings['serverName'] ?? ''}'
          .trim(),
      publicKey: '${realitySettings['publicKey'] ?? ''}'.trim(),
      shortId: '${realitySettings['shortId'] ?? ''}'.trim(),
      spiderX: '${realitySettings['spiderX'] ?? ''}'.trim(),
      name: _resolveOutboundDisplayName(outbound, fallbackName: fallbackName),
    );
  }

  String _resolveOutboundDisplayName(
    Map<String, dynamic> outbound, {
    String? fallbackName,
  }) {
    final String tag = '${outbound['tag'] ?? ''}'.trim();
    final String remark = '${outbound['remark'] ?? ''}'.trim();
    if (tag.isNotEmpty && !_isGenericProxyTag(tag)) {
      return tag;
    }
    if (remark.isNotEmpty && !_isGenericProxyTag(remark)) {
      return remark;
    }
    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      return fallbackName.trim();
    }
    if (remark.isNotEmpty) {
      return remark;
    }
    if (tag.isNotEmpty) {
      return tag;
    }
    return 'Subscription';
  }

  bool _isGenericProxyTag(String tag) {
    final String normalized = tag.trim().toLowerCase();
    return normalized == 'proxy' ||
        normalized == 'direct' ||
        normalized == 'block';
  }

  String? _buildVlessLink({
    required String uuid,
    required String host,
    required int? port,
    required String encryption,
    required String transport,
    required String security,
    required String flow,
    required String fingerprint,
    required String sni,
    required String publicKey,
    required String shortId,
    required String spiderX,
    required String name,
  }) {
    if (uuid.isEmpty || host.isEmpty || port == null || port == 0) {
      return null;
    }

    final Map<String, String> query = <String, String>{
      'encryption': encryption.isEmpty ? 'none' : encryption,
      'type': transport.isEmpty ? 'tcp' : transport,
      'security': security.isEmpty ? 'none' : security,
    };

    if (flow.isNotEmpty) {
      query['flow'] = flow;
    }
    if (fingerprint.isNotEmpty) {
      query['fp'] = fingerprint;
    }
    if (sni.isNotEmpty) {
      query['sni'] = sni;
    }
    if (publicKey.isNotEmpty) {
      query['pbk'] = publicKey;
    }
    if (shortId.isNotEmpty) {
      query['sid'] = shortId;
    }
    if (spiderX.isNotEmpty) {
      query['spx'] = spiderX;
    }

    final Uri uri = Uri(
      scheme: 'vless',
      userInfo: uuid,
      host: host,
      port: port,
      queryParameters: query,
      fragment: name.isEmpty ? 'Subscription' : name,
    );
    return uri.toString();
  }

  String _resolveYamlSecurity(YamlMap proxy) {
    final Object? realityOptions = proxy['reality-opts'];
    if (realityOptions is YamlMap && realityOptions.isNotEmpty) {
      return 'reality';
    }

    final String security = '${proxy['security'] ?? ''}'.trim().toLowerCase();
    if (security.isNotEmpty) {
      return security;
    }

    final String tls = '${proxy['tls'] ?? ''}'.trim().toLowerCase();
    if (tls == 'true') {
      return 'tls';
    }

    return 'none';
  }

  String _resolveJsonSecurity(Map<String, dynamic> proxy) {
    final String security = '${proxy['security'] ?? ''}'.trim().toLowerCase();
    if (security.isNotEmpty) {
      return security;
    }

    final Object? realityOptions =
        proxy['reality-opts'] ?? proxy['realityOpts'];
    if (realityOptions is Map && realityOptions.isNotEmpty) {
      return 'reality';
    }

    final String tls = '${proxy['tls'] ?? ''}'.trim().toLowerCase();
    if (tls == 'true') {
      return 'tls';
    }

    return 'none';
  }

  String _readJsonReality(Map<String, dynamic> proxy, List<String> keys) {
    final Object? realityOptions =
        proxy['reality-opts'] ?? proxy['realityOpts'];
    if (realityOptions is! Map) {
      return '';
    }

    for (final String key in keys) {
      final String value = '${realityOptions[key] ?? ''}'.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  bool _looksLikeBase64(String text) {
    if (text.isEmpty || text.contains(' ') || text.contains('\n')) {
      return false;
    }

    return RegExp(r'^[A-Za-z0-9+/=_-]+$').hasMatch(text);
  }

  bool _isPlaceholderProfile(VlessProfile profile) {
    final String remark = (profile.remark ?? '').toLowerCase();
    return profile.host == '0.0.0.0' ||
        profile.port == 1 ||
        profile.uuid == '00000000-0000-0000-0000-000000000000' ||
        remark.contains('app not supported');
  }

  String _profileSignature(VlessProfile profile) {
    return <String>[
      profile.uuid,
      profile.host,
      '${profile.port}',
      profile.security,
      profile.transport,
      profile.serverName ?? '',
      profile.flow ?? '',
      profile.publicKey ?? '',
    ].join('|');
  }

  static Future<RemoteLinkResponse> _defaultFetcher(
    Uri uri,
    Map<String, String> headers,
  ) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      for (final MapEntry<String, String> entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }

      final HttpClientResponse response = await request.close();
      final String body = await utf8.decodeStream(response);
      final Map<String, String> responseHeaders = <String, String>{};
      response.headers.forEach((String key, List<String> values) {
        responseHeaders[key.toLowerCase()] = values.join(', ');
      });
      return RemoteLinkResponse(body: body, headers: responseHeaders);
    } finally {
      client.close(force: true);
    }
  }

  static Future<Map<String, String>> _emptyHeadersProvider() async {
    return const <String, String>{};
  }
}

class _PayloadExtraction {
  const _PayloadExtraction({
    required this.links,
    required this.groups,
    required this.unsupportedApp,
    required this.deviceLimitReached,
  });

  final List<String> links;
  final List<_ExtractedProxyGroup> groups;
  final bool unsupportedApp;
  final bool deviceLimitReached;
}

class _ExtractedProxyGroup {
  const _ExtractedProxyGroup({required this.name, required this.proxies});

  final String name;
  final List<String> proxies;
}
