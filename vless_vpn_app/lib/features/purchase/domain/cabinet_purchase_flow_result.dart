import 'cabinet_purchase_result.dart';
import 'cabinet_top_up_payment.dart';

enum CabinetPurchaseFlowType {
  purchased,
  checkoutRequired,
}

class CabinetPurchaseFlowResult {
  const CabinetPurchaseFlowResult._({
    required this.type,
    this.purchaseResult,
    this.topUpPayment,
  });

  const CabinetPurchaseFlowResult.purchased(
    CabinetPurchaseResult result,
  ) : this._(
         type: CabinetPurchaseFlowType.purchased,
         purchaseResult: result,
       );

  const CabinetPurchaseFlowResult.checkoutRequired(
    CabinetTopUpPayment payment,
  ) : this._(
         type: CabinetPurchaseFlowType.checkoutRequired,
         topUpPayment: payment,
       );

  final CabinetPurchaseFlowType type;
  final CabinetPurchaseResult? purchaseResult;
  final CabinetTopUpPayment? topUpPayment;

  bool get isPurchased => type == CabinetPurchaseFlowType.purchased;
  bool get requiresCheckout => type == CabinetPurchaseFlowType.checkoutRequired;
}
