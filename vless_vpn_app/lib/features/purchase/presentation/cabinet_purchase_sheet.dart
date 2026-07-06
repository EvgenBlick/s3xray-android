import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../cabinet_api/domain/cabinet_session.dart';
import '../application/cabinet_purchase_controller.dart';
import '../domain/cabinet_purchase_flow_result.dart';
import '../domain/cabinet_purchase_options.dart';
import '../domain/cabinet_purchase_result.dart';

class CabinetPurchaseSheet extends StatefulWidget {
  const CabinetPurchaseSheet({
    required this.strings,
    required this.session,
    required this.controller,
    required this.onPurchased,
    this.showCloseAction = true,
    super.key,
  });

  final AppStrings strings;
  final CabinetSession session;
  final CabinetPurchaseController controller;
  final Future<void> Function(CabinetPurchaseResult result) onPurchased;
  final bool showCloseAction;

  @override
  State<CabinetPurchaseSheet> createState() => _CabinetPurchaseSheetState();
}

class _CabinetPurchaseSheetState extends State<CabinetPurchaseSheet> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.initialize(widget.session);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    widget.controller.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final CabinetPurchaseController controller = widget.controller;
    final CabinetPurchaseOptions? options = controller.options;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: const Color(0xF20F172A),
          child: SafeArea(
            top: false,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.86,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: controller.isLoading
                  ? _PurchaseLoading(strings: widget.strings)
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.strings.purchaseTitle,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.strings.purchaseBody,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFCBD5E1),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _PurchaseInfoCard(
                            label: widget.strings.cabinetBalanceLabel,
                            value: options?.balanceLabel ?? widget.strings.missingValue,
                          ),
                          if (controller.errorMessage?.trim().isNotEmpty == true) ...<Widget>[
                            const SizedBox(height: 12),
                            Text(
                              controller.errorMessage!.trim(),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFFCA5A5),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          if (options == null)
                            Text(
                              widget.strings.purchaseUnavailableMessage,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFFCBD5E1),
                              ),
                            )
                          else if (options.isTariffsMode)
                            _TariffsPurchaseSection(
                              strings: widget.strings,
                              options: options,
                              controller: controller,
                              session: widget.session,
                            )
                          else
                            _ClassicPurchaseSection(
                              strings: widget.strings,
                              options: options,
                              controller: controller,
                              session: widget.session,
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: controller.isSubmitting || options == null
                                  ? null
                                  : () async {
                                      final NavigatorState navigator =
                                          Navigator.of(context);
                                      final CabinetPurchaseFlowResult? result =
                                          await controller.submit(widget.session);
                                      if (!mounted ||
                                          result == null ||
                                          !result.isPurchased ||
                                          result.purchaseResult == null) {
                                        return;
                                      }
                                      await widget.onPurchased(result.purchaseResult!);
                                      if (!mounted) {
                                        return;
                                      }
                                      navigator.pop();
                                    },
                              child: Text(
                                controller.isSubmitting
                                    ? widget.strings.purchaseProcessingAction
                                    : widget.strings.purchaseConfirmAction,
                              ),
                            ),
                          ),
                          if (widget.showCloseAction) ...<Widget>[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(widget.strings.closeAction),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseLoading extends StatelessWidget {
  const _PurchaseLoading({
    required this.strings,
  });

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Row(
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFCBD5E1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TariffsPurchaseSection extends StatelessWidget {
  const _TariffsPurchaseSection({
    required this.strings,
    required this.options,
    required this.controller,
    required this.session,
  });

  final AppStrings strings;
  final CabinetPurchaseOptions options;
  final CabinetPurchaseController controller;
  final CabinetSession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          strings.purchaseTariffsTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ...options.tariffs.map((CabinetTariffOption tariff) {
          final bool selected = controller.selectedTariff?.id == tariff.id;
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: selected ? 0.08 : 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? const Color(0xFF14B8A6)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tariff.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((tariff.description ?? '').trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    tariff.description!.trim(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFCBD5E1),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _MiniBadge(label: tariff.trafficLimitLabel),
                    _MiniBadge(
                      label: '${tariff.deviceLimit} ${strings.cabinetDevicesLabel.toLowerCase()}',
                    ),
                    if (tariff.isCurrent)
                      _MiniBadge(label: strings.currentValue),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tariff.periods.map((CabinetTariffPeriodOption period) {
                    final bool selectedPeriod =
                        selected && controller.selectedTariffPeriod?.days == period.days;
                    return ChoiceChip(
                      selected: selectedPeriod,
                      label: Text('${period.label} • ${period.priceLabel}'),
                      onSelected: tariff.isAvailable
                          ? (_) => controller.selectTariffPeriod(session, tariff, period)
                          : null,
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ClassicPurchaseSection extends StatelessWidget {
  const _ClassicPurchaseSection({
    required this.strings,
    required this.options,
    required this.controller,
    required this.session,
  });

  final AppStrings strings;
  final CabinetPurchaseOptions options;
  final CabinetPurchaseController controller;
  final CabinetSession session;

  @override
  Widget build(BuildContext context) {
    final CabinetClassicPurchaseOptions? classic = options.classic;
    if (classic == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          strings.purchasePeriodsTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ...classic.periods.map((CabinetClassicPeriodOption period) {
          final bool selected = controller.selectedClassicPeriod?.id == period.id;
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
          const SizedBox(height: 8),
          _PurchaseInfoCard(
            label: strings.purchaseTotalLabel,
            value: controller.preview!.totalPriceLabel,
          ),
          _PurchaseInfoCard(
            label: strings.purchasePerMonthLabel,
            value: controller.preview!.perMonthPriceLabel,
          ),
          if ((controller.preview!.statusMessage ?? '').trim().isNotEmpty)
            _PurchaseInfoCard(
              label: strings.statusLabel,
              value: controller.preview!.statusMessage!.trim(),
            ),
        ],
      ],
    );
  }
}

class _PurchaseInfoCard extends StatelessWidget {
  const _PurchaseInfoCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFFCBD5E1),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
