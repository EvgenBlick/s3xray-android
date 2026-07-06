import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vless/flutter_vless.dart';
import 'package:vless_vpn_app/features/vpn/application/vpn_controller.dart';

void main() {
  group('VpnController', () {
    test('warmUp initializes native engine only once', () async {
      late _FakeFlutterVless fakeFlutterVless;
      final VpnController controller = VpnController(
        flutterVlessFactory: (void Function(VlessStatus) onStatusChanged) {
          fakeFlutterVless = _FakeFlutterVless(onStatusChanged);
          return fakeFlutterVless;
        },
        supportsNativeVpn: true,
      );
      addTearDown(controller.dispose);

      await controller.warmUp();
      await controller.connectFromConfig(
        runtimeConfig: '{"outbounds":[]}',
        remark: 'DE #1',
        connectionId: 'group:de-1',
      );

      expect(fakeFlutterVless.initializeCalls, 1);
    });

    test(
      'connectFromConfig stays connecting until native connected status',
      () async {
        late _FakeFlutterVless fakeFlutterVless;
        final VpnController controller = VpnController(
          flutterVlessFactory: (void Function(VlessStatus) onStatusChanged) {
            fakeFlutterVless = _FakeFlutterVless(onStatusChanged);
            return fakeFlutterVless;
          },
          supportsNativeVpn: true,
        );
        addTearDown(controller.dispose);

        await controller.connectFromConfig(
          runtimeConfig: '{"outbounds":[]}',
          remark: 'DE #1',
          connectionId: 'group:de-1',
        );

        expect(controller.snapshot.state, VpnConnectionState.connecting);
        expect(controller.snapshot.statusText, 'starting_tunnel');
        expect(controller.activeShareLink, isNull);

        fakeFlutterVless.emit('CONNECTED');

        expect(controller.snapshot.state, VpnConnectionState.connected);
        expect(controller.activeShareLink, 'group:de-1');
      },
    );

    test(
      'disconnect waits for native disconnected status before going idle',
      () async {
        late _FakeFlutterVless fakeFlutterVless;
        final VpnController controller = VpnController(
          flutterVlessFactory: (void Function(VlessStatus) onStatusChanged) {
            fakeFlutterVless = _FakeFlutterVless(onStatusChanged);
            return fakeFlutterVless;
          },
          supportsNativeVpn: true,
        );
        addTearDown(controller.dispose);

        await controller.connectFromConfig(
          runtimeConfig: '{"outbounds":[]}',
          remark: 'DE #1',
          connectionId: 'group:de-1',
        );
        fakeFlutterVless.emit('CONNECTED');

        await controller.disconnect();

        expect(controller.snapshot.state, VpnConnectionState.disconnecting);
        expect(controller.activeShareLink, 'group:de-1');

        fakeFlutterVless.emit('DISCONNECTED');

        expect(controller.snapshot.state, VpnConnectionState.idle);
        expect(controller.activeShareLink, isNull);
      },
    );

    test(
      'switching server keeps connecting state through old disconnect event',
      () async {
        late _FakeFlutterVless fakeFlutterVless;
        final VpnController controller = VpnController(
          flutterVlessFactory: (void Function(VlessStatus) onStatusChanged) {
            fakeFlutterVless = _FakeFlutterVless(onStatusChanged);
            return fakeFlutterVless;
          },
          supportsNativeVpn: true,
        );
        addTearDown(controller.dispose);

        await controller.connectFromConfig(
          runtimeConfig: '{"outbounds":[]}',
          remark: 'DE #1',
          connectionId: 'group:de-1',
        );
        fakeFlutterVless.emit('CONNECTED');

        await controller.connectFromConfig(
          runtimeConfig: '{"outbounds":[]}',
          remark: 'NL #1',
          connectionId: 'group:nl-1',
        );

        expect(fakeFlutterVless.stopCalls, 0);
        expect(controller.snapshot.state, VpnConnectionState.connecting);
        expect(controller.snapshot.statusText, 'switching_server');
        expect(controller.activeShareLink, 'group:de-1');

        fakeFlutterVless.emit('CONNECTED');

        expect(controller.snapshot.state, VpnConnectionState.connected);
        expect(controller.activeShareLink, 'group:nl-1');
      },
    );

    test(
      'switching server while first connection is still connecting retargets tunnel',
      () async {
        late _FakeFlutterVless fakeFlutterVless;
        final VpnController controller = VpnController(
          flutterVlessFactory: (void Function(VlessStatus) onStatusChanged) {
            fakeFlutterVless = _FakeFlutterVless(onStatusChanged);
            return fakeFlutterVless;
          },
          supportsNativeVpn: true,
        );
        addTearDown(controller.dispose);

        await controller.connectFromConfig(
          runtimeConfig: '{"outbounds":[]}',
          remark: 'DE #1',
          connectionId: 'group:de-1',
        );

        expect(controller.currentConnectionId, 'group:de-1');

        await controller.connectFromConfig(
          runtimeConfig: '{"outbounds":[]}',
          remark: 'NL #1',
          connectionId: 'group:nl-1',
        );

        expect(fakeFlutterVless.stopCalls, 0);
        expect(fakeFlutterVless.startCalls, 2);
        expect(controller.currentConnectionId, 'group:nl-1');
        expect(controller.snapshot.state, VpnConnectionState.connecting);
        expect(controller.snapshot.statusText, 'switching_server');

        fakeFlutterVless.emit('CONNECTED');

        expect(controller.snapshot.state, VpnConnectionState.connected);
        expect(controller.activeShareLink, 'group:nl-1');
        expect(controller.currentConnectionId, 'group:nl-1');
      },
    );

    test(
      'late disconnect from previous tunnel is ignored after new tunnel connects',
      () async {
        late _FakeFlutterVless fakeFlutterVless;
        final VpnController controller = VpnController(
          flutterVlessFactory: (void Function(VlessStatus) onStatusChanged) {
            fakeFlutterVless = _FakeFlutterVless(onStatusChanged);
            return fakeFlutterVless;
          },
          supportsNativeVpn: true,
        );
        addTearDown(controller.dispose);

        await controller.connectFromConfig(
          runtimeConfig: '{"outbounds":[]}',
          remark: 'DE #1',
          connectionId: 'group:de-1',
        );
        fakeFlutterVless.emit('CONNECTED');

        await controller.connectFromConfig(
          runtimeConfig: '{"outbounds":[]}',
          remark: 'NL #1',
          connectionId: 'group:nl-1',
        );
        fakeFlutterVless.emit('CONNECTED');

        expect(controller.snapshot.state, VpnConnectionState.connected);
        expect(controller.activeShareLink, 'group:nl-1');

        fakeFlutterVless.emit('DISCONNECTED');

        expect(controller.snapshot.state, VpnConnectionState.connected);
        expect(controller.activeShareLink, 'group:nl-1');
      },
    );

    test(
      'pending switch target is not treated as active before native reconnect completes',
      () async {
        late _FakeFlutterVless fakeFlutterVless;
        final VpnController controller = VpnController(
          flutterVlessFactory: (void Function(VlessStatus) onStatusChanged) {
            fakeFlutterVless = _FakeFlutterVless(onStatusChanged);
            return fakeFlutterVless;
          },
          supportsNativeVpn: true,
        );
        addTearDown(controller.dispose);

        await controller.connectFromConfig(
          runtimeConfig: '{"outbounds":[]}',
          remark: 'DE #1',
          connectionId: 'group:de-1',
        );
        fakeFlutterVless.emit('CONNECTED');

        await controller.connectFromConfig(
          runtimeConfig: '{"outbounds":[]}',
          remark: 'NL #1',
          connectionId: 'group:nl-1',
        );

        expect(controller.currentConnectionId, 'group:nl-1');
        expect(controller.isActiveConnection('group:nl-1'), isFalse);
        expect(controller.isActiveConnection('group:de-1'), isTrue);
      },
    );

    test('dispose releases native status listener owner', () {
      late _FakeFlutterVless fakeFlutterVless;
      final VpnController controller = VpnController(
        flutterVlessFactory: (void Function(VlessStatus) onStatusChanged) {
          fakeFlutterVless = _FakeFlutterVless(onStatusChanged);
          return fakeFlutterVless;
        },
        supportsNativeVpn: true,
      );

      controller.dispose();

      expect(fakeFlutterVless.disposeCalls, 1);
    });
  });
}

