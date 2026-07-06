import '../../cabinet_api/domain/cabinet_session.dart';
import '../domain/cabinet_purchase_options.dart';
import '../domain/cabinet_purchase_preview.dart';
import '../domain/cabinet_purchase_request.dart';
import '../domain/cabinet_purchase_result.dart';

abstract class CabinetPurchaseRepository {
  Future<CabinetPurchaseOptions> getPurchaseOptions(CabinetSession session);

  Future<CabinetPurchasePreview> previewClassicPurchase(
    CabinetSession session,
    CabinetClassicPurchaseRequest request,
  );

  Future<CabinetPurchaseResult> submitClassicPurchase(
    CabinetSession session,
    CabinetClassicPurchaseRequest request,
  );

  Future<CabinetPurchaseResult> submitTariffPurchase(
    CabinetSession session,
    CabinetTariffPurchaseRequest request,
  );
}
