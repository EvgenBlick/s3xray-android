import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../cabinet_api/domain/cabinet_session.dart';
import '../../navigation/presentation/tab_surface.dart';
import '../application/cabinet_purchase_controller.dart';
import '../domain/cabinet_purchase_flow_result.dart';
import '../domain/cabinet_purchase_options.dart';
import '../domain/cabinet_purchase_result.dart';
import '../domain/cabinet_top_up_payment.dart';

class SubscriptionTabView extends StatefulWidget {
  const SubscriptionTabView({
    required this.strings,
    required this.session,
    required this.controller,
    required this.onLogin,
    required this.onPurchased,
    required this.onOpenCheckout,
    super.key,
  });

  final AppStrings strings;
  final CabinetSession? session;
  final CabinetPurchaseController controller;
  final Future<void> Function() onLogin;
  final Future<void> Function(CabinetPurchaseResult result) onPurchased;
  final Future<void> Function(CabinetTopUpPayment payment) onOpenCheckout;

  @override
  State<SubscriptionTabView> createState() => _SubscriptionTabViewState();
}

class _SubscriptionTabViewState extends State<SubscriptionTabView> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(covariant SubscriptionTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChange);
      widget.controller.addListener(_handleControllerChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    super.dispose();
  }

  void _handleControllerChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final CabinetSession? currentSession = widget.session;
    if (currentSession == null) {
      return _SubscriptionGuestState(
        strings: widget.strings,
        onLogin: widget.onLogin,
      );
    }

    final CabinetPurchaseController controller = widget.controller;
    final CabinetPurchaseOptions? options = controller.options;

    return TabSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SubscriptionIntro(strings: widget.strings),
          if (options == null &&
              controller.errorMessage?.trim().isNotEmpty == true) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              controller.errorMessage!.trim(),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFFFCA5A5)),
            ),
          ],
          const SizedBox(height: 14),
          if (controller.isLoading && options == null)
            _SubscriptionLoading(strings: widget.strings)
          else if (options == null)
            Text(
              widget.strings.purchaseUnavailableMessage,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFCBD5E1)),
            )
          else if (options.isTariffsMode)
            _TariffPurchaseSection(
              strings: widget.strings,
              session: currentSession,
              controller: controller,
              onPurchased: widget.onPurchased,
              onOpenCheckout: widget.onOpenCheckout,
            )
          else
            _ClassicFallbackSection(
              strings: widget.strings,
              controller: controller,
              onPurchased: widget.onPurchased,
              session: currentSession,
            ),
        ],
      ),
    );
  }
}

