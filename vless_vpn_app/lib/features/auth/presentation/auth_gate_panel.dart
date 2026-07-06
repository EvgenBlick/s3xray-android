import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';

class AuthGatePanel extends StatelessWidget {
  const AuthGatePanel({
    required this.strings,
    required this.onLogin,
    required this.onContinueAsGuest,
    required this.isLoading,
    super.key,
  });

  final AppStrings strings;
  final Future<void> Function() onLogin;
  final Future<void> Function() onContinueAsGuest;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xF40A1220), Color(0xF0111C2D)],
            ),
            border: Border.all(color: const Color(0x225EEAD4)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x66000410),
                blurRadius: 40,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                top: -40,
                right: -10,
                child: IgnorePointer(
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[Color(0x332DD4BF), Color(0x002DD4BF)],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -64,
                left: -30,
                child: IgnorePointer(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[Color(0x220EA5E9), Color(0x000EA5E9)],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0x332DD4BF), Color(0x1614B8A6)],
                      ),
                      border: Border.all(color: const Color(0x335EEAD4)),
                    ),
                    child: const Icon(
                      Icons.lock_open_rounded,
                      color: Color(0xFF5EEAD4),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    strings.authGateTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    strings.authGateBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFCBD5E1),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: Colors.white.withValues(alpha: 0.035),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0x1A2DD4BF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.shield_moon_rounded,
                            color: Color(0xFF5EEAD4),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            strings.authLoginBody,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF94A3B8),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : onLogin,
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login_rounded),
                      label: Text(
                        isLoading
                            ? strings.authLoggingInAction
                            : strings.authLoginAction,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: isLoading ? null : onContinueAsGuest,
                      icon: const Icon(Icons.add_link_rounded, size: 18),
                      label: Text(strings.addFirstSubscriptionAction),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
