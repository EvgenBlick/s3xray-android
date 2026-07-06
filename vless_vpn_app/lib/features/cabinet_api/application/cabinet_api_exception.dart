class CabinetApiException implements Exception {
  const CabinetApiException(
    this.message, {
    this.statusCode,
    this.responseJson,
  });

  final String message;
  final int? statusCode;
  final Map<String, Object?>? responseJson;

  Object? get detail => responseJson?['detail'];

  @override
  String toString() => 'CabinetApiException($statusCode): $message';
}

class CabinetUnauthorizedException extends CabinetApiException {
  const CabinetUnauthorizedException([super.message = 'Unauthorized'])
      : super(statusCode: 401);
}