class _SubscriptionIntro extends StatelessWidget {
  const _SubscriptionIntro({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          strings.purchaseTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          strings.subscriptionTabBody,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFFCBD5E1),
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TariffPurchaseSection extends StatelessWidget {
  const _TariffPurchaseSection({
    required this.strings,
    required this.session,
    required this.controller,
    required this.onPurchased,
    required this.onOpenCheckout,
  });

  final AppStrings strings;
  final CabinetSession session;
  final CabinetPurchaseController controller;
  final Future<void> Function(CabinetPurchaseResult result) onPurchased;
  final Future<void> Function(CabinetTopUpPayment payment) onOpenCheckout;

  @override
  Widget build(BuildContext context) {
    final CabinetPurchaseOptions options = controller.options!;
    final List<CabinetTariffOption> tariffs =
        options.tariffs
            .where((CabinetTariffOption tariff) => tariff.isAvailable)
            .toList()
          ..sort((CabinetTariffOption left, CabinetTariffOption right) {
            final int deviceComparison = left.baseDeviceLimit.compareTo(
              right.baseDeviceLimit,
            );
            if (deviceComparison != 0) {
              return deviceComparison;
            }
            return left.id.compareTo(right.id);
          });
    if (tariffs.isEmpty) {
      return Text(
        strings.purchaseUnavailableMessage,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFCBD5E1)),
      );
    }

    final Map<int, List<_DisplayTariffPeriod>> periodsByDevice =
        _groupPeriodsByDevice(tariffs);
    final List<int> deviceLimits = _resolveDeviceLimits(
      tariffs,
      periodsByDevice,
    );
    if (deviceLimits.isEmpty) {
      return Text(
        strings.purchaseUnavailableMessage,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFCBD5E1)),
      );
    }

    final int selectedDeviceLimit = _resolveSelectedDeviceLimit(
      controller.selectedTariffDeviceLimit,
      deviceLimits,
    );
    final List<_DisplayTariffPeriod> periods = _resolvePeriodsForDeviceLimit(
      selectedDeviceLimit,
      periodsByDevice,
    );
    final _DisplayTariffPeriod selectedDisplayPeriod =
        _resolveSelectedDisplayPeriod(controller: controller, periods: periods);
    final CabinetTariffOption selectedTariff = selectedDisplayPeriod.tariff;
    final CabinetTariffPeriodOption selectedPeriod =
        selectedDisplayPeriod.period;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _DeviceSelectorCard(
          strings: strings,
          deviceLimits: deviceLimits,
          selectedDeviceLimit: selectedDeviceLimit,
          onSelectDeviceLimit: (int deviceLimit) {
            final List<_DisplayTariffPeriod> nextPeriods =
                _resolvePeriodsForDeviceLimit(deviceLimit, periodsByDevice);
            final _DisplayTariffPeriod nextSelection =
                _resolveSelectedDisplayPeriod(
                  controller: controller,
                  periods: nextPeriods,
                );
            controller.selectTariffPeriod(
              session,
              nextSelection.tariff,
              nextSelection.period,
              deviceLimit,
            );
          },
        ),
        const SizedBox(height: 14),
        _PeriodGrid(
          strings: strings,
          periods: periods,
          selectedPeriod: selectedDisplayPeriod,
          onSelectPeriod: (_DisplayTariffPeriod period) {
            controller.selectTariffPeriod(
              session,
              period.tariff,
              period.period,
              period.deviceLimit,
            );
          },
        ),
        const SizedBox(height: 14),
        _PurchaseActionCard(
          strings: strings,
          selectedPeriod: selectedDisplayPeriod,
          isSubmitting: controller.isSubmitting,
          onPurchase: !selectedTariff.isAvailable
              ? null
              : () async {
                  await controller.selectTariffPeriod(
                    session,
                    selectedTariff,
                    selectedPeriod,
                    selectedDeviceLimit,
                  );
                  final CabinetPurchaseFlowResult? result = await controller
                      .submit(session);
                  if (result == null) {
                    return;
                  }
                  if (result.isPurchased && result.purchaseResult != null) {
                    await onPurchased(result.purchaseResult!);
                    return;
                  }
                  if (result.requiresCheckout && result.topUpPayment != null) {
                    await onOpenCheckout(result.topUpPayment!);
                  }
                },
        ),
      ],
    );
  }
}

class _DeviceSelectorCard extends StatelessWidget {
  const _DeviceSelectorCard({
    required this.strings,
    required this.deviceLimits,
    required this.selectedDeviceLimit,
    required this.onSelectDeviceLimit,
  });

  final AppStrings strings;
  final List<int> deviceLimits;
  final int selectedDeviceLimit;
  final ValueChanged<int> onSelectDeviceLimit;

  @override
  Widget build(BuildContext context) {
    final bool hasMultipleLimits = deviceLimits.length > 1;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final int resolvedIndex = deviceLimits.indexOf(selectedDeviceLimit);
    final int selectedIndex = resolvedIndex < 0 ? 0 : resolvedIndex;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0x1A14B8A6), Color(0x10101728)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0x73123F39),
                ),
                child: const Icon(
                  Icons.devices_rounded,
                  color: Color(0xFF6EE7D8),
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '$selectedDeviceLimit',
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strings.cabinetDevicesLabel,
                      style: textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      strings.purchaseDevicesSubtitle,
                      style: textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _DeviceLimitTrack(
            deviceLimits: deviceLimits,
            selectedIndex: selectedIndex,
            enabled: hasMultipleLimits,
            onSelectIndex: (int nextIndex) {
              if (nextIndex < 0 || nextIndex >= deviceLimits.length) {
                return;
              }
              onSelectDeviceLimit(deviceLimits[nextIndex]);
            },
          ),
        ],
      ),
    );
  }
}

