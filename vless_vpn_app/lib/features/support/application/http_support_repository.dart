import 'dart:convert';
import 'dart:io';

import '../../cabinet_api/application/cabinet_api_endpoints.dart';
import '../../cabinet_api/application/cabinet_api_exception.dart';
import '../../cabinet_api/application/cabinet_http_client.dart';
import '../../cabinet_api/domain/cabinet_session.dart';
import '../domain/support_ticket.dart';
import '../domain/support_ticket_list_response.dart';
import '../domain/support_ticket_message.dart';
import 'support_repository.dart';

class HttpSupportRepository implements SupportRepository {
  HttpSupportRepository({required CabinetHttpClient httpClient, Uri? baseUri})
    : _httpClient = httpClient,
      _baseUri = baseUri ?? Uri.parse(defaultCabinetApiBaseUrl);

  final CabinetHttpClient _httpClient;
  final Uri _baseUri;

  @override
  Future<SupportTicketListResponse> listTickets(
    CabinetSession session, {
    int page = 1,
    int perPage = 50,
    String? status,
  }) async {
    final Uri uri = Uri(
      path: '/cabinet/tickets',
      queryParameters: <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      },
    );
    final Map<String, Object?> json = await _httpClient.getJson(
      uri.toString(),
      bearerToken: session.accessToken,
    );
    return SupportTicketListResponse.fromJson(json);
  }

  @override
  Future<SupportTicket> getTicket(CabinetSession session, int ticketId) async {
    final Map<String, Object?> json = await _httpClient.getJson(
      '/cabinet/tickets/$ticketId',
      bearerToken: session.accessToken,
    );
    return SupportTicket.fromDetailJson(json);
  }

  @override
  Future<SupportTicket> createTicket(
    CabinetSession session, {
    required String title,
    required String message,
  }) async {
    final Map<String, Object?> json = await _postJsonMap(
      '/cabinet/tickets',
      bearerToken: session.accessToken,
      body: <String, Object?>{'title': title.trim(), 'message': message.trim()},
    );
    return SupportTicket.fromDetailJson(json);
  }

  @override
  Future<SupportTicketMessage> addMessage(
    CabinetSession session, {
    required int ticketId,
    required String message,
  }) async {
    final Map<String, Object?> json = await _postJsonMap(
      '/cabinet/tickets/$ticketId/messages',
      bearerToken: session.accessToken,
      body: <String, Object?>{'message': message.trim()},
    );
    return SupportTicketMessage.fromJson(json);
  }

  @override
  Future<SupportTicket> closeTicket(
    CabinetSession session,
    int ticketId,
  ) async {
    final Map<String, Object?> json = await _postJsonMap(
      '/cabinet/tickets/$ticketId/close',
      bearerToken: session.accessToken,
    );
    return SupportTicket.fromDetailJson(json);
  }

  Future<Map<String, Object?>> _postJsonMap(
    String path, {
    required String bearerToken,
    Map<String, Object?> body = const <String, Object?>{},
  }) async {
    final HttpClient client = HttpClient();
    try {
      final Uri requestUri = _baseUri.resolve(path);
      final HttpClientRequest request = await client.postUrl(requestUri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${bearerToken.trim()}',
      );
      if (body.isNotEmpty) {
        request.add(utf8.encode(jsonEncode(body)));
      }

      final HttpClientResponse response = await request.close();
      final String payload = await utf8.decodeStream(response);
      final Object? decodedPayload = payload.trim().isEmpty
          ? <String, Object?>{}
          : jsonDecode(payload);
      final Map<String, Object?> responseJson = decodedPayload is Map
          ? decodedPayload.cast<String, Object?>()
          : <String, Object?>{};

      if (response.statusCode == HttpStatus.unauthorized) {
        throw const CabinetUnauthorizedException();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CabinetApiException(
          _extractErrorMessage(responseJson),
          statusCode: response.statusCode,
          responseJson: responseJson,
        );
      }
      return responseJson;
    } on SocketException catch (error) {
      throw CabinetApiException('Network error: ${error.message}');
    } on FormatException {
      throw const CabinetApiException('Invalid API response format');
    } finally {
      client.close(force: true);
    }
  }

  String _extractErrorMessage(Map<String, Object?> json) {
    final Object? detail = json['detail'];
    if (detail is String && detail.trim().isNotEmpty) {
      return detail;
    }
    if (detail is Map<Object?, Object?>) {
      final Object? nestedMessage = detail['message'];
      if (nestedMessage is String && nestedMessage.trim().isNotEmpty) {
        return nestedMessage;
      }
    }
    return 'API request failed';
  }
}
