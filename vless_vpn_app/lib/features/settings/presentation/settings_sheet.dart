import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({
    required this.strings,
    required this.blockedAppsCount,
    required this.hasCabinetSession,
    required this.onOpenLogin,
    required this.onManageSplitTunnel,
    super.key,
  });

  final AppStrings strings;
  final int blockedAppsCount;
  final bool hasCabinetSession;
  final Future<void> Function() onOpenLogin;
  final Future<void> Function() onManageSplitTunnel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: const Color(0xF20F172A),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.settingsTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.settingsBody,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFCBD5E1),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                if (!hasCabinetSession) ...<Widget>[
                  ListTile(
                    onTap: () async {
                      Navigator.of(context).pop();
                      await Future<void>.delayed(const Duration(milliseconds: 150));
                      unawaited(onOpenLogin());
                    },
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    tileColor: Colors.white.withValues(alpha: 0.05),
                    leading: const Icon(
                      Icons.login_rounded,
                      color: Color(0xFF5EEAD4),
                    ),
                    title: Text(
                      strings.authLoginAction,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      strings.settingsLoginSubtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                ListTile(
                  onTap: () async {
                    Navigator.of(context).pop();
                    await Future<void>.delayed(const Duration(milliseconds: 150));
                    unawaited(onManageSplitTunnel());
                  },
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  tileColor: Colors.white.withValues(alpha: 0.05),
                  leading: const Icon(
                    Icons.app_shortcut_rounded,
                    color: Color(0xFF5EEAD4),
                  ),
                  title: Text(
                    strings.splitTunnelTitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    strings.splitTunnelAction(blockedAppsCount),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(strings.closeAction),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