class _DeviceLimitTrack extends StatelessWidget {
  const _DeviceLimitTrack({
    required this.deviceLimits,
    required this.selectedIndex,
    required this.enabled,
    required this.onSelectIndex,
  });

  final List<int> deviceLimits;
  final int selectedIndex;
  final bool enabled;
  final ValueChanged<int> onSelectIndex;

  @override
  Widget build(BuildContext context) {
    if (deviceLimits.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        int resolveIndex(double localDx) {
          if (deviceLimits.length <= 1 || constraints.maxWidth <= 0) {
            return 0;
          }
          final double normalized = (localDx / constraints.maxWidth)
              .clamp(0, 1)
              .toDouble();
          return (normalized * (deviceLimits.length - 1)).round();
        }

        final int clampedSelectedIndex = selectedIndex
            .clamp(0, deviceLimits.length - 1)
            .toInt();
        final double selectedFraction = deviceLimits.length <= 1
            ? 1
            : clampedSelectedIndex / (deviceLimits.length - 1);

        return Semantics(
          label: 'Device limit selector',
          value: deviceLimits[clampedSelectedIndex].toString(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled
                ? (TapDownDetails details) =>
                      onSelectIndex(resolveIndex(details.localPosition.dx))
                : null,
            onHorizontalDragUpdate: enabled
                ? (DragUpdateDetails details) =>
                      onSelectIndex(resolveIndex(details.localPosition.dx))
                : null,
            child: SizedBox(
              height: 22,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Positioned(
                    left: 6,
                    right: 6,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    right:
                        6 +
                        (constraints.maxWidth - 12) * (1 - selectedFraction),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          colors: <Color>[Color(0xFF2DD4BF), Color(0xFF99F6E4)],
                        ),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x665EEAD4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: deviceLimits.asMap().entries.map((entry) {
                      final bool active = entry.key <= selectedIndex;
                      final bool selected = entry.key == selectedIndex;
                      return GestureDetector(
                        key: ValueKey<String>('device-limit-${entry.value}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: enabled ? () => onSelectIndex(entry.key) : null,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutCubic,
                            width: selected ? 14 : 9,
                            height: selected ? 14 : 9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active
                                  ? const Color(0xFF5EEAD4)
                                  : const Color(0xFF253244),
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.18),
                                width: selected ? 2 : 1,
                              ),
                              boxShadow: active
                                  ? const <BoxShadow>[
                                      BoxShadow(
                                        color: Color(0x665EEAD4),
                                        blurRadius: 10,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PeriodGrid extends StatelessWidget {
  const _PeriodGrid({
    required this.strings,
    required this.periods,
    required this.selectedPeriod,
    required this.onSelectPeriod,
  });

  final AppStrings strings;
  final List<_DisplayTariffPeriod> periods;
  final _DisplayTariffPeriod selectedPeriod;
  final ValueChanged<_DisplayTariffPeriod> onSelectPeriod;

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) {
      return Text(
        strings.purchaseUnavailableMessage,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFCBD5E1)),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final _DisplayTariffPeriod? popularPeriod = _resolvePopularPeriod(
          periods,
        );
        return GridView.builder(
          itemCount: periods.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 186,
          ),
          itemBuilder: (BuildContext context, int index) {
            final _DisplayTariffPeriod period = periods[index];
            return _PeriodCard(
              strings: strings,
              period: period,
              selected:
                  selectedPeriod.tariff.id == period.tariff.id &&
                  selectedPeriod.period.days == period.period.days &&
                  selectedPeriod.deviceLimit == period.deviceLimit,
              popular:
                  popularPeriod != null &&
                  popularPeriod.period.days == period.period.days,
              onTap: () => onSelectPeriod(period),
            );
          },
        );
      },
    );
  }
}

class _PeriodCard extends StatefulWidget {
  const _PeriodCard({
    required this.strings,
    required this.period,
    required this.selected,
    required this.popular,
    required this.onTap,
  });

  final AppStrings strings;
  final _DisplayTariffPeriod period;
  final bool selected;
  final bool popular;
  final VoidCallback onTap;

  @override
  State<_PeriodCard> createState() => _PeriodCardState();
}

class _PeriodCardState extends State<_PeriodCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool showBadge =
        widget.popular || (widget.period.period.discountPercent ?? 0) > 0;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double scale = widget.selected ? 1.02 : (_pressed ? 0.985 : 1);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.popular ? 24 : 22),
            gradient: widget.selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0x4A14B8A6), Color(0x21111828)],
                  )
                : widget.popular
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0x2414B8A6), Color(0x12111828)],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0x14172234), Color(0x0B0F172A)],
                  ),
            border: Border.all(
              color: widget.selected
                  ? const Color(0xFF5EEAD4)
                  : widget.popular
                  ? const Color(0x665EEAD4)
                  : Colors.white.withValues(alpha: 0.08),
              width: widget.selected ? 2 : 1,
            ),
            boxShadow: widget.selected
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x3D14B8A6),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ]
                : widget.popular
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x1F14B8A6),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.period.period.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (showBadge) ...<Widget>[
                          const SizedBox(height: 4),
                          _MiniBadge(
                            label: widget.popular
                                ? widget.strings.purchasePopularBadge
                                : widget.period.period.discountLabel
                                          ?.trim()
                                          .isNotEmpty ==
                                      true
                                ? widget.period.period.discountLabel!.trim()
                                : 'Выгодно',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _RadioIndicator(selected: widget.selected, compact: true),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.period.priceLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              if (widget.period.originalPriceLabel != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  widget.period.originalPriceLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
              if (widget.period.perMonthLabel != null ||
                  widget.period.perDayLabel != null) ...<Widget>[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 5,
                  children: <Widget>[
                    if (widget.period.perMonthLabel != null)
                      _PriceMetaChip(label: widget.period.perMonthLabel!),
                    if (widget.period.perDayLabel != null)
                      _PriceMetaChip(label: widget.period.perDayLabel!),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioIndicator extends StatelessWidget {
  const _RadioIndicator({required this.selected, this.compact = false});

  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: compact ? 20 : 24,
      height: compact ? 20 : 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xFF5EEAD4) : Colors.transparent,
        border: Border.all(
          color: selected
              ? const Color(0xFF99F6E4)
              : Colors.white.withValues(alpha: 0.28),
          width: selected ? 2 : 1.4,
        ),
        boxShadow: selected
            ? const <BoxShadow>[
                BoxShadow(color: Color(0x665EEAD4), blurRadius: 12),
              ]
            : null,
      ),
      child: selected
          ? Icon(
              Icons.check_rounded,
              size: compact ? 13 : 15,
              color: const Color(0xFF052E2B),
            )
          : null,
    );
  }
}

class _PriceMetaChip extends StatelessWidget {
  const _PriceMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFFCBD5E1),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PurchaseActionCard extends StatelessWidget {
  const _PurchaseActionCard({
    required this.strings,
    required this.selectedPeriod,
    required this.isSubmitting,
    required this.onPurchase,
  });

  final AppStrings strings;
  final _DisplayTariffPeriod selectedPeriod;
  final bool isSubmitting;
  final Future<void> Function()? onPurchase;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: onPurchase == null || isSubmitting
            ? null
            : () async {
                await onPurchase!.call();
              },
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF21D3A7),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF155E52),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.68),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                isSubmitting
                    ? strings.purchaseProcessingAction
                    : '${strings.purchasePayAction} • ${selectedPeriod.period.label} • ${selectedPeriod.priceLabel}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisplayTariffPeriod {
  const _DisplayTariffPeriod({
    required this.tariff,
    required this.period,
    required this.deviceLimit,
    required this.baseDeviceLimit,
    required this.devicePriceKopeks,
  });

  final CabinetTariffOption tariff;
  final CabinetTariffPeriodOption period;
  final int deviceLimit;
  final int baseDeviceLimit;
  final int devicePriceKopeks;

  int get _monthsForPricing => period.months > 0
      ? period.months
      : (period.days / 30).clamp(1, double.infinity).round();

  int get extraDeviceCount => (deviceLimit - baseDeviceLimit).clamp(0, 999);

  int get priceKopeks {
    final int basePrice = period.baseTariffPriceKopeks ?? period.priceKopeks;
    return basePrice + extraDeviceCount * devicePriceKopeks * _monthsForPricing;
  }

  int? get originalPriceKopeks {
    final int? original = period.originalPriceKopeks;
    if (original == null) {
      return null;
    }
    final int adjustedOriginal =
        original + extraDeviceCount * devicePriceKopeks * _monthsForPricing;
    return adjustedOriginal > priceKopeks ? adjustedOriginal : null;
  }

  String get priceLabel => _formatKopeks(priceKopeks);

  String? get perMonthLabel {
    if (period.days <= 31 || period.months <= 1) {
      return null;
    }
    final int perMonthKopeks = (priceKopeks / (period.days / 30)).round();
    if (perMonthKopeks == priceKopeks) {
      return null;
    }
    return '${_formatKopeks(perMonthKopeks)} / мес';
  }

  String? get perDayLabel {
    if (period.days < 28) {
      return null;
    }
    final int perDayKopeks = (priceKopeks / period.days).round();
    if (perDayKopeks <= 0) {
      return null;
    }
    return '~${_formatKopeks(perDayKopeks)} / день';
  }

  String? get originalPriceLabel {
    final int? original = originalPriceKopeks;
    if (original == null) {
      return null;
    }
    return _formatKopeks(original);
  }

  _DisplayTariffPeriod forDeviceLimit(int nextDeviceLimit) {
    return _DisplayTariffPeriod(
      tariff: tariff,
      period: period,
      deviceLimit: nextDeviceLimit,
      baseDeviceLimit: baseDeviceLimit,
      devicePriceKopeks: devicePriceKopeks,
    );
  }
}

