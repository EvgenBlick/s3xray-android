import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vless_vpn_app/app/app.dart';
import 'package:vless_vpn_app/features/import/application/import_link_resolver.dart';
import 'package:vless_vpn_app/features/import/domain/import_link_error.dart';
import 'package:vless_vpn_app/features/split_tunnel/application/split_tunnel_apps_repository.dart';
import 'package:vless_vpn_app/features/vless/domain/vless_uri_parser.dart';

void main() {
  testWidgets('renders russian landing screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const VlessVpnApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final bool showsLoading =
        find.text('Загружаем подписку').evaluate().isNotEmpty;
    final bool showsAddSubscription =
        find.text('Добавить подписку').evaluate().isNotEmpty;
    final bool showsAuthGate =
        find.text('Продолжить без авторизации').evaluate().isNotEmpty ||
        find.text('Войти').evaluate().isNotEmpty;
    final bool showsAddLinkIcon =
        find.byIcon(Icons.add_link_rounded).evaluate().isNotEmpty;

    expect(
      showsLoading || showsAddSubscription || showsAddLinkIcon || showsAuthGate,
      isTrue,
    );
  });

  test('parses working germany reality link', () {
    const VlessUriParser parser = VlessUriParser();
    final VlessParseResult result = parser.parse(
      'vless://d6f3d24f-531b-4ed4-96ab-86ee585016bc@104.194.159.146:443?encryption=none&flow=xtls-rprx-vision&type=tcp&security=reality&sni=github.com&fp=chrome&pbk=m3W48zNdXpOZwNbOv-Jx5J125x3RyQRNt8JXP-aY9nI#%F0%9F%87%A9%F0%9F%87%AAGermany',
    );

    expect(result.error, isNull);
    expect(result.profile, isNotNull);
    expect(result.profile!.host, '104.194.159.146');
    expect(result.profile!.port, 443);
    expect(result.profile!.security, 'reality');
    expect(result.profile!.transport, 'tcp');
    expect(result.profile!.flow, 'xtls-rprx-vision');
    expect(result.profile!.fingerprint, 'chrome');
    expect(result.profile!.publicKey, 'm3W48zNdXpOZwNbOv-Jx5J125x3RyQRNt8JXP-aY9nI');
    expect(result.profile!.serverName, 'github.com');
  });

  test('resolves remote base64 subscription into vless link', () async {
    final ImportLinkResolver resolver = ImportLinkResolver(
      fetcher: (Uri uri, Map<String, String> headers) async {
        return const RemoteLinkResponse(
          body:
              'dmxlc3M6Ly9kNmYzZDI0Zi01MzFiLTRlZDQtOTZhYi04NmVlNTg1MDE2YmNAMTA0LjE5NC4xNTkuMTQ2OjQ0Mz9lbmNyeXB0aW9uPW5vbmUmZmxvdz14dGxzLXJwcngtdmlzaW9uJnR5cGU9dGNwJnNlY3VyaXR5PXJlYWxpdHkmc25pPWdpdGh1Yi5jb20mZnA9Y2hyb21lJnBiaz1tM1c0OHpOZFhwT1p3TmJPdi1KeDVKMTI1eDNSeVFSTnQ4SlhQLWFZOW5JI0dlcm1hbnk=',
          headers: <String, String>{
            'profile-title': 'base64:VWx0aW10ZWFtIFZQTg==',
            'announce': 'base64:0KLQtdGB0YIg0L7QsdGK0Y/QstC70LXQvdC40Y8=',
            'profile-update-interval': '12',
            'subscription-userinfo':
                'upload=0; download=123456789; total=987654321; expire=1803548400',
          },
        );
      },
    );

    final ImportLinkResult result = await resolver.resolve(
      'https://example.com/subscription',
    );

    expect(result.error, isNull);
    expect(result.link, isNotNull);
    expect(result.link!.isRemote, isTrue);
    expect(result.link!.profiles, hasLength(1));
    expect(result.link!.profiles.first.profile.host, '104.194.159.146');
    expect(result.link!.subscriptionInfo, isNotNull);
    expect(result.link!.subscriptionInfo!.profileTitle, 'Ultimteam VPN');
    expect(result.link!.subscriptionInfo!.downloadBytes, 123456789);
    expect(result.link!.subscriptionInfo!.totalBytes, 987654321);
    expect(result.link!.subscriptionInfo!.profileUpdateIntervalHours, 12);
  });

  test('loads and saves split tunnel apps through method channel', () async {
    const MethodChannel channel = MethodChannel('stockvpn/split_tunnel');
    final List<MethodCall> calls = <MethodCall>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          switch (call.method) {
            case 'listApps':
              return <Map<String, Object?>>[
                <String, Object?>{
                  'packageName': 'org.telegram.messenger',
                  'label': 'Telegram',
                  'isSystemApp': false,
                },
              ];
            case 'getBlockedApps':
              return <String>['org.telegram.messenger'];
            case 'setBlockedApps':
              return null;
          }
          return null;
        });

    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    const SplitTunnelAppsRepository repository = SplitTunnelAppsRepository(
      supportsNativeApps: true,
    );
    final apps = await repository.listApps();
    final blockedApps = await repository.loadBlockedPackages();
    await repository.saveBlockedPackages(<String>{'org.telegram.messenger'});

    expect(apps, hasLength(1));
    expect(apps.first.label, 'Telegram');
    expect(blockedApps, contains('org.telegram.messenger'));
    expect(
      calls.map((MethodCall call) => call.method),
      containsAll(<String>['listApps', 'getBlockedApps', 'setBlockedApps']),
    );
  });

  test('resolves multiple yaml subscription servers', () async {
    final ImportLinkResolver resolver = ImportLinkResolver(
      fetcher: (Uri uri, Map<String, String> headers) async {
        return const RemoteLinkResponse(
          body:
              'proxies:\n'
              '  - name: 🇺🇸 USA\n'
              '    type: vless\n'
              '    server: 144.172.96.132\n'
              '    port: 443\n'
              '    network: tcp\n'
              '    uuid: d6f3d24f-531b-4ed4-96ab-86ee585016bc\n'
              '    flow: xtls-rprx-vision\n'
              '    tls: true\n'
              '    servername: github.com\n'
              '    reality-opts:\n'
              '      public-key: m3W48zNdXpOZwNbOv-Jx5J125x3RyQRNt8JXP-aY9nI\n'
              '      short-id: abcd1234\n'
              '    client-fingerprint: chrome\n'
              '  - name: 🇩🇪Germany\n'
              '    type: vless\n'
              '    server: 104.194.159.146\n'
              '    port: 443\n'
              '    network: tcp\n'
              '    uuid: d6f3d24f-531b-4ed4-96ab-86ee585016bc\n'
              '    flow: xtls-rprx-vision\n'
              '    tls: true\n'
              '    servername: github.com\n'
              '    reality-opts:\n'
              '      public-key: m3W48zNdXpOZwNbOv-Jx5J125x3RyQRNt8JXP-aY9nI\n'
              '      short-id: dcba4321\n'
              '    client-fingerprint: chrome\n'
              'proxy-groups:\n'
              '  - name: Быстрые\n'
              '    type: select\n'
              '    proxies:\n'
              '      - 🇺🇸 USA\n'
              '      - 🇩🇪Germany\n',
          headers: <String, String>{},
        );
      },
    );

    final ImportLinkResult result = await resolver.resolve(
      'https://example.com/subscription',
    );

    expect(result.error, isNull);
    expect(result.link, isNotNull);
    expect(result.link!.profiles, hasLength(2));
    expect(result.link!.profiles.first.profile.remark, '🇺🇸 USA');
    expect(result.link!.profiles.last.profile.remark, '🇩🇪Germany');
    expect(result.link!.profiles.first.profile.security, 'reality');
    expect(result.link!.profiles.last.profile.security, 'reality');
    expect(result.link!.profiles.first.profile.shortId, 'abcd1234');
    expect(result.link!.profiles.last.profile.shortId, 'dcba4321');
    expect(result.link!.groups, hasLength(1));
    expect(result.link!.groups.first.name, 'Быстрые');
    expect(result.link!.groups.first.profiles, hasLength(2));
  });

  test('deduplicates identical servers across fallback header profiles', () async {
    int fetchCount = 0;
    final ImportLinkResolver resolver = ImportLinkResolver(
      fetcher: (Uri uri, Map<String, String> headers) async {
        fetchCount++;
        return const RemoteLinkResponse(
          body:
              'proxies:\n'
              '  - name: 🇺🇸 USA\n'
              '    type: vless\n'
              '    server: 144.172.96.132\n'
              '    port: 443\n'
              '    network: tcp\n'
              '    uuid: d6f3d24f-531b-4ed4-96ab-86ee585016bc\n'
              '    flow: xtls-rprx-vision\n'
              '    tls: true\n'
              '    servername: github.com\n'
              '    reality-opts:\n'
              '      public-key: m3W48zNdXpOZwNbOv-Jx5J125x3RyQRNt8JXP-aY9nI\n'
              '    client-fingerprint: chrome\n'
              '  - name: 🇩🇪Germany\n'
              '    type: vless\n'
              '    server: 104.194.159.146\n'
              '    port: 443\n'
              '    network: tcp\n'
              '    uuid: d6f3d24f-531b-4ed4-96ab-86ee585016bc\n'
              '    flow: xtls-rprx-vision\n'
              '    tls: true\n'
              '    servername: github.com\n'
              '    reality-opts:\n'
              '      public-key: m3W48zNdXpOZwNbOv-Jx5J125x3RyQRNt8JXP-aY9nI\n'
              '    client-fingerprint: chrome\n',
          headers: <String, String>{},
        );
      },
    );

    final ImportLinkResult result = await resolver.resolve(
      'https://example.com/subscription',
    );

    expect(result.error, isNull);
    expect(result.link, isNotNull);
    expect(result.link!.profiles, hasLength(2));
    expect(fetchCount, 1);
  });

  test('resolves json subscription servers with reality options', () async {
    final ImportLinkResolver resolver = ImportLinkResolver(
      fetcher: (Uri uri, Map<String, String> headers) async {
        return const RemoteLinkResponse(
          body:
              '{'
              '"proxies":['
              '{'
              '"name":"Japan",'
              '"type":"vless",'
              '"server":"1.2.3.4",'
              '"port":443,'
              '"uuid":"d6f3d24f-531b-4ed4-96ab-86ee585016bc",'
              '"network":"tcp",'
              '"flow":"xtls-rprx-vision",'
              '"servername":"github.com",'
              '"client-fingerprint":"chrome",'
              '"reality-opts":{'
              '"public-key":"pubkey123",'
              '"short-id":"short1234",'
              '"spider-x":"/"'
              '}'
              '}'
              '],'
              '"proxy-groups":['
              '{'
              '"name":"Быстрые",'
              '"type":"select",'
              '"proxies":["Japan"]'
              '}'
              ']'
              '}',
          headers: <String, String>{},
        );
      },
    );

    final ImportLinkResult result = await resolver.resolve(
      'https://example.com/subscription.json',
    );

    expect(result.error, isNull);
    expect(result.link, isNotNull);
    expect(result.link!.profiles, hasLength(1));
    expect(result.link!.profiles.first.profile.host, '1.2.3.4');
    expect(result.link!.profiles.first.profile.security, 'reality');
    expect(result.link!.profiles.first.profile.publicKey, 'pubkey123');
    expect(result.link!.profiles.first.profile.shortId, 'short1234');
    expect(result.link!.profiles.first.profile.spiderX, '/');
    expect(result.link!.groups, hasLength(1));
    expect(result.link!.groups.first.name, 'Быстрые');
    expect(result.link!.groups.first.profiles, hasLength(1));
  });

  test('reports unsupported app placeholder from remote link', () async {
    final ImportLinkResolver resolver = ImportLinkResolver(
      fetcher: (Uri uri, Map<String, String> headers) async {
        return const RemoteLinkResponse(
          body:
              'dmxlc3M6Ly8wMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDBAMC4wLjAuMDoxP2VuY3J5cHRpb249bm9uZSZ0eXBlPXRjcCZzZWN1cml0eT1ub25lI0FwcCUyMG5vdCUyMHN1cHBvcnRlZA==',
          headers: <String, String>{'x-hwid-not-supported': 'true'},
        );
      },
    );

    final ImportLinkResult result = await resolver.resolve(
      'https://example.com/subscription',
    );

    expect(result.link, isNull);
    expect(result.error, ImportLinkError.remoteUnsupportedApp);
  });

  test('passes hwid headers into remote fetch and reports device limit', () async {
    final List<Map<String, String>> seenHeaders = <Map<String, String>>[];
    final ImportLinkResolver resolver = ImportLinkResolver(
      headersProvider: () async {
        return const <String, String>{
          'x-hwid': 'android-hwid-123',
          'x-device-os': 'Android',
          'x-ver-os': '15',
          'x-device-model': 'Pixel',
        };
      },
      fetcher: (Uri uri, Map<String, String> headers) async {
        seenHeaders.add(Map<String, String>.from(headers));
        return const RemoteLinkResponse(
          body: 'mixed-port: 7890\nproxies: []\n',
          headers: <String, String>{
            'x-hwid-active': 'true',
            'x-hwid-limit': 'true',
            'x-hwid-max-devices-reached': 'true',
          },
        );
      },
    );

    final ImportLinkResult result = await resolver.resolve(
      'https://example.com/subscription',
    );

    expect(seenHeaders, isNotEmpty);
    expect(seenHeaders.first['x-hwid'], 'android-hwid-123');
    expect(seenHeaders.first['x-device-os'], 'Android');
    expect(seenHeaders.first['User-Agent'], 'HApp/1.0 Android');
    expect(result.link, isNull);
    expect(result.error, ImportLinkError.remoteDeviceLimitReached);
  });

  test('tries happ-style client headers before legacy profiles', () async {
    late Map<String, String> seenHeaders;
    final ImportLinkResolver resolver = ImportLinkResolver(
      headersProvider: () async {
        return const <String, String>{'x-hwid': 'android-hwid-123'};
      },
      fetcher: (Uri uri, Map<String, String> headers) async {
        seenHeaders = headers;
        return const RemoteLinkResponse(
          body:
              '[{"remarks":"Самые быстрые","outbounds":[{"tag":"proxy","protocol":"vless","settings":{"vnext":[{"address":"5.188.115.3","port":443,"users":[{"id":"d6f3d24f-531b-4ed4-96ab-86ee585016bc","encryption":"none","flow":"xtls-rprx-vision"}]}]},"streamSettings":{"network":"tcp","security":"reality","realitySettings":{"serverName":"github.com","fingerprint":"chrome","publicKey":"pubkey123","shortId":"abcd1234"}}}]}]',
          headers: <String, String>{},
        );
      },
    );

    final ImportLinkResult result = await resolver.resolve(
      'https://example.com/subscription',
    );

    expect(seenHeaders['x-hwid'], 'android-hwid-123');
    expect(seenHeaders['User-Agent'], 'HApp/1.0 Android');
    expect(seenHeaders['Accept'], contains('application/json'));
    expect(result.error, isNull);
    expect(result.link, isNotNull);
    expect(result.link!.profiles, hasLength(1));
    expect(result.link!.profiles.first.profile.host, '5.188.115.3');
    expect(result.link!.profiles.first.profile.security, 'reality');
  });

  test('parses happ runtime json groups without exposing proxy tag', () async {
    final ImportLinkResolver resolver = ImportLinkResolver(
      fetcher: (Uri uri, Map<String, String> headers) async {
        return const RemoteLinkResponse(
          body:
              '['
              '{'
              '"remarks":"🏁 🇪🇺 Самые быстрые",'
              '"inbounds":[{"tag":"socks","port":10808,"listen":"127.0.0.1","protocol":"socks"}],'
              '"outbounds":['
              '{'
              '"tag":"proxy",'
              '"protocol":"vless",'
              '"settings":{"vnext":[{"address":"5.188.115.3","port":443,"users":[{"id":"d6f3d24f-531b-4ed4-96ab-86ee585016bc","encryption":"none","flow":"xtls-rprx-vision"}]}]},'
              '"streamSettings":{"network":"tcp","security":"reality","realitySettings":{"serverName":"github.com","fingerprint":"chrome","publicKey":"pubkey123","shortId":"abcd1234"}}'
              '},'
              '{'
              '"tag":"Германия 🇩🇪",'
              '"protocol":"vless",'
              '"settings":{"vnext":[{"address":"89.208.229.170","port":443,"users":[{"id":"d6f3d24f-531b-4ed4-96ab-86ee585016bc","encryption":"none","flow":"xtls-rprx-vision"}]}]},'
              '"streamSettings":{"network":"tcp","security":"reality","realitySettings":{"serverName":"github.com","fingerprint":"chrome","publicKey":"pubkey123","shortId":"abcd1234"}}'
              '},'
              '{'
              '"tag":"США 🇺🇸",'
              '"protocol":"vless",'
              '"settings":{"vnext":[{"address":"23.172.217.129","port":7443,"users":[{"id":"d6f3d24f-531b-4ed4-96ab-86ee585016bc","encryption":"none","flow":"xtls-rprx-vision"}]}]},'
              '"streamSettings":{"network":"tcp","security":"reality","realitySettings":{"serverName":"github.com","fingerprint":"chrome","publicKey":"pubkey123","shortId":"abcd1234"}}'
              '},'
              '{"tag":"direct","protocol":"freedom"},'
              '{"tag":"block","protocol":"blackhole"}'
              ']'
              '},'
              '{'
              '"remarks":"🇩🇪 Германия - WiFi / LTE",'
              '"inbounds":[{"tag":"socks","port":10808,"listen":"127.0.0.1","protocol":"socks"}],'
              '"outbounds":['
              '{'
              '"tag":"proxy",'
              '"protocol":"vless",'
              '"settings":{"vnext":[{"address":"89.208.229.170","port":443,"users":[{"id":"d6f3d24f-531b-4ed4-96ab-86ee585016bc","encryption":"none","flow":"xtls-rprx-vision"}]}]},'
              '"streamSettings":{"network":"tcp","security":"reality","realitySettings":{"serverName":"github.com","fingerprint":"chrome","publicKey":"pubkey123","shortId":"abcd1234"}}'
              '},'
              '{'
              '"tag":"Германия 🇩🇪",'
              '"protocol":"vless",'
              '"settings":{"vnext":[{"address":"89.208.229.170","port":443,"users":[{"id":"d6f3d24f-531b-4ed4-96ab-86ee585016bc","encryption":"none","flow":"xtls-rprx-vision"}]}]},'
              '"streamSettings":{"network":"tcp","security":"reality","realitySettings":{"serverName":"github.com","fingerprint":"chrome","publicKey":"pubkey123","shortId":"abcd1234"}}'
              '},'
              '{"tag":"direct","protocol":"freedom"}'
              ']'
              '}'
              ']',
          headers: <String, String>{},
        );
      },
    );

    final ImportLinkResult result = await resolver.resolve(
      'https://example.com/subscription',
    );

    expect(result.error, isNull);
    expect(result.link, isNotNull);
    expect(
      result.link!.groups.map((group) => group.name),
      containsAll(<String>['🏁 🇪🇺 Самые быстрые', '🇩🇪 Германия - WiFi / LTE']),
    );
    expect(
      result.link!.profiles.map((profile) => profile.profile.remark),
      isNot(contains('proxy')),
    );
    expect(
      result.link!.groups.first.profiles.map((profile) => profile.profile.remark),
      containsAll(<String>['Германия 🇩🇪', 'США 🇺🇸']),
    );
    expect(result.link!.groups.first.runtimeConfig, isNotNull);
    expect(result.link!.groups.first.runtimeConfig, contains('"protocol":"socks"'));
    expect(result.link!.groups.first.runtimeConfig, contains('"port":10807'));
    expect(result.link!.groups.first.runtimeConfig, contains('"outboundTag":"direct"'));
    expect(result.link!.groups.first.runtimeConfig, contains('89.208.229.170'));
    expect(result.link!.groups.first.runtimeConfig, contains('23.172.217.129'));
  });
}
