import 'package:flutter/foundation.dart';

import '../../cabinet_api/application/cabinet_api_exception.dart';
import '../../cabinet_api/domain/cabinet_session.dart';
import '../domain/cabinet_payment_method.dart';
import '../domain/cabinet_pending_tariff_purchase.dart';
import '../domain/cabinet_purchase_flow_result.dart';
import '../domain/cabinet_purchase_options.dart';
import '../domain/cabinet_purchase_preview.dart';
import '../domain/cabinet_purchase_request.dart';
import '../domain/cabinet_purchase_result.dart';
import '../domain/cabinet_top_up_payment.dart';
import 'cabinet_payment_repository.dart';
import 'cabinet_pending_purchase_repository.dart';
import 'cabinet_purchase_repository.dart';

class CabinetPurchaseController extends ChangeNotifier {
  CabinetPurchaseController({
    required CabinetPurchaseRepository repository,
    required CabinetPaymentRepository paymentRepository,
    required CabinetPendingPurchaseRepository pendingPurchaseRepository,
  }) : _repository = repository,
       _paymentRepository = paymentRepository,
       _pendingPurchaseRepository = pendingPurchaseRepository;

  final CabinetPurchaseRepository _repository;
  final CabinetPaymentRepository _paymentRepository;
  final CabinetPendingPurchaseRepository _pendingPurchaseRepository;

  CabinetPurchaseOptions? _options;
  CabinetPurchasePreview? _preview;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isSubmitting = false;
  CabinetTariffOption? _selectedTariff;
  CabinetTariffPeriodOption? _selectedTariffPeriod;
  int? _selectedTariffDeviceLimit;
  CabinetClassicPeriodOption? _selectedClassicPeriod;

  CabinetPurchaseOptions? get options => _options;
  CabinetPurchasePreview? get preview => _preview;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  CabinetTariffOption? get selectedTariff => _selectedTariff;
  CabinetTariffPeriodOption? get selectedTariffPeriod => _selectedTariffPeriod;
  int? get selectedTariffDeviceLimit => _selectedTariffDeviceLimit;
  CabinetClassicPeriodOption? get selectedClassicPeriod => _selectedClassicPeriod;

  void reset() {
    _options = null;
    _preview = null;
    _errorMessage = null;
    _isLoading = false;
    _isSubmitting = false;
    _selectedTariff = null;
    _selectedTariffPeriod = null;
    _selectedTariffDeviceLimit = null;
    _selectedClassicPeriod = null;
    notifyListeners();
  }