String _formatKopeks(int kopeks) {
  final double rubles = kopeks / 100;
  final bool isInteger = rubles.truncateToDouble() == rubles;
  return '${rubles.toStringAsFixed(isInteger ? 0 : 2)} ₽';
}

_DisplayTariffPeriod? _resolvePopularPeriod(
  List<_DisplayTariffPeriod> periods,
) {
  for (final _DisplayTariffPeriod period in periods) {
    if (period.period.months == 3 || period.period.days == 90) {
      return period;
    }
  }
  if (periods.length < 2) {
    return null;
  }
  _DisplayTariffPeriod best = periods.first;
  double bestPerDay = best.priceKopeks / best.period.days.clamp(1, 10000);
  for (final _DisplayTariffPeriod period in periods.skip(1)) {
    final double perDay =
        period.priceKopeks / period.period.days.clamp(1, 10000);
    if (perDay < bestPerDay) {
      best = period;
      bestPerDay = perDay;
    }
  }
  return best;
}

Map<int, List<_DisplayTariffPeriod>> _groupPeriodsByDevice(
  List<CabinetTariffOption> tariffs,
) {
  final Map<int, List<_DisplayTariffPeriod>> periodsByDevice =
      <int, List<_DisplayTariffPeriod>>{};

  for (final CabinetTariffOption tariff in tariffs) {
    final int baseDeviceLimit = tariff.baseDeviceLimit <= 0
        ? tariff.deviceLimit
        : tariff.baseDeviceLimit;
    for (final CabinetTariffPeriodOption period in tariff.periods) {
      final int extraDevicesCount =
          period.extraDevicesCount ?? tariff.extraDevicesCount;
      final int deviceLimit = baseDeviceLimit + extraDevicesCount;
      final List<_DisplayTariffPeriod> periods = periodsByDevice.putIfAbsent(
        deviceLimit,
        () => <_DisplayTariffPeriod>[],
      );
      periods.add(
        _DisplayTariffPeriod(
          tariff: tariff,
          period: period,
          deviceLimit: deviceLimit,
          baseDeviceLimit: baseDeviceLimit,
          devicePriceKopeks: tariff.devicePriceKopeks,
        ),
      );
    }
  }

  for (final List<_DisplayTariffPeriod> periods in periodsByDevice.values) {
    periods.sort((_DisplayTariffPeriod left, _DisplayTariffPeriod right) {
      final int monthsComparison = left.period.months.compareTo(
        right.period.months,
      );
      if (monthsComparison != 0) {
        return monthsComparison;
      }
      final int daysComparison = left.period.days.compareTo(right.period.days);
      if (daysComparison != 0) {
        return daysComparison;
      }
      return left.period.priceKopeks.compareTo(right.period.priceKopeks);
    });
  }

  return periodsByDevice;
}

