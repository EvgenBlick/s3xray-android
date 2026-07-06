import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../cabinet/presentation/cabinet_account_sheet.dart';
import '../../cabinet_api/application/cabinet_bootstrap_snapshot.dart';
import '../../navigation/presentation/tab_surface.dart';

class ProfileTabView extends StatelessWidget {
  const ProfileTabView({
    required this.strings,
    required this.snapshot,
    required this.onLogin,
    required this.onRefresh,
    required this.onLogout,
    super.key,
  });

  final AppStrings strings;
  final CabinetBootstrapSnapshot snapshot;
  final Future<void> Function() onLogin;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    if (snapshot.session == null) {
      return TabSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              strings.navProfileLabel,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              strings.profileGuestTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.profileGuestBody,
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

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        CabinetAccountSheet(
          strings: strings,
          snapshot: snapshot,
          onPurchase: onRefresh,
          onRefresh: onRefresh,
          onLogout: onLogout,
          showCloseAction: false,
          showDevices: false,
          showPurchaseAction: false,
          showRefreshAction: false,
        ),
      ],
    );
  }
}
