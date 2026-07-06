import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_vless/flutter_vless.dart';

enum VpnConnectionState { idle, connecting, connected, disconnecting, error }

typedef FlutterVlessFactory =
    FlutterVless Function(void Function(VlessStatus status) onStatusChanged);

class VpnStatusSnapshot {
  const VpnStatusSnapshot({
    required this.state,
    required this.statusText,
    this.detail,
    this.connectedSince,
    this.connectionDuration,
  });

  final VpnConnectionState state;
  final String statusText;
  final String? detail;
  final DateTime? connectedSince;
  final Duration? connectionDuration;

  VpnStatusSnapshot copyWith({
    VpnConnectionState? state,
    String? statusText,
    String? detail,
    DateTime? connectedSince,
    Duration? connectionDuration,
    bool clearDetail = false,
    bool clearConnectedSince = false,
    bool clearConnectionDuration = false,
  }) {
    return VpnStatusSnapshot(
      state: state ?? this.state,
      statusText: statusText ?? this.statusText,
      detail: clearDetail ? null : (detail ?? this.detail),
      connectedSince: clearConnectedSince
          ? null
          : (connectedSince ?? this.connectedSince),
      connectionDuration: clearConnectionDuration
          ? null
          : (connectionDuration ?? this.connectionDuration),
    );
  }
}

class VpnController extends ChangeNotifier {
  VpnController({
    FlutterVlessFactory? flutterVlessFactory,
    bool? supportsNativeVpn,
  }) : _supportsNativeVpnOverride = supportsNativeVpn {
    if (_supportsNativeVpn) {
      _flutterVless =
          (flutterVlessFactory ??
          ((void Function(VlessStatus status) onStatusChanged) => FlutterVless(
            onStatusChanged: onStatusChanged,
          )))(_handleStatusChanged);
    }
  }

  FlutterVless? _flutterVless;
  final bool? _supportsNativeVpnOverride;
  bool _initialized = false;
  Future<void>? _initializationFuture;
  String? _activeShareLink;
  String? _desiredConnectionId;
  bool _switchInProgress = false;
  bool _ignoreNextDisconnectAfterSwitch = false;
  DateTime? _connectedSince;
  Timer? _connectionTicker;
  VpnStatusSnapshot _snapshot = const VpnStatusSnapshot(
    state: VpnConnectionState.idle,
    statusText: 'idle',
  );

  VpnStatusSnapshot get snapshot => _snapshot;
  String? get activeShareLink => _activeShareLink;
  String? get currentConnectionId => _desiredConnectionId ?? _activeShareLink;
  bool isActiveConnection(String? connectionId) =>
      _activeShareLink == connectionId;