List<int> _resolveDeviceLimits(
  List<CabinetTariffOption> tariffs,
  Map<int, List<_DisplayTariffPeriod>> periodsByDevice,
) {
  if (tariffs.isEmpty && periodsByDevice.isEmpty) {
    return const <int>[];
  }

  int minLimit = 1 << 30;
  int maxLimit = 0;

  for (final CabinetTariffOption tariff in tariffs) {
    final int baseLimit = tariff.baseDeviceLimit <= 0
        ? tariff.deviceLimit
        : tariff.baseDeviceLimit;
    minLimit = minLimit < baseLimit ? minLimit : baseLimit;
    final int tariffMax = tariff.maxDeviceLimit ?? tariff.deviceLimit;
    maxLimit = maxLimit > tariffMax ? maxLimit : tariffMax;
  }

  for (final int limit in periodsByDevice.keys) {
    minLimit = minLimit < limit ? minLimit : limit;
    maxLimit = maxLimit > limit ? maxLimit : limit;
  }

  if (maxLimit <= 0 || minLimit == 1 << 30) {
    return periodsByDevice.keys.toList()
      ..sort((int left, int right) => left.compareTo(right));
  }

  if (maxLimit < minLimit) {
    return <int>[minLimit];
  }

  return List<int>.generate(
    maxLimit - minLimit + 1,
    (int index) => minLimit + index,
  );
}

