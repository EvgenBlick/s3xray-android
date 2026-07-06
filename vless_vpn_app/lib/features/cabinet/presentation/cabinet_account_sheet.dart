import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../cabinet_api/application/cabinet_bootstrap_snapshot.dart';
import '../../cabinet_api/domain/cabinet_subscription_status.dart';

class CabinetAccountSheet extends StatelessWidget {
  const CabinetAccountSheet({
    required this.strings,
    required this.snapshot,
    required this.onPurchase,
    required this.onRefresh,
    required this.onLogout,
    this.showCloseAction = true,
    this.showDevices = true,
    this.showPurchaseAction = true,
    this.showRefreshAction = true,
    super.key,
  });

  final AppStrings strings;
  final CabinetBootstrapSnapshot snapshot;
  final Future<void> Function() onPurchase;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLogout;
  final bool showCloseAction;
  final bool showDevices;
  final bool showPurchaseAction;
  final bool showRefreshAction;

  @override
  Widget build(BuildContext context) {
    final user = snapshot.user;
    final subscription = snapshot.subscriptionStatus;
    final String displayName =
        [
              _sanitizeDisplayText(user?.firstName),
              _sanitizeDisplayText(user?.lastName),
            ]
            .whereType<String>()
            .where((String value) => value.isNotEmpty)
            .join(' ')
            .trim();
    final String normalizedEmail = _sanitizeDisplayText(user?.email);
    final String normalizedUsername = _sanitizeDisplayText(user?.username);

    final String title = displayName.isNotEmpty
        ? displayName
        : normalizedUsername.isNotEmpty
        ? normalizedUsername
        : normalizedEmail.isNotEmpty
        ? normalizedEmail
        : strings.authLoginTitle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            top: false,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.82,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xF2141D31), Color(0xEE0A1020)],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.075),
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x66000612),
                    blurRadius: 30,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: const Color(0x1F2DD4BF),
                            border: Border.all(color: const Color(0x332DD4BF)),
                          ),
                          child: const Icon(
                            Icons.account_circle_rounded,
                            color: Color(0xFF5EEAD4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            strings.cabinetTitle,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (snapshot.isLoading) ...<Widget>[
                      Row(
                        children: <Widget>[
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              strings.cabinetLoadingMessage,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFFCBD5E1)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ] else if (snapshot.errorMessage?.trim().isNotEmpty ==
                        true) ...<Widget>[
                      Text(
                        snapshot.errorMessage!.trim(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFFCA5A5),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _InfoRow(label: strings.cabinetUserLabel, value: title),
                    if (normalizedEmail.isNotEmpty)
                      _InfoRow(
                        label: strings.authEmailLabel,
                        value: normalizedEmail,
                      ),
                    _InfoRow(
                      label: strings.cabinetBalanceLabel,
                      value: _formatMoney(user?.balanceKopeks),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.subscriptionTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: strings.statusLabel,
                      value: subscription?.isActive == true
                          ? strings.subscriptionActiveLabel
                          : strings.cabinetNoSubscriptionLabel,
                    ),
                    _InfoRow(
                      label: strings.expiresInLabel,
                      value:
                          subscription?.timeLeftDisplay?.trim().isNotEmpty ==
                              true
                          ? subscription!.timeLeftDisplay!.trim()
                          : '${subscription?.daysLeft ?? 0} ${strings.daysSuffix}',
                    ),
                    _InfoRow(
                      label: strings.trafficUsedLabel,
                      value: _formatTraffic(subscription),
                    ),
                    if (showDevices)
                      _InfoRow(
                        label: strings.cabinetDevicesLabel,
                        value:
                            subscription?.deviceLimit?.toString() ??
                            strings.missingValue,
                      ),
                    const SizedBox(height: 14),
                    if (showPurchaseAction) ...<Widget>[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onPurchase,
                          icon: const Icon(Icons.shopping_bag_rounded),
                          label: Text(
                            subscription?.isActive == true
                                ? strings.purchaseRenewAction
                                : strings.purchaseOpenAction,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool compact = constraints.maxWidth < 360;
                            return OverflowBar(
                              alignment: MainAxisAlignment.start,
                              overflowAlignment: OverflowBarAlignment.center,
                              spacing: 8,
                              overflowSpacing: 8,
                              children: <Widget>[
                                if (showRefreshAction)
                                  SizedBox(
                                    width: compact
                                        ? double.infinity
                                        : (constraints.maxWidth - 8) / 2,
                                    child: OutlinedButton.icon(
                                      onPressed: onRefresh,
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: Text(
                                        compact
                                            ? strings
                                                  .cabinetRefreshCompactAction
                                            : strings.cabinetRefreshAction,
                                      ),
                                    ),
                                  ),
                                SizedBox(
                                  width: compact || !showRefreshAction
                                      ? double.infinity
                                      : (constraints.maxWidth - 8) / 2,
                                  child: FilledButton.icon(
                                    onPressed: onLogout,
                                    icon: const Icon(Icons.logout_rounded),
                                    label: Text(strings.cabinetLogoutAction),
                                  ),
                                ),
                              ],
                            );
                          },
                    ),
                    if (showCloseAction) ...<Widget>[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(strings.closeAction),
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

  String _formatMoney(int? kopeks) {
    if (kopeks == null) {
      return strings.missingValue;
    }
    final double rubles = kopeks / 100;
    return '${rubles.toStringAsFixed(rubles.truncateToDouble() == rubles ? 0 : 2)} ₽';
  }

  String _formatTraffic(CabinetSubscriptionStatus? subscription) {
    if (subscription == null) {
      return strings.missingValue;
    }
    final double used = subscription.trafficUsedGb ?? 0;
    final double? limit = subscription.trafficLimitGb;
    final String usedText = '${used.toStringAsFixed(used % 1 == 0 ? 0 : 1)} GB';
    if (limit == null) {
      return usedText;
    }
    if (limit <= 0) {
      return '$usedText / ${strings.unlimitedValue}';
    }
    final String limitText =
        '${limit.toStringAsFixed(limit % 1 == 0 ? 0 : 1)} GB';
    return '$usedText / $limitText';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String sanitizedValue = _sanitizeDisplayText(value);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.045)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              sanitizedValue,
              textAlign: TextAlign.right,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _sanitizeDisplayText(String? value) {
  if (value == null) {
    return '';
  }

  return value
      .replaceAll(
        RegExp(
          r'[\u0000-\u001F\u007F-\u009F\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF]',
        ),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
