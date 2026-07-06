import '../../cabinet_api/domain/cabinet_session.dart';
import '../domain/cabinet_payment_method.dart';
import '../domain/cabinet_top_up_payment.dart';

abstract class CabinetPaymentRepository {
  Future<List<CabinetPaymentMethod>> getPaymentMethods(CabinetSession session);

  Future<CabinetTopUpPayment> createTopUp(
    CabinetSession session, {
    required int amountKopeks,
    required CabinetPaymentMethod paymentMethod,
    String? paymentOptionId,
  });
}