List<_DisplayTariffPeriod> _resolvePeriodsForDeviceLimit(
  int deviceLimit,
  Map<int, List<_DisplayTariffPeriod>> periodsByDevice,
) {
  if (periodsByDevice.isEmpty) {
    return const <_DisplayTariffPeriod>[];
  }

  final List<int> availableLimits = periodsByDevice.keys.toList()
    ..sort((int left, int right) => left.compareTo(right));
  final int sourceLimit = periodsByDevice.containsKey(deviceLimit)
      ? deviceLimit
      : availableLimits.lastWhere(
          (int limit) => limit <= deviceLimit,
          orElse: () => availableLimits.first,
        );
  final List<_DisplayTariffPeriod> sourcePeriods =
      periodsByDevice[sourceLimit] ?? periodsByDevice[availableLimits.first]!;
  final Map<int, _DisplayTariffPeriod> bestByDays =
      <int, _DisplayTariffPeriod>{};

  for (final _DisplayTariffPeriod period in sourcePeriods) {
    final _DisplayTariffPeriod adjusted = period.forDeviceLimit(deviceLimit);
    final _DisplayTariffPeriod? existing = bestByDays[adjusted.period.days];
    if (existing == null || adjusted.priceKopeks < existing.priceKopeks) {
      bestByDays[adjusted.period.days] = adjusted;
    }
  }

  return bestByDays.values.toList()
    ..sort((_DisplayTariffPeriod left, _DisplayTariffPeriod right) {
      final int monthsComparison = left.period.months.compareTo(
        right.period.months,
      );
      if (monthsComparison != 0) {
        return monthsComparison;
      }
      final int daysComparison = left.period.days.compareTo(right.period.days);
      if (daysComparison != 0) {
        return daysComparison;
      }
      return left.priceKopeks.compareTo(right.priceKopeks);
    });
}

