import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../import/domain/resolved_profile_link.dart';

enum ServerLatencyState {
  unknown,
  probing,
  online,
  offline,
  unsupported,
}

class ServerLatencySnapshot {
  const ServerLatencySnapshot({
    required this.state,
    this.pingMs,
    this.detail,
  });

  final ServerLatencyState state;
  final int? pingMs;
  final String? detail;

  static const ServerLatencySnapshot unknownState = ServerLatencySnapshot(
    state: ServerLatencyState.unknown,
  );
}

class ServerLatencyProbe extends ChangeNotifier {
  int _generation = 0;
  Map<String, ServerLatencySnapshot> _snapshots =
      <String, ServerLatencySnapshot>{};
  Timer? _notifyTimer;

  bool get _supportsSocketProbe =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  ServerLatencySnapshot snapshotFor(String resolvedLink) {
    return _snapshots[resolvedLink] ?? ServerLatencySnapshot.unknownState;
  }

  Future<void> probeProfiles(List<ResolvedProfileLink> profiles) async {
    final int generation = ++_generation;

    if (profiles.isEmpty) {
      _snapshots = <String, ServerLatencySnapshot>{};
      notifyListeners();
      return;
    }

    if (!_supportsSocketProbe) {
      _snapshots = <String, ServerLatencySnapshot>{
        for (final ResolvedProfileLink profile in profiles)
          profile.resolvedLink: const ServerLatencySnapshot(
            state: ServerLatencyState.unsupported,
            detail: 'probe_supported_only_on_android_or_ios',
          ),
      };
      notifyListeners();
      return;
    }

    _snapshots = <String, ServerLatencySnapshot>{
      for (final ResolvedProfileLink profile in profiles)
        profile.resolvedLink: const ServerLatencySnapshot(
          state: ServerLatencyState.probing,
        ),
    };
    notifyListeners();

    final Iterable<Future<void>> tasks = profiles.map(
      (ResolvedProfileLink profile) async {
        final ServerLatencySnapshot snapshot = await _probeTcp(profile);
        if (generation != _generation) {
          return;
        }

        _snapshots[profile.resolvedLink] = snapshot;
        _scheduleNotify();
      },
    );

    await Future.wait(tasks);
    if (generation == _generation) {
      _flushNotify();
    }
  }

  Future<ServerLatencySnapshot> _probeTcp(ResolvedProfileLink profile) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    try {
      final Socket socket = await Socket.connect(
        profile.profile.host,
        profile.profile.port,
        timeout: const Duration(seconds: 2),
      );
      stopwatch.stop();
      await socket.close();

      return ServerLatencySnapshot(
        state: ServerLatencyState.online,
        pingMs: stopwatch.elapsedMilliseconds,
        detail: 'tcp_reachable',
      );
    } catch (error) {
      stopwatch.stop();
      return ServerLatencySnapshot(
        state: ServerLatencyState.offline,
        detail: error.toString(),
      );
    }
  }

  void clear() {
    _generation++;
    _notifyTimer?.cancel();
    _notifyTimer = null;
    _snapshots = <String, ServerLatencySnapshot>{};
    notifyListeners();
  }

  void _scheduleNotify() {
    _notifyTimer ??= Timer(const Duration(milliseconds: 80), _flushNotify);
  }

  void _flushNotify() {
    _notifyTimer?.cancel();
    _notifyTimer = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    super.dispose();
  }
}
