import 'package:flutter/services.dart';

import '../domain/cabinet_pending_tariff_purchase.dart';
import 'cabinet_pending_purchase_repository.dart';

class MethodChannelCabinetPendingPurchaseRepository
    implements CabinetPendingPurchaseRepository {
  const MethodChannelCabinetPendingPurchaseRepository({
    MethodChannel methodChannel =
        const MethodChannel('stockvpn/purchase_pending_request'),
  }) : _methodChannel = methodChannel;

  final MethodChannel _methodChannel;

  @override
  Future<CabinetPendingTariffPurchase?> load() async {
    final Map<Object?, Object?>? json =
        await _methodChannel.invokeMapMethod<Object?, Object?>(
      'getPendingPurchase',
    );
    if (json == null || json.isEmpty) {
      return null;
    }
    return CabinetPendingTariffPurchase.fromJson(
      json.cast<String, Object?>(),
    );
  }

  @override
  Future<void> save(CabinetPendingTariffPurchase purchase) {
    return _methodChannel.invokeMethod<void>(
      'setPendingPurchase',
      purchase.toJson(),
    );
  }

  @override
  Future<void> clear() {
    return _methodChannel.invokeMethod<void>('clearPendingPurchase');
  }
}