int _resolveSelectedDeviceLimit(int? currentLimit, List<int> availableLimits) {
  if (availableLimits.isEmpty) {
    return 1;
  }
  if (currentLimit != null && availableLimits.contains(currentLimit)) {
    return currentLimit;
  }
  return availableLimits.first;
}

_DisplayTariffPeriod _resolveSelectedDisplayPeriod({
  required CabinetPurchaseController controller,
  required List<_DisplayTariffPeriod> periods,
}) {
  final CabinetTariffOption? selectedTariff = controller.selectedTariff;
  final CabinetTariffPeriodOption? selectedPeriod =
      controller.selectedTariffPeriod;
  if (selectedTariff != null && selectedPeriod != null) {
    for (final _DisplayTariffPeriod period in periods) {
      if (period.tariff.id == selectedTariff.id &&
          period.period.days == selectedPeriod.days) {
        return period;
      }
    }
  }
  for (final _DisplayTariffPeriod period in periods) {
    if (period.period.days == 180 || period.period.months == 6) {
      return period;
    }
  }
  return periods.first;
}

class _ClassicFallbackSection extends StatelessWidget {
  const _ClassicFallbackSection({
    required this.strings,
    required this.controller,
    required this.onPurchased,
    required this.session,
  });

  final AppStrings strings;
  final CabinetPurchaseController controller;
  final Future<void> Function(CabinetPurchaseResult result) onPurchased;
  final CabinetSession session;

  @override
  Widget build(BuildContext context) {
    final CabinetPurchaseOptions options = controller.options!;
    final CabinetClassicPurchaseOptions? classic = options.classic;
    if (classic == null) {
      return Text(
        strings.purchaseUnavailableMessage,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFCBD5E1)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ...classic.periods.map((CabinetClassicPeriodOption period) {
          final bool selected =
              controller.selectedClassicPeriod?.id == period.id;
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            child: ChoiceChip(
              selected: selected,
              label: Text('${period.label} • ${period.priceLabel}'),
              onSelected: period.isAvailable
                  ? (_) => controller.selectClassicPeriod(session, period)
                  : null,
            ),
          );
        }),
        if (controller.preview != null) ...<Widget>[
          _MetricTile(
            label: strings.purchaseTotalLabel,
            value: controller.preview!.totalPriceLabel,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: controller.isSubmitting
                  ? null
                  : () async {
                      final CabinetPurchaseFlowResult? result = await controller
                          .submit(session);
                      if (result == null ||
                          !result.isPurchased ||
                          result.purchaseResult == null) {
                        return;
                      }
                      await onPurchased(result.purchaseResult!);
                    },
              child: Text(
                controller.isSubmitting
                    ? strings.purchaseProcessingAction
                    : strings.purchaseActivateAction,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SubscriptionLoading extends StatelessWidget {
  const _SubscriptionLoading({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            strings.purchaseLoadingMessage,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFCBD5E1)),
          ),
        ),
      ],
    );
  }
}

class _SubscriptionGuestState extends StatelessWidget {
  const _SubscriptionGuestState({required this.strings, required this.onLogin});

  final AppStrings strings;
  final Future<void> Function() onLogin;

  @override
  Widget build(BuildContext context) {
    return TabSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            strings.navSubscriptionLabel,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            strings.subscriptionGuestTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.subscriptionGuestBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFCBD5E1),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.login_rounded),
              label: Text(strings.authLoginAction),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x2A2DD4BF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x552DD4BF)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFFBFFDF2),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
