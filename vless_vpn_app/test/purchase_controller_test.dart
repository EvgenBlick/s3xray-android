import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vless_vpn_app/l10n/app_strings.dart';
import 'package:vless_vpn_app/features/cabinet_api/application/cabinet_api_exception.dart';
import 'package:vless_vpn_app/features/cabinet_api/domain/cabinet_session.dart';
import 'package:vless_vpn_app/features/purchase/application/cabinet_payment_repository.dart';
import 'package:vless_vpn_app/features/purchase/application/cabinet_pending_purchase_repository.dart';
import 'package:vless_vpn_app/features/purchase/application/cabinet_purchase_controller.dart';
import 'package:vless_vpn_app/features/purchase/application/cabinet_purchase_repository.dart';
import 'package:vless_vpn_app/features/purchase/domain/cabinet_payment_method.dart';
import 'package:vless_vpn_app/features/purchase/domain/cabinet_pending_tariff_purchase.dart';
import 'package:vless_vpn_app/features/purchase/domain/cabinet_purchase_flow_result.dart';
import 'package:vless_vpn_app/features/purchase/domain/cabinet_purchase_options.dart';
import 'package:vless_vpn_app/features/purchase/domain/cabinet_purchase_preview.dart';
import 'package:vless_vpn_app/features/purchase/domain/cabinet_purchase_request.dart';
import 'package:vless_vpn_app/features/purchase/domain/cabinet_purchase_result.dart';
import 'package:vless_vpn_app/features/purchase/domain/cabinet_top_up_payment.dart';
import 'package:vless_vpn_app/features/purchase/presentation/subscription_tab_view.dart';

void main() {
  group('CabinetPurchaseController', () {
    final CabinetSession session = CabinetSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      tokenType: 'bearer',
      expiresAt: DateTime.utc(2030, 1, 1),
    );

    test('returns purchased result for direct tariff purchase', () async {
      final _FakePurchaseRepository purchaseRepository =
          _FakePurchaseRepository(
            options: _tariffOptions(),
            tariffPurchaseResult: const CabinetPurchaseResult(
              success: true,
              message: 'ok',
            ),
          );
      final CabinetPurchaseController controller = CabinetPurchaseController(
        repository: purchaseRepository,
        paymentRepository: _FakePaymentRepository(),
        pendingPurchaseRepository: _FakePendingPurchaseRepository(),
      );

      await controller.initialize(session);
      final CabinetPurchaseFlowResult? result = await controller.submit(
        session,
      );

      expect(result, isNotNull);
      expect(result!.isPurchased, isTrue);
      expect(result.purchaseResult?.message, 'ok');
    });

    test(
      'creates checkout on insufficient balance for tariff purchase',
      () async {
        final _FakePendingPurchaseRepository pendingRepository =
            _FakePendingPurchaseRepository();
        final _FakePurchaseRepository purchaseRepository =
            _FakePurchaseRepository(
              options: _tariffOptions(),
              tariffPurchaseError: CabinetApiException(
                'Недостаточно средств',
                statusCode: 402,
                responseJson: const <String, Object?>{
                  'detail': <String, Object?>{
                    'code': 'insufficient_funds',
                    'missing_kopeks': 12000,
                  },
                },
              ),
            );
        final CabinetPurchaseController controller = CabinetPurchaseController(
          repository: purchaseRepository,
          paymentRepository: _FakePaymentRepository(),
          pendingPurchaseRepository: pendingRepository,
        );

        await controller.initialize(session);
        final CabinetPurchaseFlowResult? result = await controller.submit(
          session,
        );

        expect(result, isNotNull);
        expect(result!.requiresCheckout, isTrue);
        expect(
          result.topUpPayment?.paymentUrl.toString(),
          'https://pay.example/checkout',
        );
        expect(pendingRepository.savedPurchase, isNotNull);
        expect(pendingRepository.savedPurchase?.tariffId, 10);
      },
    );

    test('finalizes pending purchase after payment', () async {
      final _FakePendingPurchaseRepository pendingRepository =
          _FakePendingPurchaseRepository(
            initialPurchase: const CabinetPendingTariffPurchase(
              tariffId: 10,
              periodDays: 30,
              deviceLimit: 3,
              createdAtMillis: 123456,
            ),
          );
      final _FakePurchaseRepository purchaseRepository =
          _FakePurchaseRepository(
            options: _tariffOptions(),
            tariffPurchaseResult: const CabinetPurchaseResult(
              success: true,
              message: 'applied',
            ),
          );
      final CabinetPurchaseController controller = CabinetPurchaseController(
        repository: purchaseRepository,
        paymentRepository: _FakePaymentRepository(),
        pendingPurchaseRepository: pendingRepository,
      );

      final CabinetPurchaseFlowResult? result = await controller
          .resumePendingTariffPurchase(session);

      expect(result, isNotNull);
      expect(result!.isPurchased, isTrue);
      expect(result.purchaseResult?.message, 'applied');
      expect(pendingRepository.savedPurchase, isNull);
    });

    testWidgets('device selector label tap changes selected tariff', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final CabinetPurchaseController controller = CabinetPurchaseController(
        repository: _FakePurchaseRepository(
          options: _multiDeviceTariffOptions(),
        ),
        paymentRepository: _FakePaymentRepository(),
        pendingPurchaseRepository: _FakePendingPurchaseRepository(),
      );
      addTearDown(controller.dispose);

      await controller.initialize(session);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0F766E),
            ),
            useMaterial3: true,
          ),
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                backgroundColor: const Color(0xFF020617),
                body: SubscriptionTabView(
                  strings: AppStrings.of(context),
                  session: session,
                  controller: controller,
                  onLogin: () async {},
                  onPurchased: (_) async {},
                  onOpenCheckout: (_) async {},
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.selectedTariffDeviceLimit, 3);

      await tester.tap(find.byKey(const ValueKey<String>('device-limit-5')));
      await tester.pumpAndSettle();

      expect(controller.selectedTariffDeviceLimit, 5);
      expect(controller.selectedTariff?.id, 20);
    });

    testWidgets('device selector recalculates price for extra devices', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final CabinetPurchaseController controller = CabinetPurchaseController(
        repository: _FakePurchaseRepository(
          options: _extraDevicePriceOptions(),
        ),
        paymentRepository: _FakePaymentRepository(),
        pendingPurchaseRepository: _FakePendingPurchaseRepository(),
      );
      addTearDown(controller.dispose);

      await controller.initialize(session);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0F766E),
            ),
            useMaterial3: true,
          ),
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                backgroundColor: const Color(0xFF020617),
                body: SubscriptionTabView(
                  strings: AppStrings.of(context),
                  session: session,
                  controller: controller,
                  onLogin: () async {},
                  onPurchased: (_) async {},
                  onOpenCheckout: (_) async {},
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('180 ₽'), findsWidgets);
      expect(find.text('180 ₽ / мес'), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('device-limit-4')));
      await tester.pumpAndSettle();

      expect(controller.selectedTariffDeviceLimit, 4);
      expect(controller.selectedTariff?.id, 10);
      expect(find.text('240 ₽'), findsWidgets);
      expect(find.text('240 ₽ / мес'), findsNothing);
    });
  });
}

