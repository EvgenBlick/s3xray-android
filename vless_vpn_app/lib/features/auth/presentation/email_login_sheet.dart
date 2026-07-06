import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../cabinet_api/domain/cabinet_auth_provider.dart';

class EmailLoginSheet extends StatefulWidget {
  const EmailLoginSheet({
    required this.onSubmit,
    required this.availableProviders,
    required this.onSelectProvider,
    required this.isEmailAuthEnabled,
    super.key,
  });

  final Future<String?> Function(String email, String password) onSubmit;
  final List<CabinetAuthProvider> availableProviders;
  final Future<String?> Function(CabinetAuthProvider provider) onSelectProvider;
  final bool isEmailAuthEnabled;

  @override
  State<EmailLoginSheet> createState() => _EmailLoginSheetState();
}

class _EmailLoginSheetState extends State<EmailLoginSheet> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = AppStrings.of(context).authMissingCredentialsError;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final String? errorMessage = await widget.onSubmit(email, password);
    if (!mounted) {
      return;
    }

    if (errorMessage == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _errorMessage = errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(context);
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + viewInsets.bottom),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xF20F172A),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x66000410),
                  blurRadius: 30,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[Color(0x332DD4BF), Color(0x1614B8A6)],
                    ),
                    border: Border.all(color: const Color(0x335EEAD4)),
                  ),
                  child: const Icon(
                    Icons.account_circle_rounded,
                    color: Color(0xFF5EEAD4),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  strings.authLoginTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.authLoginBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFCBD5E1),
                    height: 1.4,
                  ),
                ),
                if (widget.availableProviders.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    strings.authOtherMethodsTitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: widget.availableProviders.map((
                      CabinetAuthProvider provider,
                    ) {
                      return _ProviderButton(
                        provider: provider,
                        busy: _isSubmitting,
                        onTap: () async {
                          setState(() {
                            _isSubmitting = true;
                            _errorMessage = null;
                          });
                          final String? errorMessage = await widget
                              .onSelectProvider(provider);
                          if (!context.mounted) {
                            return;
                          }
                          if (errorMessage == null) {
                            Navigator.of(context).pop(true);
                            return;
                          }
                          setState(() {
                            _isSubmitting = false;
                            _errorMessage = errorMessage;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
                if (widget.isEmailAuthEnabled) ...<Widget>[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const <String>[AutofillHints.username],
                    enabled: !_isSubmitting,
                    style: const TextStyle(color: Color(0xFFF8FAFC)),
                    decoration: InputDecoration(
                      labelText: strings.authEmailLabel,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const <String>[AutofillHints.password],
                    enabled: !_isSubmitting,
                    style: const TextStyle(color: Color(0xFFF8FAFC)),
                    decoration: InputDecoration(
                      labelText: strings.authPasswordLabel,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ],
                if (!widget.isEmailAuthEnabled &&
                    widget.availableProviders.isEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    strings.authNoMethodsAvailable,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFFCA5A5),
                    ),
                  ),
                ],
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFFCA5A5),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: Text(strings.closeAction),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: widget.isEmailAuthEnabled
                          ? FilledButton.icon(
                              onPressed: _isSubmitting ? null : _submit,
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: Text(
                                _isSubmitting
                                    ? strings.authLoggingInAction
                                    : strings.authLoginAction,
                              ),
                            )
                          : FilledButton(
                              onPressed: null,
                              child: Text(strings.authLoginAction),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.provider,
    required this.busy,
    required this.onTap,
  });

  final CabinetAuthProvider provider;
  final bool busy;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final _ProviderVisual visual = _providerVisual(provider.name);

    return SizedBox(
      width: 156,
      child: OutlinedButton(
        onPressed: busy ? null : onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          side: BorderSide(color: visual.borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: visual.backgroundColor,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: visual.logoBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                visual.logoText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                provider.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ProviderVisual _providerVisual(String providerName) {
    switch (providerName.toLowerCase()) {
      case 'yandex':
        return const _ProviderVisual(
          logoText: 'Я',
          backgroundColor: Color(0x141F2937),
          logoBackgroundColor: Color(0xFFE53935),
          borderColor: Color(0x33E53935),
        );
      case 'vk':
        return const _ProviderVisual(
          logoText: 'VK',
          backgroundColor: Color(0x141F2937),
          logoBackgroundColor: Color(0xFF2787F5),
          borderColor: Color(0x332787F5),
        );
      default:
        return const _ProviderVisual(
          logoText: 'ID',
          backgroundColor: Color(0x141F2937),
          logoBackgroundColor: Color(0xFF14B8A6),
          borderColor: Color(0x3314B8A6),
        );
    }
  }
}

class _ProviderVisual {
  const _ProviderVisual({
    required this.logoText,
    required this.backgroundColor,
    required this.logoBackgroundColor,
    required this.borderColor,
  });

  final String logoText;
  final Color backgroundColor;
  final Color logoBackgroundColor;
  final Color borderColor;
}