  bool get _supportsNativeVpn =>
      _supportsNativeVpnOverride ??
      (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  Future<void> warmUp() async {
    if (!_supportsNativeVpn || _flutterVless == null) {
      return;
    }

    try {
      await _ensureInitialized();
    } catch (_) {
      // Retry lazily on the next explicit connect attempt.
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    final Future<void>? pendingInitialization = _initializationFuture;
    if (pendingInitialization != null) {
      await pendingInitialization;
      return;
    }

    final Future<void> initialization = _flutterVless!.initializeVless().then((
      _,
    ) {
      _initialized = true;
    });
    _initializationFuture = initialization;
    try {
      await initialization;
    } catch (_) {
      _initializationFuture = null;
      rethrow;
    }
  }

  Future<void> connectFromLink({
    required String shareLink,
    required String remarkFallback,
    List<String>? blockedApps,
  }) async {
    if (!_supportsNativeVpn) {
      _setSnapshot(
        const VpnStatusSnapshot(
          state: VpnConnectionState.error,
          statusText: 'unsupported_platform',
          detail: 'vpn_supported_only_on_android_or_ios',
        ),
      );
      return;
    }

    final FlutterVless flutterVless = _flutterVless!;
    final String? currentConnectionId = this.currentConnectionId;
    final bool switchingServer =
        currentConnectionId != null &&
        currentConnectionId != shareLink &&
        (_snapshot.state == VpnConnectionState.connected ||
            _snapshot.state == VpnConnectionState.connecting);

    _setSnapshot(
      VpnStatusSnapshot(
        state: VpnConnectionState.connecting,
        statusText: switchingServer ? 'switching_server' : 'initializing',
      ),
    );
    _desiredConnectionId = shareLink;
    _switchInProgress = switchingServer;

    try {
      await _ensureInitialized();

      final FlutterVlessURL parsed = FlutterVless.parseFromURL(shareLink);
      final String config = parsed.getFullConfiguration();

      final bool allowed = await flutterVless.requestPermission();
      if (!allowed) {
        _desiredConnectionId = null;
        _switchInProgress = false;
        _setSnapshot(
          const VpnStatusSnapshot(
            state: VpnConnectionState.error,
            statusText: 'permission_denied',
          ),
        );
        return;
      }

      await flutterVless.startVless(
        remark: parsed.remark.isNotEmpty ? parsed.remark : remarkFallback,
        config: config,
        proxyOnly: false,
        blockedApps: blockedApps,
        bypassSubnets: const <String>['0.0.0.0/0', '::/0'],
      );

      _setSnapshot(
        VpnStatusSnapshot(
          state: VpnConnectionState.connecting,
          statusText: switchingServer ? 'switching_server' : 'starting_tunnel',
        ),
      );
    } catch (error) {
      _desiredConnectionId = null;
      _switchInProgress = false;
      _ignoreNextDisconnectAfterSwitch = false;
      _activeShareLink = null;
      _setSnapshot(
        VpnStatusSnapshot(
          state: VpnConnectionState.error,
          statusText: 'connect_failed',
          detail: error.toString(),
        ),
      );
    }
  }

  Future<void> connectFromConfig({
    required String runtimeConfig,
    required String remark,
    required String connectionId,
    List<String>? blockedApps,
  }) async {
    if (!_supportsNativeVpn) {
      _setSnapshot(
        const VpnStatusSnapshot(
          state: VpnConnectionState.error,
          statusText: 'unsupported_platform',
          detail: 'vpn_supported_only_on_android_or_ios',
        ),
      );
      return;
    }

    final FlutterVless flutterVless = _flutterVless!;
    final String? currentConnectionId = this.currentConnectionId;
    final bool switchingServer =
        currentConnectionId != null &&
        currentConnectionId != connectionId &&
        (_snapshot.state == VpnConnectionState.connected ||
            _snapshot.state == VpnConnectionState.connecting);

    _setSnapshot(
      VpnStatusSnapshot(
        state: VpnConnectionState.connecting,
        statusText: switchingServer ? 'switching_server' : 'initializing',
      ),
    );
    _desiredConnectionId = connectionId;
    _switchInProgress = switchingServer;

    try {
      await _ensureInitialized();

      final bool allowed = await flutterVless.requestPermission();
      if (!allowed) {
        _desiredConnectionId = null;
        _switchInProgress = false;
        _setSnapshot(
          const VpnStatusSnapshot(
            state: VpnConnectionState.error,
            statusText: 'permission_denied',
          ),
        );
        return;
      }

      await flutterVless.startVless(
        remark: remark,
        config: runtimeConfig,
        proxyOnly: false,
        blockedApps: blockedApps,
        bypassSubnets: const <String>['0.0.0.0/0', '::/0'],
      );

      _setSnapshot(
        VpnStatusSnapshot(
          state: VpnConnectionState.connecting,
          statusText: switchingServer ? 'switching_server' : 'starting_tunnel',
        ),
      );
    } catch (error) {
      _desiredConnectionId = null;
      _switchInProgress = false;
      _ignoreNextDisconnectAfterSwitch = false;
      _activeShareLink = null;
      _setSnapshot(
        VpnStatusSnapshot(
          state: VpnConnectionState.error,
          statusText: 'connect_failed',
          detail: error.toString(),
        ),
      );
    }
  }

  Future<void> disconnect() async {
    if (!_supportsNativeVpn || _flutterVless == null) {
      return;
    }

    _desiredConnectionId = null;
    _switchInProgress = false;
    _ignoreNextDisconnectAfterSwitch = false;
    _setSnapshot(
      const VpnStatusSnapshot(
        state: VpnConnectionState.disconnecting,
        statusText: 'disconnecting',
      ),
    );

    try {
      await _flutterVless!.stopVless();
    } catch (error) {
      _setSnapshot(
        VpnStatusSnapshot(
          state: VpnConnectionState.error,
          statusText: 'disconnect_failed',
          detail: error.toString(),
        ),
      );
    }
  }

  void _handleStatusChanged(dynamic status) {
    final String raw = status is VlessStatus
        ? status.state.toLowerCase()
        : status.toString().toLowerCase();
    if (raw.contains('disconnect') || raw.contains('stop')) {
      if (_switchInProgress || _desiredConnectionId != null) {
        _setSnapshot(
          const VpnStatusSnapshot(
            state: VpnConnectionState.connecting,
            statusText: 'switching_server',
          ),
        );
        return;
      }

      if (_ignoreNextDisconnectAfterSwitch && _activeShareLink != null) {
        _ignoreNextDisconnectAfterSwitch = false;
        return;
      }

      _desiredConnectionId = null;
      _activeShareLink = null;
      _setSnapshot(
        VpnStatusSnapshot(state: VpnConnectionState.idle, statusText: raw),
      );
      return;
    }

    if (raw.contains('connecting')) {
      _setSnapshot(
        VpnStatusSnapshot(
          state: VpnConnectionState.connecting,
          statusText: raw,
        ),
      );
      return;
    }

    if (raw.contains('error') || raw.contains('fail')) {
      _desiredConnectionId = null;
      _activeShareLink = null;
      _setSnapshot(
        VpnStatusSnapshot(
          state: VpnConnectionState.error,
          statusText: raw,
          detail: raw,
        ),
      );
      return;
    }

    if (raw.contains('connect')) {
      final bool completedSwitch =
          _switchInProgress || _desiredConnectionId != null;
      _activeShareLink = _desiredConnectionId ?? _activeShareLink;
      _desiredConnectionId = null;
      _switchInProgress = false;
      _ignoreNextDisconnectAfterSwitch = completedSwitch;
      _setSnapshot(
        VpnStatusSnapshot(state: VpnConnectionState.connected, statusText: raw),
      );
      return;
    }

    _setSnapshot(
      VpnStatusSnapshot(state: VpnConnectionState.connecting, statusText: raw),
    );
  }

  void _setSnapshot(VpnStatusSnapshot snapshot) {
    if (snapshot.state == VpnConnectionState.connected) {
      final DateTime now = DateTime.now();
      _connectedSince ??= now;
      _startConnectionTicker();
      snapshot = snapshot.copyWith(
        connectedSince: _connectedSince,
        connectionDuration: now.difference(_connectedSince!),
      );
    } else {
      _stopConnectionTicker();
      _connectedSince = null;
      snapshot = snapshot.copyWith(
        clearConnectedSince: true,
        clearConnectionDuration: true,
      );
    }

    _snapshot = snapshot;
    notifyListeners();
  }

  void _startConnectionTicker() {
    _connectionTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final DateTime? connectedSince = _connectedSince;
      if (connectedSince == null ||
          _snapshot.state != VpnConnectionState.connected) {
        _stopConnectionTicker();
        return;
      }

      _snapshot = _snapshot.copyWith(
        connectedSince: connectedSince,
        connectionDuration: DateTime.now().difference(connectedSince),
      );
      notifyListeners();
    });
  }

  void _stopConnectionTicker() {
    _connectionTicker?.cancel();
    _connectionTicker = null;
  }

  @override
  void dispose() {
    _stopConnectionTicker();
    _flutterVless?.dispose();
    super.dispose();
  }
}
