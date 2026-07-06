import '../../cabinet_api/application/cabinet_http_client.dart';
import '../../cabinet_api/domain/cabinet_session.dart';
import '../domain/cabinet_purchase_options.dart';
import '../domain/cabinet_purchase_preview.dart';
import '../domain/cabinet_purchase_request.dart';
import '../domain/cabinet_purchase_result.dart';
import 'cabinet_purchase_repository.dart';

class HttpCabinetPurchaseRepository implements CabinetPurchaseRepository {
  HttpCabinetPurchaseRepository({
    required CabinetHttpClient httpClient,
  }) : _httpClient = httpClient;

  final CabinetHttpClient _httpClient;

  @override
  Future<CabinetPurchaseOptions> getPurchaseOptions(CabinetSession session) async {
    final Map<String, Object?> json = await _httpClient.getJson(
      '/cabinet/subscription/purchase-options',
      bearerToken: session.accessToken,
    );
    return CabinetPurchaseOptions.fromJson(json);
  }

  @override
  Future<CabinetPurchasePreview> previewClassicPurchase(
    CabinetSession session,
    CabinetClassicPurchaseRequest request,
  ) async {
    final Map<String, Object?> json = await _httpClient.postJson(
      '/cabinet/subscription/purchase-preview',
      bearerToken: session.accessToken,
      body: request.toJson(),
    );
    return CabinetPurchasePreview.fromJson(json);
  }

  @override
  Future<CabinetPurchaseResult> submitClassicPurchase(
    CabinetSession session,
    CabinetClassicPurchaseRequest request,
  ) async {
    final Map<String, Object?> json = await _httpClient.postJson(
      '/cabinet/subscription/purchase',
      bearerToken: session.accessToken,
      body: request.toJson(),
    );
    return CabinetPurchaseResult.fromJson(json);
  }

  @override
  Future<CabinetPurchaseResult> submitTariffPurchase(
    CabinetSession session,
    CabinetTariffPurchaseRequest request,
  ) async {
    final Map<String, Object?> json = await _httpClient.postJson(
      '/cabinet/subscription/purchase-tariff',
      bearerToken: session.accessToken,
      body: request.toJson(),
    );
    return CabinetPurchaseResult.fromJson(json);
  }
}
