import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vless_vpn_app/features/cabinet_api/application/cabinet_http_client.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_session.dart';
import 'package:vless_vpn_app/features/support/application/http_support_repository.dart';

void main() {
  final CabinetSession session = CabinetSession(
    accessToken: 'access',
    refreshToken: 'refresh',
    tokenType: 'bearer',
    expiresAt: DateTime.utc(2030, 1, 1),
  );

  test('createTicket sends utf8 json payload correctly', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(server.close);

    String? receivedBody;
    String? receivedAuth;
    () async {
      await for (final HttpRequest request in server) {
        receivedAuth = request.headers.value(HttpHeaders.authorizationHeader);
        receivedBody = await utf8.decodeStream(request);
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(<String, Object?>{
              'id': 10,
              'title': 'Не работает VPN',
              'status': 'open',
              'priority': 'normal',
              'created_at': '2026-04-12T12:00:00Z',
              'updated_at': '2026-04-12T12:00:00Z',
              'closed_at': null,
              'is_reply_blocked': false,
              'messages': <Object?>[
                <String, Object?>{
                  'id': 11,
                  'message_text': 'Помогите что как дела?',
                  'is_from_admin': false,
                  'has_media': false,
                  'created_at': '2026-04-12T12:00:00Z',
                },
              ],
            }),
          )
          ..close();
      }
    }();

    final Uri baseUri = Uri.parse('http://127.0.0.1:${server.port}');
    final HttpSupportRepository repository = HttpSupportRepository(
      httpClient: CabinetHttpClient(baseUri: baseUri),
      baseUri: baseUri,
    );

    await repository.createTicket(
      session,
      title: 'Не работает VPN',
      message: 'Помогите что как дела?',
    );

    expect(receivedAuth, 'Bearer access');
    expect(jsonDecode(receivedBody!) as Map<String, Object?>, <String, Object?>{
      'title': 'Не работает VPN',
      'message': 'Помогите что как дела?',
    });
  });
}
