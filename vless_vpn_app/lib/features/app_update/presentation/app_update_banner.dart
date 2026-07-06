import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../application/app_update_controller.dart';

class AppUpdateBanner extends StatelessWidget {
  const AppUpdateBanner({
    required this.snapshot,
    required this.onPrimaryAction,
    super.key,
  });

  final AppUpdateSnapshot snapshot;
  final Future<void> Function() onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final _UpdateBannerPresentation? presentation = _buildPresentation(strings);
    if (presentation == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: presentation.backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: presentation.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(presentation.icon, color: presentation.iconColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  presentation.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (presentation.body != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              presentation.body!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFFDCE7F7),
                height: 1.3,
              ),
            ),
          ],
          if (snapshot.status == AppUpdateStatus.downloading) ...<Widget>[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: snapshot.downloadProgress,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5EEAD4)),
              ),
            ),
          ],
          if (presentation.actionLabel != null) ...<Widget>[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => onPrimaryAction(),
                icon: Icon(presentation.actionIcon),
                label: Text(presentation.actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _UpdateBannerPresentation? _buildPresentation(AppStrings strings) {
    final String? versionName = snapshot.manifest?.versionName;

    switch (snapshot.status) {
      case AppUpdateStatus.available:
        return _UpdateBannerPresentation(
          icon: Icons.system_update_rounded,
          iconColor: const Color(0xFFFDE68A),
          title: strings.updateAvailableTitle(versionName ?? ''),
          body: strings.updateAvailableBody,
          actionLabel: strings.updateNowAction,
          actionIcon: Icons.download_rounded,
          backgroundColor: const Color(0x1FF59E0B),
          borderColor: const Color(0x40F59E0B),
        );
      case AppUpdateStatus.downloading:
        return _UpdateBannerPresentation(
          icon: Icons.downloading_rounded,
          iconColor: const Color(0xFF5EEAD4),
          title: strings.updateDownloadingTitle,
          body: strings.updateDownloadingBody(snapshot.downloadProgress),
          backgroundColor: const Color(0x1F0EA5E9),
          borderColor: const Color(0x400EA5E9),
        );
      case AppUpdateStatus.installPermissionRequired:
        return _UpdateBannerPresentation(
          icon: Icons.app_registration_rounded,
          iconColor: const Color(0xFFFDE68A),
          title: strings.updatePermissionTitle,
          body: strings.updatePermissionBody,
          actionLabel: strings.updateContinueAction,
          actionIcon: Icons.open_in_new_rounded,
          backgroundColor: const Color(0x1FF59E0B),
          borderColor: const Color(0x40F59E0B),
        );
      case AppUpdateStatus.installing:
        return _UpdateBannerPresentation(
          icon: Icons.install_mobile_rounded,
          iconColor: const Color(0xFF86EFAC),
          title: strings.updateInstallingTitle,
          body: strings.updateInstallingBody,
          backgroundColor: const Color(0x1F16A34A),
          borderColor: const Color(0x4016A34A),
        );
      case AppUpdateStatus.error:
        return _UpdateBannerPresentation(
          icon: Icons.error_outline_rounded,
          iconColor: const Color(0xFFFDA4AF),
          title: strings.updateErrorTitle,
          body: strings.updateErrorBody,
          actionLabel: strings.retryAction,
          actionIcon: Icons.refresh_rounded,
          backgroundColor: const Color(0x1FDC2626),
          borderColor: const Color(0x40DC2626),
        );
      case AppUpdateStatus.idle:
      case AppUpdateStatus.checking:
      case AppUpdateStatus.upToDate:
        return null;
    }
  }
}

class _UpdateBannerPresentation {
  const _UpdateBannerPresentation({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.backgroundColor,
    required this.borderColor,
    this.body,
    this.actionLabel,
    this.actionIcon,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? body;
  final String? actionLabel;
  final IconData? actionIcon;
  final Color backgroundColor;
  final Color borderColor;
}
