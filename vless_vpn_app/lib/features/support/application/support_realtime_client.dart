import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../cabinet_api/application/cabinet_api_endpoints.dart';
import '../domain/support_ws_event.dart';

class SupportRealtimeClient {
  SupportRealtimeClient({Uri? baseUri})
    : _baseUri = baseUri ?? Uri.parse(defaultCabinetApiBaseUrl);

  final Uri _baseUri;
  WebSocket? _socket;
  Timer? _pingTimer;
  StreamController<SupportWsEvent>? _eventsController;
  String? _currentToken;

  Stream<SupportWsEvent> connect(String accessToken) {
    if (_eventsController != null && _currentToken == accessToken) {
      return _eventsController!.stream;
    }

    dispose();
    _currentToken = accessToken;
    late final StreamController<SupportWsEvent> controller;
    controller = StreamController<SupportWsEvent>.broadcast(
      onCancel: () {
        if (!controller.hasListener) {
          dispose();
        }
      },
    );
    _eventsController = controller;
    unawaited(_openSocket(accessToken, controller));
    return controller.stream;
  }

  Future<void> _openSocket(
    String accessToken,
    StreamController<SupportWsEvent> controller,
  ) async {
    try {
      final Uri socketUri = _buildSocketUri(accessToken);
      final WebSocket socket = await WebSocket.connect(socketUri.toString());
      _socket = socket;
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        socket.add(jsonEncode(const <String, String>{'type': 'ping'}));
      });

      socket.listen(
        (dynamic data) {
          if (data is! String) {
            return;
          }
          try {
            final Object? payload = jsonDecode(data);
            if (payload is! Map) {
              return;
            }
            final SupportWsEvent event = SupportWsEvent.fromJson(
              payload.cast<String, Object?>(),
            );
            if (!controller.isClosed) {
              controller.add(event);
            }
          } catch (_) {
            return;
          }
        },
        onDone: () {
          _pingTimer?.cancel();
          _pingTimer = null;
          _socket = null;
        },
        onError: (_) {
          _pingTimer?.cancel();
          _pingTimer = null;
          _socket = null;
        },
        cancelOnError: true,
      );
    } catch (_) {
      _socket = null;
    }
  }

  Uri _buildSocketUri(String accessToken) {
    final String scheme = _baseUri.scheme == 'https' ? 'wss' : 'ws';
    return _baseUri.replace(
      scheme: scheme,
      path: '/cabinet/ws',
      queryParameters: <String, String>{'token': accessToken},
    );
  }

  void dispose() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _socket?.close();
    _socket = null;
    _currentToken = null;
    _eventsController?.close();
    _eventsController = null;
  }
}