class _FakeFlutterVless extends FlutterVless {
  _FakeFlutterVless(this._listener) : super(onStatusChanged: _noop);

  final void Function(VlessStatus status) _listener;
  int initializeCalls = 0;
  int requestPermissionCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;
  bool permissionGranted = true;
  Future<void> Function()? onStart;
  Future<void> Function()? onStop;

  @override
  Future<void> initializeVless({
    String notificationIconResourceType = 'mipmap',
    String notificationIconResourceName = 'ic_launcher',
    String providerBundleIdentifier = '',
    String groupIdentifier = '',
  }) async {
    initializeCalls += 1;
  }

  @override
  Future<bool> requestPermission() async {
    requestPermissionCalls += 1;
    return permissionGranted;
  }

  @override
  Future<void> startVless({
    required String remark,
    required String config,
    List<String>? blockedApps,
    List<String>? bypassSubnets,
    bool proxyOnly = false,
    String notificationDisconnectButtonName = 'DISCONNECT',
  }) async {
    startCalls += 1;
    if (onStart != null) {
      await onStart!();
    }
  }

  @override
  Future<void> stopVless() async {
    stopCalls += 1;
    if (onStop != null) {
      await onStop!();
    }
  }

  @override
  void dispose() {
    disposeCalls += 1;
  }

  void emit(String state) {
    _listener(VlessStatus(state: state));
  }

  static void _noop(VlessStatus _) {}
}