CabinetPurchaseOptions _tariffOptions() {
  return const CabinetPurchaseOptions(
    mode: CabinetPurchaseMode.tariffs,
    balanceKopeks: 0,
    balanceLabel: '0 ₽',
    tariffs: <CabinetTariffOption>[
      CabinetTariffOption(
        id: 10,
        name: '3 устройства',
        description: 'Tariff',
        trafficLimitGb: 5,
        trafficLimitLabel: '5 GB',
        isUnlimitedTraffic: false,
        deviceLimit: 3,
        baseDeviceLimit: 3,
        maxDeviceLimit: 5,
        extraDevicesCount: 0,
        devicePriceKopeks: 0,
        isCurrent: false,
        isAvailable: true,
        isDaily: false,
        periods: <CabinetTariffPeriodOption>[
          CabinetTariffPeriodOption(
            days: 30,
            months: 1,
            label: '1 месяц',
            priceKopeks: 17460,
            priceLabel: '174.60 ₽',
            pricePerMonthLabel: '174.60 ₽',
          ),
        ],
      ),
    ],
  );
}

CabinetPurchaseOptions _extraDevicePriceOptions() {
  return const CabinetPurchaseOptions(
    mode: CabinetPurchaseMode.tariffs,
    balanceKopeks: 0,
    balanceLabel: '0 ₽',
    tariffs: <CabinetTariffOption>[
      CabinetTariffOption(
        id: 10,
        name: '3 устройства',
        description: 'Tariff',
        trafficLimitGb: 0,
        trafficLimitLabel: 'Без лимит',
        isUnlimitedTraffic: true,
        deviceLimit: 3,
        baseDeviceLimit: 3,
        maxDeviceLimit: 5,
        extraDevicesCount: 0,
        devicePriceKopeks: 6000,
        isCurrent: false,
        isAvailable: true,
        isDaily: false,
        periods: <CabinetTariffPeriodOption>[
          CabinetTariffPeriodOption(
            days: 30,
            months: 1,
            label: '1 месяц',
            priceKopeks: 18000,
            priceLabel: '180 ₽',
            pricePerMonthLabel: '180 ₽',
          ),
          CabinetTariffPeriodOption(
            days: 180,
            months: 6,
            label: '6 месяцев',
            priceKopeks: 90000,
            priceLabel: '900 ₽',
            pricePerMonthLabel: '150 ₽',
          ),
        ],
      ),
    ],
  );
}

