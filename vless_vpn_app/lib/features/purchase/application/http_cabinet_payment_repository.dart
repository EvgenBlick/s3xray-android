import '../../cabinet_api/application/cabinet_api_exception.dart';
import '../../cabinet_api/application/cabinet_http_client.dart';
import '../../cabinet_api/domain/cabinet_session.dart';
import '../domain/cabinet_payment_method.dart';
import '../domain/cabinet_top_up_payment.dart';
import 'cabinet_payment_repository.dart';

class HttpCabinetPaymentRepository implements CabinetPaymentRepository {
  HttpCabinetPaymentRepository({
    required CabinetHttpClient httpClient,
  }) : _httpClient = httpClient;

  final CabinetHttpClient _httpClient;

  @override
  Future<List<CabinetPaymentMethod>> getPaymentMethods(
    CabinetSession session,
  ) async {
    final List<Object?> rawMethods = await _httpClient.getJsonList(
      '/cabinet/balance/payment-methods',
      bearerToken: session.accessToken,
    );
    if (rawMethods.isEmpty) {
      throw const CabinetApiException('Payment methods are unavailable');
    }

    return rawMethods
        .whereType<Map<Object?, Object?>>()
        .map(
          (Map<Object?, Object?> item) => CabinetPaymentMethod.fromJson(
            item.cast<String, Object?>(),
          ),
        )
        .toList();
  }

  @override
  Future<CabinetTopUpPayment> createTopUp(
    CabinetSession session, {
    required int amountKopeks,
    required CabinetPaymentMethod paymentMethod,
    String? paymentOptionId,
  }) async {
    final Map<String, Object?> json = await _httpClient.postJson(
      '/cabinet/balance/topup',
      bearerToken: session.accessToken,
      body: <String, Object?>{
        'amount_kopeks': amountKopeks,
        'payment_method': paymentMethod.id,
        if (paymentOptionId != null && paymentOptionId.trim().isNotEmpty)
          'payment_option': paymentOptionId.trim(),
      },
    );
    final String paymentUrl = (json['payment_url'] as String? ?? '').trim();
    if (paymentUrl.isEmpty) {
      throw const CabinetApiException('Backend did not return a payment link');
    }
    return CabinetTopUpPayment.fromJson(
      json,
      paymentMethodId: paymentMethod.id,
      paymentMethodName: paymentMethod.name,
    );
  }
}