  Future<void> initialize(CabinetSession session) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final CabinetPurchaseOptions options = await _repository.getPurchaseOptions(
        session,
      );
      _options = options;
      _selectDefaults();
      if (!options.isTariffsMode) {
        await _loadClassicPreview(session);
      } else {
        _preview = null;
      }
    } on CabinetApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectTariffPeriod(
    CabinetSession session,
    CabinetTariffOption tariff,
    CabinetTariffPeriodOption period, [
    int? deviceLimit,
  ]) async {
    _selectedTariff = tariff;
    _selectedTariffPeriod = period;
    _selectedTariffDeviceLimit = deviceLimit ?? tariff.deviceLimit;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> selectTariff(
    CabinetSession session,
    CabinetTariffOption tariff, [
    int? deviceLimit,
  ]) async {
    _selectedTariff = tariff;
    _selectedTariffPeriod = _defaultTariffPeriod(tariff);
    _selectedTariffDeviceLimit = deviceLimit ?? tariff.deviceLimit;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> selectClassicPeriod(
    CabinetSession session,
    CabinetClassicPeriodOption period,
  ) async {
    _selectedClassicPeriod = period;
    _errorMessage = null;
    notifyListeners();
    await _loadClassicPreview(session);
  }

  Future<CabinetPurchaseFlowResult?> submit(CabinetSession session) async {
    final CabinetPurchaseOptions? options = _options;
    if (options == null) {
      return null;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (options.isTariffsMode) {
        final CabinetTariffOption? tariff = _selectedTariff;
        final CabinetTariffPeriodOption? period = _selectedTariffPeriod;
        if (tariff == null || period == null) {
          throw const CabinetApiException('No tariff selected');
        }
        return await _submitTariffPurchase(
          session,
          CabinetTariffPurchaseRequest(
            tariffId: tariff.id,
            periodDays: period.days,
            deviceLimit: _selectedTariffDeviceLimit ?? tariff.deviceLimit,
          ),
        );
      }

      final CabinetPurchaseResult result = await _repository.submitClassicPurchase(
        session,
        _buildClassicRequest(),
      );
      return CabinetPurchaseFlowResult.purchased(result);
    } on CabinetApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void _selectDefaults() {
    final CabinetPurchaseOptions? options = _options;
    if (options == null) {
      return;
    }

    if (options.isTariffsMode) {
      final CabinetTariffOption? tariff =
          options.tariffs.cast<CabinetTariffOption?>().firstWhere(
                (CabinetTariffOption? item) => item?.isAvailable == true,
                orElse: () => options.tariffs.isEmpty ? null : options.tariffs.first,
              );
      _selectedTariff = tariff;
      _selectedTariffPeriod = _defaultTariffPeriod(tariff);
      _selectedTariffDeviceLimit = tariff?.deviceLimit;
      _selectedClassicPeriod = null;
      return;
    }

    final CabinetClassicPurchaseOptions? classic = options.classic;
    if (classic == null) {
      return;
    }

    final String selectedId = classic.selection.periodId;
    _selectedClassicPeriod =
        classic.periods.cast<CabinetClassicPeriodOption?>().firstWhere(
              (CabinetClassicPeriodOption? item) => item?.id == selectedId,
              orElse: () => classic.periods.isEmpty ? null : classic.periods.first,
            );
    _selectedTariff = null;
    _selectedTariffPeriod = null;
    _selectedTariffDeviceLimit = null;
  }

  Future<void> _loadClassicPreview(CabinetSession session) async {
    try {
      _preview = await _repository.previewClassicPurchase(
        session,
        _buildClassicRequest(),
      );
    } on CabinetApiException catch (error) {
      _preview = null;
      _errorMessage = error.message;
    }
  }

  Future<CabinetPurchaseFlowResult?> resumePendingTariffPurchase(
    CabinetSession session,
  ) async {
    final CabinetPendingTariffPurchase? pendingPurchase =
        await _pendingPurchaseRepository.load();
    if (pendingPurchase == null) {
      return null;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final CabinetPurchaseResult result = await _repository.submitTariffPurchase(
        session,
        CabinetTariffPurchaseRequest(
          tariffId: pendingPurchase.tariffId,
          periodDays: pendingPurchase.periodDays,
          deviceLimit: pendingPurchase.deviceLimit,
        ),
      );
      await _pendingPurchaseRepository.clear();
      return CabinetPurchaseFlowResult.purchased(result);
    } on CabinetApiException catch (error) {
      if (_isInsufficientBalance(error)) {
        return null;
      }
      await _pendingPurchaseRepository.clear();
      _errorMessage = error.message;
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  CabinetClassicPurchaseRequest _buildClassicRequest() {
    final CabinetClassicPurchaseOptions classic = _options!.classic!;
    final CabinetClassicPeriodOption period =
        _selectedClassicPeriod ?? classic.periods.first;
    return CabinetClassicPurchaseRequest(
      periodId: period.id,
      periodDays: period.periodDays,
      trafficValue: period.defaultTrafficValue,
      servers: period.defaultServers,
      devices: period.defaultDevices,
    );
  }

  Future<CabinetPurchaseFlowResult> _submitTariffPurchase(
    CabinetSession session,
    CabinetTariffPurchaseRequest request,
  ) async {
    try {
      final CabinetPurchaseResult result = await _repository.submitTariffPurchase(
        session,
        request,
      );
      await _pendingPurchaseRepository.clear();
      return CabinetPurchaseFlowResult.purchased(result);
    } on CabinetApiException catch (error) {
      final CabinetTopUpPayment? payment = await _buildTopUpCheckout(
        session,
        request,
        error,
      );
      if (payment != null) {
        return CabinetPurchaseFlowResult.checkoutRequired(payment);
      }
      rethrow;
    }
  }

  CabinetTariffPeriodOption? _defaultTariffPeriod(CabinetTariffOption? tariff) {
    if (tariff == null || tariff.periods.isEmpty) {
      return null;
    }
    for (final CabinetTariffPeriodOption period in tariff.periods) {
      if (period.days == 180 || period.months == 6) {
        return period;
      }
    }
    return tariff.periods.first;
  }

  Future<CabinetTopUpPayment?> _buildTopUpCheckout(
    CabinetSession session,
    CabinetTariffPurchaseRequest request,
    CabinetApiException error,
  ) async {
    if (!_isInsufficientBalance(error)) {
      return null;
    }

    final List<CabinetPaymentMethod> methods = await _paymentRepository
        .getPaymentMethods(session);
    final CabinetPaymentMethod? paymentMethod =
        methods.where((CabinetPaymentMethod item) => item.isAvailable).fold<
          CabinetPaymentMethod?
        >(
          null,
          (CabinetPaymentMethod? current, CabinetPaymentMethod item) {
            if (current == null) {
              return item;
            }
            if (item.isDefaultForSubscription) {
              return item;
            }
            return current;
          },
        );
    if (paymentMethod == null) {
      throw const CabinetApiException('No available payment methods found');
    }

    final int topUpAmountKopeks = _resolveTopUpAmountKopeks(
      options: _options,
      paymentMethod: paymentMethod,
      error: error,
    );

    await _pendingPurchaseRepository.save(
      CabinetPendingTariffPurchase(
        tariffId: request.tariffId,
        periodDays: request.periodDays,
        deviceLimit: request.deviceLimit,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    return _paymentRepository.createTopUp(
      session,
      amountKopeks: topUpAmountKopeks,
      paymentMethod: paymentMethod,
      paymentOptionId: paymentMethod.options.isEmpty
          ? null
          : paymentMethod.options.first.id,
    );
  }

  bool _isInsufficientBalance(CabinetApiException error) {
    if (error.statusCode == 402) {
      return true;
    }
    final Object? detail = error.detail;
    if (detail is Map<Object?, Object?>) {
      final String code = (detail['code'] as String? ?? '').trim();
      return code == 'insufficient_balance' || code == 'insufficient_funds';
    }
    return false;
  }

  int _resolveTopUpAmountKopeks({
    required CabinetPurchaseOptions? options,
    required CabinetPaymentMethod paymentMethod,
    required CabinetApiException error,
  }) {
    final Object? detail = error.detail;
    int? requiredAmount;
    int? currentBalance;
    int? missingAmount;

    if (detail is Map<Object?, Object?>) {
      missingAmount =
          (detail['missing_amount'] as num?)?.toInt() ??
          (detail['missing_kopeks'] as num?)?.toInt();
      requiredAmount =
          (detail['required'] as num?)?.toInt() ??
          (detail['required_kopeks'] as num?)?.toInt();
      currentBalance =
          (detail['balance'] as num?)?.toInt() ??
          (detail['current_kopeks'] as num?)?.toInt();
    }

    int baseAmount = missingAmount ?? 0;
    if (baseAmount <= 0 && requiredAmount != null && currentBalance != null) {
      baseAmount = requiredAmount - currentBalance;
    }
    if (baseAmount <= 0) {
      final CabinetTariffOption? tariff = _selectedTariff;
      final CabinetTariffPeriodOption? period = _selectedTariffPeriod;
      if (tariff != null && period != null) {
        baseAmount = period.priceKopeks - (options?.balanceKopeks ?? 0);
      }
    }
    if (baseAmount <= 0) {
      baseAmount = 1;
    }

    final int minimumAmount = paymentMethod.minAmountKopeks <= 0
        ? 1
        : paymentMethod.minAmountKopeks;
    final int maximumAmount = paymentMethod.maxAmountKopeks <= 0
        ? baseAmount > minimumAmount ? baseAmount : minimumAmount
        : paymentMethod.maxAmountKopeks;
    final int requestedAmount = baseAmount < minimumAmount
        ? minimumAmount
        : baseAmount;
    return requestedAmount > maximumAmount ? maximumAmount : requestedAmount;
  }
}