CabinetPurchaseOptions _multiDeviceTariffOptions() {
  return const CabinetPurchaseOptions(
    mode: CabinetPurchaseMode.tariffs,
    balanceKopeks: 0,
    balanceLabel: '0 ₽',
    tariffs: <CabinetTariffOption>[
      CabinetTariffOption(
        id: 10,
        name: '3 устройства',
        description: 'Tariff',
        trafficLimitGb: 0,
        trafficLimitLabel: 'Без лимит',
        isUnlimitedTraffic: true,
        deviceLimit: 3,
        baseDeviceLimit: 3,
        maxDeviceLimit: 5,
        extraDevicesCount: 0,
        devicePriceKopeks: 0,
        isCurrent: false,
        isAvailable: true,
        isDaily: false,
        periods: <CabinetTariffPeriodOption>[
          CabinetTariffPeriodOption(
            days: 30,
            months: 1,
            label: '1 месяц',
            priceKopeks: 18000,
            priceLabel: '180 ₽',
            pricePerMonthLabel: '180 ₽',
          ),
        ],
      ),
      CabinetTariffOption(
        id: 20,
        name: '5 устройств',
        description: 'Tariff',
        trafficLimitGb: 0,
        trafficLimitLabel: 'Без лимит',
        isUnlimitedTraffic: true,
        deviceLimit: 5,
        baseDeviceLimit: 5,
        maxDeviceLimit: 5,
        extraDevicesCount: 0,
        devicePriceKopeks: 0,
        isCurrent: false,
        isAvailable: true,
        isDaily: false,
        periods: <CabinetTariffPeriodOption>[
          CabinetTariffPeriodOption(
            days: 30,
            months: 1,
            label: '1 месяц',
            priceKopeks: 24000,
            priceLabel: '240 ₽',
            pricePerMonthLabel: '240 ₽',
          ),
        ],
      ),
    ],
  );
}

class _FakePurchaseRepository implements CabinetPurchaseRepository {
  _FakePurchaseRepository({
    required this.options,
    this.tariffPurchaseResult,
    this.tariffPurchaseError,
  });

  final CabinetPurchaseOptions options;
  final CabinetPurchaseResult? tariffPurchaseResult;
  final CabinetApiException? tariffPurchaseError;

  @override
  Future<CabinetPurchaseOptions> getPurchaseOptions(
    CabinetSession session,
  ) async {
    return options;
  }

  @override
  Future<CabinetPurchasePreview> previewClassicPurchase(
    CabinetSession session,
    CabinetClassicPurchaseRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<CabinetPurchaseResult> submitClassicPurchase(
    CabinetSession session,
    CabinetClassicPurchaseRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<CabinetPurchaseResult> submitTariffPurchase(
    CabinetSession session,
    CabinetTariffPurchaseRequest request,
  ) async {
    if (tariffPurchaseError != null) {
      throw tariffPurchaseError!;
    }
    return tariffPurchaseResult ??
        const CabinetPurchaseResult(success: true, message: 'done');
  }
}

class _FakePaymentRepository implements CabinetPaymentRepository {
  @override
  Future<CabinetTopUpPayment> createTopUp(
    CabinetSession session, {
    required int amountKopeks,
    required CabinetPaymentMethod paymentMethod,
    String? paymentOptionId,
  }) async {
    return CabinetTopUpPayment(
      paymentId: 'pay_1',
      paymentUrl: Uri.parse('https://pay.example/checkout'),
      amountKopeks: amountKopeks,
      amountRubles: amountKopeks / 100,
      status: 'pending',
      paymentMethodId: paymentMethod.id,
      paymentMethodName: paymentMethod.name,
    );
  }

  @override
  Future<List<CabinetPaymentMethod>> getPaymentMethods(
    CabinetSession session,
  ) async {
    return const <CabinetPaymentMethod>[
      CabinetPaymentMethod(
        id: 'card',
        name: 'Card',
        description: 'Default',
        minAmountKopeks: 1000,
        maxAmountKopeks: 500000,
        isAvailable: true,
        isDefaultForSubscription: true,
        options: <CabinetPaymentMethodOption>[
          CabinetPaymentMethodOption(id: 'bank-card', name: 'Bank card'),
        ],
      ),
    ];
  }
}

class _FakePendingPurchaseRepository
    implements CabinetPendingPurchaseRepository {
  _FakePendingPurchaseRepository({
    CabinetPendingTariffPurchase? initialPurchase,
  }) : savedPurchase = initialPurchase;

  CabinetPendingTariffPurchase? savedPurchase;

  @override
  Future<void> clear() async {
    savedPurchase = null;
  }

  @override
  Future<CabinetPendingTariffPurchase?> load() async {
    return savedPurchase;
  }

  @override
  Future<void> save(CabinetPendingTariffPurchase purchase) async {
    savedPurchase = purchase;
  }
}
