import 'dart:convert';
import 'dart:io';

import 'cabinet_api_exception.dart';

class CabinetHttpClient {
  CabinetHttpClient({required Uri baseUri}) : _baseUri = baseUri;

  final Uri _baseUri;

  Future<Map<String, Object?>> getJson(String path, {String? bearerToken}) {
    return _sendMapRequest(method: 'GET', path: path, bearerToken: bearerToken);
  }

  Future<List<Object?>> getJsonList(String path, {String? bearerToken}) {
    return _sendListRequest(
      method: 'GET',
      path: path,
      bearerToken: bearerToken,
    );
  }

  Future<Map<String, Object?>> postJson(
    String path, {
    String? bearerToken,
    Map<String, Object?> body = const <String, Object?>{},
  }) {
    return _sendMapRequest(
      method: 'POST',
      path: path,
      bearerToken: bearerToken,
      body: body,
    );
  }

  Future<Map<String, Object?>> _sendMapRequest({
    required String method,
    required String path,
    String? bearerToken,
    Map<String, Object?>? body,
  }) async {
    final Object? payload = await _sendRequest(
      method: method,
      path: path,
      bearerToken: bearerToken,
      body: body,
    );
    if (payload is Map<Object?, Object?>) {
      return payload.cast<String, Object?>();
    }
    throw const CabinetApiException('Invalid API response format');
  }

  Future<List<Object?>> _sendListRequest({
    required String method,
    required String path,
    String? bearerToken,
    Map<String, Object?>? body,
  }) async {
    final Object? payload = await _sendRequest(
      method: method,
      path: path,
      bearerToken: bearerToken,
      body: body,
    );
    if (payload is List<Object?>) {
      return payload;
    }
    if (payload is List) {
      return payload.cast<Object?>();
    }
    throw const CabinetApiException('Invalid API response format');
  }

  Future<Object?> _sendRequest({
    required String method,
    required String path,
    String? bearerToken,
    Map<String, Object?>? body,
  }) async {
    final HttpClient client = HttpClient();
    try {
      final Uri requestUri = _baseUri.resolve(path);
      final HttpClientRequest request = await client.openUrl(
        method,
        requestUri,
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (bearerToken != null && bearerToken.trim().isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${bearerToken.trim()}',
        );
      }
      if (body != null && body.isNotEmpty) {
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

      return decodedPayload;
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
