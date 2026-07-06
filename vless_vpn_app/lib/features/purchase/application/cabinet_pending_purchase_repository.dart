import '../domain/cabinet_pending_tariff_purchase.dart';

abstract class CabinetPendingPurchaseRepository {
  Future<CabinetPendingTariffPurchase?> load();

  Future<void> save(CabinetPendingTariffPurchase purchase);

  Future<void> clear();
}
