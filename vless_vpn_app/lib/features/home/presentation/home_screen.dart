import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_preferences/application/app_preferences_repository.dart';
import '../../auth/presentation/auth_gate_panel.dart';
import '../../auth/presentation/email_login_sheet.dart';
import '../../auth/application/method_channel_auth_platform_bridge.dart';
import '../../auth/application/oauth_login_coordinator.dart';
import '../../auth/application/pending_oauth_request_repository.dart';
import '../../cabinet_api/application/cabinet_api_endpoints.dart';
import '../../cabinet_api/application/cabinet_api_exception.dart';
import '../../cabinet_api/application/cabinet_auth_repository.dart';
import '../../cabinet_api/application/cabinet_bootstrap_controller.dart';
import '../../cabinet_api/application/cabinet_bootstrap_snapshot.dart';
import '../../cabinet_api/application/cabinet_http_client.dart';
import '../../cabinet_api/application/http_cabinet_auth_repository.dart';
import '../../cabinet_api/application/http_cabinet_subscription_repository.dart';
import '../../cabinet_api/application/method_channel_cabinet_session_storage.dart';
import '../../cabinet_api/domain/cabinet_auth_provider.dart';
import '../../cabinet_api/domain/cabinet_oauth_callback_payload.dart';
import '../../cabinet_api/domain/cabinet_email_auth_config.dart';
import '../../cabinet_api/domain/cabinet_session.dart';
import '../../cabinet_api/domain/cabinet_subscription_status.dart';
import '../../purchase/application/cabinet_purchase_controller.dart';
import '../../purchase/application/http_cabinet_payment_repository.dart';
import '../../purchase/application/method_channel_cabinet_pending_purchase_repository.dart';
import '../../purchase/application/http_cabinet_purchase_repository.dart';
import '../../purchase/domain/cabinet_purchase_flow_result.dart';
import '../../purchase/domain/cabinet_purchase_result.dart';
import '../../purchase/domain/cabinet_top_up_payment.dart';
import '../../purchase/presentation/subscription_tab_view.dart';
import '../../profile/presentation/profile_tab_view.dart';
import '../../support/application/http_support_repository.dart';
import '../../support/application/support_controller.dart';
import '../../support/domain/support_ticket.dart';
import '../../support/domain/support_ticket_message.dart';
import '../../support/presentation/support_tab_view.dart';
import '../../navigation/domain/home_tab.dart';
import '../../navigation/presentation/home_bottom_navigation.dart';
import '../../notifications/application/app_notification_bridge.dart';
import '../../../l10n/app_strings.dart';
import '../../app_update/application/app_update_controller.dart';
import '../../app_update/application/app_update_endpoints.dart';
import '../../app_update/presentation/app_update_banner.dart';
import '../../import/application/import_link_resolver.dart';
import '../../import/application/subscription_request_headers_provider.dart';
import '../../import/domain/import_link_error.dart';
import '../../import/domain/resolved_import_link.dart';
import '../../import/domain/resolved_profile_group.dart';
import '../../import/domain/resolved_profile_link.dart';
import '../../import/domain/resolved_subscription_info.dart';
import '../../split_tunnel/application/split_tunnel_apps_repository.dart';
import '../../split_tunnel/domain/split_tunnel_app.dart';
import '../../settings/presentation/settings_sheet.dart';
import '../../s3x/application/s3x_deep_link_bridge.dart';
import '../../vless/domain/vless_profile.dart';
import '../../vpn/application/server_latency_probe.dart';
import '../../vpn/application/vpn_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final CabinetHttpClient _cabinetHttpClient = CabinetHttpClient(
    baseUri: Uri.parse(defaultCabinetApiBaseUrl),
  );
  late final CabinetAuthRepository _cabinetAuthRepository =
      HttpCabinetAuthRepository(
        httpClient: _cabinetHttpClient,
        sessionStorage: const MethodChannelCabinetSessionStorage(),
      );
  late final HttpCabinetSubscriptionRepository _cabinetSubscriptionRepository =
      HttpCabinetSubscriptionRepository(httpClient: _cabinetHttpClient);
  late final HttpCabinetPurchaseRepository _cabinetPurchaseRepository =
      HttpCabinetPurchaseRepository(httpClient: _cabinetHttpClient);
  late final HttpCabinetPaymentRepository _cabinetPaymentRepository =
      HttpCabinetPaymentRepository(httpClient: _cabinetHttpClient);
  late final HttpSupportRepository _supportRepository = HttpSupportRepository(
    httpClient: _cabinetHttpClient,
  );
  late final CabinetPurchaseController _cabinetPurchaseController =
      CabinetPurchaseController(
        repository: _cabinetPurchaseRepository,
        paymentRepository: _cabinetPaymentRepository,
        pendingPurchaseRepository:
            const MethodChannelCabinetPendingPurchaseRepository(),
      );
  late final SupportController _supportController = SupportController(
    repository: _supportRepository,
    onSupportReply: _handleSupportReplyNotification,
  );
  final TextEditingController _controller = TextEditingController();
  final ImportLinkResolver _resolver = ImportLinkResolver(
    headersProvider: SubscriptionRequestHeadersProvider().buildHeaders,
  );
  final AppPreferencesRepository _appPreferencesRepository =
      const AppPreferencesRepository();
  final MethodChannelAuthPlatformBridge _authPlatformBridge =
      MethodChannelAuthPlatformBridge();
  final PendingOAuthRequestRepository _pendingOAuthRequestRepository =
      const PendingOAuthRequestRepository();
  late final OAuthLoginCoordinator _oauthLoginCoordinator =
      OAuthLoginCoordinator(
        authRepository: _cabinetAuthRepository,
        platformBridge: _authPlatformBridge,
        pendingRequestRepository: _pendingOAuthRequestRepository,
      );
  late final CabinetBootstrapController _cabinetBootstrapController =
      CabinetBootstrapController(
        authRepository: _cabinetAuthRepository,
        subscriptionRepository: _cabinetSubscriptionRepository,
      );
  final SplitTunnelAppsRepository _splitTunnelAppsRepository =
      const SplitTunnelAppsRepository();
  final AppUpdateController _appUpdateController = AppUpdateController(
    manifestUri: Uri.parse(defaultUpdateManifestUrl),
  );
  final VpnController _vpnController = VpnController();
  final ServerLatencyProbe _latencyProbe = ServerLatencyProbe();
  final AppNotificationBridge _notificationBridge =
      const AppNotificationBridge();
  final S3xDeepLinkBridge _s3xDeepLinkBridge = const S3xDeepLinkBridge();
  StreamSubscription<Uri>? _authCallbackSubscription;
  StreamSubscription<String>? _s3xDeepLinkSubscription;
  Timer? _cabinetSessionRefreshTimer;
  Timer? _inAppNoticeTimer;
  Timer? _bottomNavRevealTimer;
  bool _isResumingOAuthLogin = false;
  int? _lastNotifiedUpdateVersionCode;
  bool _isBottomNavVisible = false;
  bool? _lastBottomNavEligibility;

  ResolvedImportLink? _resolvedImport;
  ImportLinkError? _error;
  bool _isResolving = false;
  bool _isBootstrapping = true;
  bool _isLoadingSplitTunnel = false;
  bool _isGuestModeEnabled = false;
  bool _isAuthenticating = false;
  bool _isLoadingAuthOptions = false;
  bool _usesCabinetImportLink = false;
  bool _isEmailAuthEnabled = true;
  bool _isPurchasePreloading = false;
  HomeTab _currentTab = HomeTab.vpn;
  int _selectedGroupIndex = 0;
  int _selectedIndex = 0;
  Set<String> _blockedPackages = <String>{};
  CabinetBootstrapSnapshot _cabinetSnapshot = CabinetBootstrapSnapshot.initial;
  List<CabinetAuthProvider> _availableAuthProviders =
      const <CabinetAuthProvider>[];
  bool get _hasCabinetSession => _cabinetSnapshot.session != null;
  bool get _shouldShowBottomNav =>
      _hasCabinetSession &&
      !_isBootstrapping &&
      !_isAuthenticating &&
      _cabinetSnapshot.state == CabinetBootstrapState.ready;

  bool get _showsGroupsAsPrimaryList => _visibleGroups.isNotEmpty;

  List<ResolvedProfileGroup> get _visibleGroups {
    final ResolvedImportLink? resolvedImport = _resolvedImport;
    if (resolvedImport == null) {
      return const <ResolvedProfileGroup>[];
    }

    return resolvedImport.groups;
  }

  List<ResolvedProfileLink> get _visibleProfiles {
    final ResolvedImportLink? resolvedImport = _resolvedImport;
    if (resolvedImport == null) {
      return const <ResolvedProfileLink>[];
    }

    final List<ResolvedProfileGroup> groups = _visibleGroups;
    if (groups.isEmpty) {
      return resolvedImport.profiles;
    }

    if (_selectedGroupIndex >= groups.length) {
      return groups.first.profiles;
    }

    return groups[_selectedGroupIndex].profiles;
  }

  ResolvedProfileLink? get _selectedProfileLink {
    final ResolvedProfileGroup? selectedGroup = _selectedGroup;
    if (selectedGroup != null && selectedGroup.profiles.isNotEmpty) {
      return selectedGroup.profiles.first;
    }

    final List<ResolvedProfileLink> profiles = _visibleProfiles;
    if (profiles.isEmpty) {
      return null;
    }

    if (_selectedIndex >= profiles.length) {
      return profiles.first;
    }

    return profiles[_selectedIndex];
  }

  ResolvedProfileGroup? get _selectedGroup {
    final List<ResolvedProfileGroup> groups = _visibleGroups;
    if (groups.isEmpty) {
      return null;
    }

    if (_selectedGroupIndex >= groups.length) {
      return groups.first;
    }

    return groups[_selectedGroupIndex];
  }

  String? _connectionIdForSelection(
    ResolvedProfileGroup? group,
    ResolvedProfileLink? profileLink,
  ) {
    if (group?.runtimeConfig != null) {
      return 'group:${group!.name}';
    }
    return profileLink?.resolvedLink;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authCallbackSubscription = _authPlatformBridge.callbackLinks.listen((
      Uri uri,
    ) {
      unawaited(_resumePendingOAuthLogin(callbackUri: uri));
    });
    _s3xDeepLinkSubscription = _s3xDeepLinkBridge.links.listen((String link) {
      unawaited(_handleS3xDeepLink(link));
    });
    unawaited(_vpnController.warmUp());
    unawaited(
      _bootstrapImportSource().whenComplete(_consumePendingS3xDeepLink),
    );
    _appUpdateController.addListener(_handleAppUpdateNotification);
    unawaited(_appUpdateController.initialize());
    unawaited(_loadBlockedPackages());
    unawaited(_loadAvailableAuthProviders());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authCallbackSubscription?.cancel();
    _s3xDeepLinkSubscription?.cancel();
    _cabinetSessionRefreshTimer?.cancel();
    _inAppNoticeTimer?.cancel();
    _bottomNavRevealTimer?.cancel();
    _appUpdateController.removeListener(_handleAppUpdateNotification);
    _appUpdateController.dispose();
    _cabinetPurchaseController.dispose();
    _cabinetBootstrapController.dispose();
    _supportController.dispose();
    _vpnController.dispose();
    _latencyProbe.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resumePendingOAuthLogin());
      unawaited(_ensureFreshCabinetSession());
      unawaited(_resumePendingTariffPurchase());
    }
  }

  Future<bool> _parseLink({
    bool showRefreshFeedback = false,
    bool preserveCurrentOnFailure = false,
  }) async {
    final String importLink = _controller.text.trim();
    final ResolvedImportLink? previousResolvedImport = _resolvedImport;
    final int previousSelectedGroupIndex = _selectedGroupIndex;
    final int previousSelectedIndex = _selectedIndex;
    setState(() {
      _isResolving = true;
      _error = null;
    });

    final ImportLinkResult result = await _resolver.resolve(importLink);
    if (!mounted) {
      return false;
    }

    if (result.link == null) {
      setState(() {
        _resolvedImport = preserveCurrentOnFailure
            ? previousResolvedImport
            : null;
        _error = result.error;
        _isResolving = false;
        _selectedGroupIndex = preserveCurrentOnFailure
            ? previousSelectedGroupIndex
            : 0;
        _selectedIndex = preserveCurrentOnFailure ? previousSelectedIndex : 0;
      });
      if (!preserveCurrentOnFailure) {
        _latencyProbe.clear();
      }
      if (showRefreshFeedback) {
        _showRefreshSnackbar(success: false);
      }
      return false;
    }

    setState(() {
      _resolvedImport = result.link;
      _error = result.error;
      _isResolving = false;
      _selectedGroupIndex = 0;
      _selectedIndex = 0;
      _usesCabinetImportLink = false;
    });

    await _appPreferencesRepository.saveLastImportLink(importLink);
    unawaited(_latencyProbe.probeProfiles(result.link!.profiles));
    if (showRefreshFeedback && mounted) {
      _showRefreshSnackbar(success: true);
    }
    return true;
  }

  Future<void> _consumePendingS3xDeepLink() async {
    try {
      final String? link = await _s3xDeepLinkBridge.consumePendingLink();
      if (link == null) {
        return;
      }
      await _handleS3xDeepLink(link);
    } catch (_) {
      // Deep link import is best-effort; manual paste stays available.
    }
  }

  Future<void> _handleS3xDeepLink(String link) async {
    if (!mounted || !link.trim().startsWith('s3x://')) {
      return;
    }

    _controller.text = link.trim();
    setState(() {
      _currentTab = HomeTab.vpn;
      _usesCabinetImportLink = false;
    });
    await _parseLink();
  }

  Future<void> _bootstrapImportSource() async {
    try {
      final bool resumedPendingOAuth = await _resumePendingOAuthLogin();
      if (resumedPendingOAuth || !mounted) {
        return;
      }

      final bool guestModeEnabled = await _appPreferencesRepository
          .loadGuestModeEnabled();
      if (mounted) {
        setState(() {
          _isGuestModeEnabled = guestModeEnabled;
        });
      }

      final CabinetBootstrapSnapshot snapshot =
          await _cabinetBootstrapController.initialize();
      if (!mounted) {
        return;
      }
      setState(() {
        _cabinetSnapshot = snapshot;
      });
      _scheduleCabinetSessionRefresh(snapshot.session);
      unawaited(_preloadPurchaseOptions(snapshot.session));
      unawaited(_resumePendingTariffPurchase());

      final String? savedLink = await _appPreferencesRepository
          .loadLastImportLink();
      if (!mounted) {
        return;
      }

      if (savedLink != null && savedLink.isNotEmpty) {
        _controller.text = savedLink;
        final bool resolved = await _parseLink(preserveCurrentOnFailure: true);
        if (resolved &&
            snapshot.importLink != null &&
            savedLink.trim() == snapshot.importLink!.trim() &&
            mounted) {
          setState(() {
            _usesCabinetImportLink = true;
          });
        }
        return;
      }

      final String? importLink = snapshot.importLink;
      if (importLink == null || importLink.isEmpty) {
        return;
      }

      _controller.text = importLink;
      final bool resolved = await _parseLink(preserveCurrentOnFailure: true);
      if (resolved) {
        await _appPreferencesRepository.saveLastImportLink(importLink);
        if (mounted) {
          setState(() {
            _usesCabinetImportLink = true;
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBootstrapping = false;
        });
      }
    }
  }

  Future<bool> _resumePendingOAuthLogin({Uri? callbackUri}) async {
    if (_isResumingOAuthLogin) {
      return false;
    }
    _isResumingOAuthLogin = true;

    try {
      final pendingRequest = await _pendingOAuthRequestRepository.load();
      final Uri? resolvedCallbackUri =
          callbackUri ?? await _authPlatformBridge.consumePendingCallbackLink();
      if (pendingRequest == null || resolvedCallbackUri == null) {
        return false;
      }

      final payload = CabinetOAuthCallbackPayload.fromUri(resolvedCallbackUri);
      if (!payload.isValid || payload.state != pendingRequest.state) {
        await _pendingOAuthRequestRepository.clear();
        return false;
      }

      if (mounted) {
        setState(() {
          _isAuthenticating = true;
        });
      }

      try {
        final CabinetSession session = await _cabinetAuthRepository
            .loginWithOAuth(
              provider: pendingRequest.provider,
              payload: payload,
            );
        _markCabinetSessionActive(session);
        await _pendingOAuthRequestRepository.clear();
        await _completeCabinetLogin();
        return true;
      } on CabinetApiException {
        await _pendingOAuthRequestRepository.clear();
        if (mounted) {
          setState(() {
            _isAuthenticating = false;
          });
        }
        return false;
      } catch (_) {
        await _pendingOAuthRequestRepository.clear();
        if (mounted) {
          setState(() {
            _isAuthenticating = false;
          });
        }
        return false;
      }
    } finally {
      _isResumingOAuthLogin = false;
    }
  }

  Future<void> _continueAsGuest() async {
    await _appPreferencesRepository.saveGuestModeEnabled(true);
    if (!mounted) {
      return;
    }
    setState(() {
      _isGuestModeEnabled = true;
    });
  }

  Future<void> _showEmailLoginSheet() async {
    if (_isAuthenticating || _isLoadingAuthOptions) {
      return;
    }

    await _loadAuthOptions(forceRefresh: true);
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return EmailLoginSheet(
          onSubmit: _loginWithEmail,
          availableProviders: _availableAuthProviders,
          onSelectProvider: _startProviderLogin,
          isEmailAuthEnabled: _isEmailAuthEnabled,
        );
      },
    );
  }

  Future<String?> _loginWithEmail(String email, String password) async {
    final AppStrings strings = AppStrings.of(context);

    setState(() {
      _isAuthenticating = true;
    });

    try {
      final CabinetSession session = await _cabinetAuthRepository
          .loginWithEmail(email: email, password: password);
      _markCabinetSessionActive(session);
      await _completeCabinetLogin();
      return null;
    } on CabinetApiException catch (error) {
      if (!mounted) {
        return error.message;
      }
      setState(() {
        _isAuthenticating = false;
      });
      return error.message;
    } catch (_) {
      if (!mounted) {
        return strings.authGenericError;
      }
      setState(() {
        _isAuthenticating = false;
      });
      return strings.authGenericError;
    }
  }

  Future<String?> _startProviderLogin(CabinetAuthProvider provider) async {
    final AppStrings strings = AppStrings.of(context);

    setState(() {
      _isAuthenticating = true;
    });

    try {
      await _oauthLoginCoordinator.start(provider);
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
      return null;
    } on CabinetApiException catch (error) {
      if (!mounted) {
        return error.message;
      }
      setState(() {
        _isAuthenticating = false;
      });
      return error.message;
    } on PlatformException {
      if (!mounted) {
        return strings.authOAuthOpenBrowserError;
      }
      setState(() {
        _isAuthenticating = false;
      });
      return strings.authOAuthOpenBrowserError;
    } catch (_) {
      if (!mounted) {
        return strings.authGenericError;
      }
      setState(() {
        _isAuthenticating = false;
      });
      return strings.authGenericError;
    }
  }

  Future<void> _completeCabinetLogin() async {
    await _appPreferencesRepository.saveGuestModeEnabled(false);
    final CabinetBootstrapSnapshot snapshot = await _cabinetBootstrapController
        .initialize();
    if (!mounted) {
      return;
    }

    setState(() {
      _cabinetSnapshot = snapshot;
      _isGuestModeEnabled = false;
    });
    _scheduleCabinetSessionRefresh(snapshot.session);
    await _preloadPurchaseOptions(snapshot.session);
    if (snapshot.session != null) {
      await _supportController.initialize(snapshot.session!);
    } else {
      _supportController.reset();
    }
    await _applyCabinetImportLink(snapshot);

    if (!mounted) {
      return;
    }
    setState(() {
      _isAuthenticating = false;
    });
  }

  void _markCabinetSessionActive(CabinetSession session) {
    if (!mounted) {
      return;
    }

    setState(() {
      _cabinetSnapshot = CabinetBootstrapSnapshot(
        state: CabinetBootstrapState.loading,
        session: session,
        user: _cabinetSnapshot.user,
        subscriptionStatus: _cabinetSnapshot.subscriptionStatus,
        importLink: _cabinetSnapshot.importLink,
      );
      _isGuestModeEnabled = false;
    });
    _scheduleCabinetSessionRefresh(session);
  }

  Future<void> _loadAvailableAuthProviders() {
    return _loadAuthOptions();
  }

  Future<void> _loadAuthOptions({bool forceRefresh = false}) async {
    if (_isLoadingAuthOptions) {
      return;
    }
    if (!forceRefresh &&
        (_availableAuthProviders.isNotEmpty || !_isEmailAuthEnabled)) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingAuthOptions = true;
      });
    }
    try {
      final List<Object> results = await Future.wait<Object>(<Future<Object>>[
        _cabinetAuthRepository.getAvailableAuthProviders(),
        _cabinetAuthRepository.getEmailAuthConfig(),
      ]);
      final List<CabinetAuthProvider> providers =
          results[0] as List<CabinetAuthProvider>;
      final CabinetEmailAuthConfig emailAuthConfig =
          results[1] as CabinetEmailAuthConfig;
      if (!mounted) {
        return;
      }
      setState(() {
        _availableAuthProviders = providers;
        _isEmailAuthEnabled = emailAuthConfig.enabled;
        _isLoadingAuthOptions = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingAuthOptions = false;
      });
    }
  }

  Future<void> _showImportDialog() async {
    final String clipboardValue = await _readClipboardText();
    if (!mounted) {
      return;
    }
    final String? nextLink = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _ImportLinkSheet(
          initialValue: _controller.text,
          clipboardValue: clipboardValue,
        );
      },
    );

    if (nextLink == null || nextLink.trim().isEmpty || !mounted) {
      return;
    }

    _controller.text = nextLink.trim();
    await WidgetsBinding.instance.endOfFrame;
    await _parseLink();
  }

  Future<String> _readClipboardText() async {
    final ClipboardData? clipboardData = await Clipboard.getData(
      Clipboard.kTextPlain,
    );
    return clipboardData?.text?.trim() ?? '';
  }

  Future<void> _refreshSubscription() async {
    final ResolvedImportLink? resolvedImport = _resolvedImport;
    if (resolvedImport == null || !resolvedImport.isRemote || _isResolving) {
      return;
    }

    await _parseLink(showRefreshFeedback: true, preserveCurrentOnFailure: true);
  }

  void _handleAppUpdateNotification() {
    final AppUpdateSnapshot snapshot = _appUpdateController.snapshot;
    final int? versionCode = snapshot.manifest?.versionCode;
    if (snapshot.status != AppUpdateStatus.available || versionCode == null) {
      return;
    }
    if (_lastNotifiedUpdateVersionCode == versionCode) {
      return;
    }
    _lastNotifiedUpdateVersionCode = versionCode;
    final AppStrings strings = AppStrings.of(context);
    unawaited(
      _notificationBridge.show(
        id: 2000 + versionCode,
        title: strings.notificationUpdateTitle(
          snapshot.manifest?.versionName ?? '',
        ),
        body: strings.notificationUpdateBody,
      ),
    );
  }

  Future<void> _handleAppUpdateAction() async {
    final AppUpdateStatus status = _appUpdateController.snapshot.status;
    if (status == AppUpdateStatus.checking ||
        status == AppUpdateStatus.downloading ||
        status == AppUpdateStatus.installing) {
      return;
    }

    if (status == AppUpdateStatus.error || status == AppUpdateStatus.idle) {
      await _appUpdateController.checkForUpdates();
      return;
    }

    await _appUpdateController.downloadAndInstall();
  }

  Future<void> _loadBlockedPackages() async {
    final Set<String> blockedPackages = await _splitTunnelAppsRepository
        .loadBlockedPackages();
    if (!mounted) {
      return;
    }
    setState(() {
      _blockedPackages = blockedPackages;
    });
  }

  void _showRefreshSnackbar({required bool success}) {
    final AppStrings strings = AppStrings.of(context);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? strings.subscriptionUpdatedMessage
                : strings.subscriptionUpdateFailedMessage,
          ),
          backgroundColor: success
              ? const Color(0xFF0F766E)
              : const Color(0xFF991B1B),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showInAppNotice({
    required IconData icon,
    required Color accent,
    required String title,
    required String body,
    String? actionLabel,
    VoidCallback? onTap,
  }) {
    if (!mounted) {
      return;
    }
    _inAppNoticeTimer?.cancel();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          forceActionsBelow: false,
          content: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF0F172A),
                border: Border.all(color: accent.withValues(alpha: 0.45)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.15),
                    blurRadius: 18,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: const Color(0xFFCBD5E1),
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            if (onTap != null)
              TextButton(onPressed: onTap, child: Text(actionLabel ?? 'Open')),
          ],
        ),
      );
    _inAppNoticeTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    });
  }

  void _syncBottomNavReveal(bool shouldShow) {
    _bottomNavRevealTimer?.cancel();
    if (!mounted) {
      return;
    }
    if (!shouldShow) {
      if (_isBottomNavVisible) {
        setState(() {
          _isBottomNavVisible = false;
        });
      }
      return;
    }

    _bottomNavRevealTimer = Timer(const Duration(milliseconds: 260), () {
      if (!mounted || _isBottomNavVisible) {
        return;
      }
      setState(() {
        _isBottomNavVisible = true;
      });
    });
  }

  Future<void> _handlePrimaryAction() async {
    final ResolvedProfileGroup? selectedGroup = _selectedGroup;
    final ResolvedProfileLink? selectedProfileLink = _selectedProfileLink;
    if (selectedGroup == null && selectedProfileLink == null) {
      await _parseLink();
    }

    final ResolvedProfileGroup? currentGroup = _selectedGroup;
    final ResolvedProfileLink? currentProfileLink = _selectedProfileLink;
    if (currentGroup == null && currentProfileLink == null) {
      return;
    }

    final VpnConnectionState state = _vpnController.snapshot.state;
    final String activeConnectionId = currentGroup?.runtimeConfig != null
        ? 'group:${currentGroup!.name}'
        : currentProfileLink!.resolvedLink;
    final bool isCurrentServerActive = _vpnController.isActiveConnection(
      activeConnectionId,
    );
    if (isCurrentServerActive &&
        (state == VpnConnectionState.connected ||
            state == VpnConnectionState.connecting ||
            state == VpnConnectionState.disconnecting)) {
      await _vpnController.disconnect();
      return;
    }

    if (currentGroup?.runtimeConfig != null) {
      await _vpnController.connectFromConfig(
        runtimeConfig: currentGroup!.runtimeConfig!,
        remark: currentGroup.name,
        connectionId: 'group:${currentGroup.name}',
        blockedApps: _blockedPackages.toList(),
      );
      return;
    }

    await _vpnController.connectFromLink(
      shareLink: currentProfileLink!.resolvedLink,
      remarkFallback: currentProfileLink.profile.remark ?? 'VLESS',
      blockedApps: _blockedPackages.toList(),
    );
  }

  Future<void> _showSplitTunnelDialog() async {
    if (_isLoadingSplitTunnel) {
      return;
    }

    setState(() {
      _isLoadingSplitTunnel = true;
    });

    final List<SplitTunnelApp> apps = await _splitTunnelAppsRepository
        .listApps();
    if (!mounted) {
      return;
    }

    final Set<String>? nextBlockedPackages =
        await showModalBottomSheet<Set<String>>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return _SplitTunnelSheet(
              strings: AppStrings.of(context),
              apps: apps,
              initiallyBlockedPackages: _blockedPackages,
            );
          },
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingSplitTunnel = false;
    });

    if (nextBlockedPackages == null) {
      return;
    }

    await _splitTunnelAppsRepository.saveBlockedPackages(nextBlockedPackages);
    if (!mounted) {
      return;
    }
    setState(() {
      _blockedPackages = nextBlockedPackages;
    });
  }

  Future<void> _showSettingsDialog() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SettingsSheet(
          strings: AppStrings.of(context),
          blockedAppsCount: _blockedPackages.length,
          hasCabinetSession: _hasCabinetSession,
          onOpenLogin: _showEmailLoginSheet,
          onManageSplitTunnel: _showSplitTunnelDialog,
        );
      },
    );
  }

  void _selectHomeTab(HomeTab tab) {
    if (!mounted) {
      return;
    }
    setState(() {
      _currentTab = tab;
    });
    if (tab == HomeTab.subscription) {
      unawaited(_prepareSubscriptionTab());
      return;
    }
    if (tab == HomeTab.support) {
      unawaited(_prepareSupportTab());
      return;
    }
    if (tab == HomeTab.profile) {
      unawaited(_prepareProfileTab());
    }
  }

  Future<void> _prepareSubscriptionTab() async {
    final CabinetSession? previousSession = _cabinetSnapshot.session;
    final bool hadPurchaseOptions = _cabinetPurchaseController.options != null;
    final bool hadUnauthorizedError = _isUnauthorizedPurchaseError(
      _cabinetPurchaseController.errorMessage,
    );

    final CabinetSession? session = await _ensureFreshCabinetSession();
    if (session == null) {
      return;
    }

    final bool sessionChanged =
        previousSession == null ||
        previousSession.accessToken != session.accessToken ||
        previousSession.expiresAt != session.expiresAt;
    if (hadPurchaseOptions && !sessionChanged && !hadUnauthorizedError) {
      return;
    }

    if (sessionChanged || hadUnauthorizedError) {
      _cabinetPurchaseController.reset();
    }
    await _preloadPurchaseOptions(session, true);
  }

  Future<void> _prepareSupportTab() async {
    final CabinetSession? session = await _ensureFreshCabinetSession();
    if (session == null) {
      return;
    }
    await _supportController.initialize(session);
  }

  Future<void> _handleSupportReplyNotification(SupportTicket ticket) async {
    final AppStrings strings = AppStrings.of(context);
    if (_currentTab == HomeTab.support &&
        _supportController.selectedTicket?.id == ticket.id) {
      return;
    }
    final SupportTicketMessage? lastAdminMessage = ticket.messages
        .where((SupportTicketMessage message) => message.isFromAdmin)
        .cast<SupportTicketMessage?>()
        .lastWhere(
          (SupportTicketMessage? message) => message != null,
          orElse: () => null,
        );
    final String body = (lastAdminMessage?.messageText ?? '').trim();
    await _notificationBridge.show(
      id: 3000 + ticket.id,
      title: strings.notificationSupportReplyTitle,
      body: body.isEmpty ? strings.notificationSupportReplyBody : body,
    );
    _showInAppNotice(
      icon: Icons.support_agent_rounded,
      accent: const Color(0xFF2DD4BF),
      title: strings.notificationSupportReplyTitle,
      body: body.isEmpty ? strings.notificationSupportReplyBody : body,
      actionLabel: strings.supportOpenTicketTitle,
      onTap: () {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
        unawaited(_openSupportTicket(ticket.id));
      },
    );
  }

  Future<void> _openSupportTicket(int ticketId) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _currentTab = HomeTab.support;
    });
    final CabinetSession? session = await _ensureFreshCabinetSession();
    if (session == null) {
      return;
    }
    await _supportController.initialize(session);
    await _supportController.selectTicket(ticketId);
  }

  Future<CabinetSession?> _ensureFreshCabinetSession({
    bool forceRefresh = false,
  }) async {
    final CabinetSession? currentSession = _cabinetSnapshot.session;
    if (currentSession == null) {
      return null;
    }
    if (!forceRefresh && !currentSession.shouldRefreshSoon()) {
      _scheduleCabinetSessionRefresh(currentSession);
      return currentSession;
    }

    final CabinetSession? refreshedSession = await _cabinetAuthRepository
        .bootstrapSession();
    if (!mounted) {
      return refreshedSession;
    }
    if (refreshedSession == null) {
      setState(() {
        _cabinetSnapshot = const CabinetBootstrapSnapshot(
          state: CabinetBootstrapState.unauthenticated,
        );
      });
      _scheduleCabinetSessionRefresh(null);
      _cabinetPurchaseController.reset();
      return null;
    }

    if (refreshedSession.accessToken != currentSession.accessToken ||
        refreshedSession.expiresAt != currentSession.expiresAt) {
      setState(() {
        _cabinetSnapshot = _cabinetSnapshot.copyWith(
          state: CabinetBootstrapState.ready,
          session: refreshedSession,
          errorMessage: null,
        );
      });
      _cabinetPurchaseController.reset();
    }
    await _supportController.initialize(refreshedSession);
    _scheduleCabinetSessionRefresh(refreshedSession);
    return refreshedSession;
  }

  Future<void> _prepareProfileTab() async {
    final CabinetSession? session = await _ensureFreshCabinetSession();
    if (session == null || !mounted) {
      return;
    }

    if (_cabinetSnapshot.user != null &&
        _cabinetSnapshot.subscriptionStatus != null &&
        _cabinetSnapshot.state == CabinetBootstrapState.ready) {
      return;
    }

    await _refreshCabinetSnapshot();
  }

  Future<void> _refreshCabinetSnapshot() async {
    final CabinetBootstrapSnapshot snapshot = await _cabinetBootstrapController
        .initialize();
    if (!mounted) {
      return;
    }
    setState(() {
      _cabinetSnapshot = snapshot;
    });
    _scheduleCabinetSessionRefresh(snapshot.session);
    _cabinetPurchaseController.reset();
    if (snapshot.session != null) {
      await _supportController.initialize(snapshot.session!);
    } else {
      _supportController.reset();
    }
    await _preloadPurchaseOptions(snapshot.session);
    await _applyCabinetImportLink(snapshot);
  }

  Future<void> _handlePurchaseCompleted(CabinetPurchaseResult result) async {
    await _refreshCabinetSnapshot();
    if (!mounted) {
      return;
    }

    final AppStrings strings = AppStrings.of(context);
    final String message = result.message.trim();
    unawaited(
      _notificationBridge.show(
        id: 1001,
        title: strings.notificationPurchaseTitle,
        body: message.isNotEmpty ? message : strings.notificationPurchaseBody,
      ),
    );

    setState(() {
      _currentTab = HomeTab.vpn;
    });

    if (message.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openPurchaseCheckout(CabinetTopUpPayment payment) async {
    await _authPlatformBridge.openExternalUrl(payment.paymentUrl);
  }

  Future<void> _resumePendingTariffPurchase() async {
    final CabinetSession? session = await _ensureFreshCabinetSession();
    if (session == null) {
      return;
    }

    final CabinetPurchaseFlowResult? result = await _cabinetPurchaseController
        .resumePendingTariffPurchase(session);
    if (result == null ||
        !result.isPurchased ||
        result.purchaseResult == null) {
      return;
    }

    await _handlePurchaseCompleted(result.purchaseResult!);
  }

  Future<void> _applyCabinetImportLink(
    CabinetBootstrapSnapshot snapshot,
  ) async {
    final String? importLink = snapshot.importLink;
    if (importLink == null || importLink.isEmpty) {
      return;
    }

    _controller.text = importLink;
    final bool resolved = await _parseLink(preserveCurrentOnFailure: true);
    if (!resolved) {
      return;
    }

    await _appPreferencesRepository.saveLastImportLink(importLink);
    if (!mounted) {
      return;
    }

    setState(() {
      _usesCabinetImportLink = true;
    });
  }

  Future<void> _preloadPurchaseOptions([
    CabinetSession? session,
    bool allowRetryAfterUnauthorized = false,
  ]) async {
    final CabinetSession? candidateSession =
        session ?? _cabinetSnapshot.session;
    if (candidateSession == null || _isPurchasePreloading) {
      return;
    }
    if (_cabinetPurchaseController.options != null ||
        _cabinetPurchaseController.isLoading) {
      return;
    }

    _isPurchasePreloading = true;
    try {
      final CabinetSession effectiveSession = candidateSession.isExpired
          ? (await _ensureFreshCabinetSession(forceRefresh: true)) ??
                candidateSession
          : candidateSession;
      await _cabinetPurchaseController.initialize(effectiveSession);
      if (allowRetryAfterUnauthorized &&
          _isUnauthorizedPurchaseError(
            _cabinetPurchaseController.errorMessage,
          )) {
        final CabinetSession? refreshedSession =
            await _ensureFreshCabinetSession(forceRefresh: true);
        if (refreshedSession != null) {
          _cabinetPurchaseController.reset();
          await _cabinetPurchaseController.initialize(refreshedSession);
        }
      }
    } finally {
      _isPurchasePreloading = false;
    }
  }

  bool _isUnauthorizedPurchaseError(String? message) {
    return message?.trim().toLowerCase() == 'unauthorized';
  }

  Future<void> _logoutCabinetSession() async {
    await _cabinetAuthRepository.clearSession();
    await _appPreferencesRepository.saveGuestModeEnabled(false);
    if (_usesCabinetImportLink) {
      await _appPreferencesRepository.saveLastImportLink('');
    }
    if (!mounted) {
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
    setState(() {
      _cabinetSnapshot = const CabinetBootstrapSnapshot(
        state: CabinetBootstrapState.unauthenticated,
      );
      _isGuestModeEnabled = false;
      _usesCabinetImportLink = false;
      if (_resolvedImport != null) {
        _resolvedImport = null;
        _error = null;
        _selectedGroupIndex = 0;
        _selectedIndex = 0;
      }
    });
    _scheduleCabinetSessionRefresh(null);
    _cabinetPurchaseController.reset();
    _supportController.reset();
    _latencyProbe.clear();
  }

  void _scheduleCabinetSessionRefresh(CabinetSession? session) {
    _cabinetSessionRefreshTimer?.cancel();
    _cabinetSessionRefreshTimer = null;
    if (session == null) {
      return;
    }

    final DateTime now = DateTime.now().toUtc();
    Duration delay = session.expiresAt
        .subtract(CabinetSession.refreshLeeway)
        .difference(now);
    if (delay <= Duration.zero) {
      delay = const Duration(minutes: 1);
    }

    _cabinetSessionRefreshTimer = Timer(delay, () {
      unawaited(_refreshCabinetSessionSilently());
    });
  }

  Future<void> _refreshCabinetSessionSilently() async {
    final CabinetSession? session = _cabinetSnapshot.session;
    if (session == null) {
      return;
    }

    final CabinetSession? refreshedSession = await _ensureFreshCabinetSession(
      forceRefresh: session.shouldRefreshSoon(),
    );
    if (!mounted) {
      return;
    }
    _scheduleCabinetSessionRefresh(
      refreshedSession ?? _cabinetSnapshot.session,
    );
  }

  Future<void> _refreshLatencies() async {
    final ResolvedImportLink? resolvedImport = _resolvedImport;
    if (resolvedImport == null) {
      return;
    }

    await _latencyProbe.probeProfiles(resolvedImport.profiles);
  }

  void _selectGroup(int index) {
    final List<ResolvedProfileGroup> groups = _visibleGroups;
    if (index < 0 || index >= groups.length) {
      return;
    }

    setState(() {
      _selectedGroupIndex = index;
      _selectedIndex = 0;
    });
  }

  Future<void> _selectServer(int index) async {
    if (_showsGroupsAsPrimaryList) {
      return;
    }

    final List<ResolvedProfileLink> profiles = _visibleProfiles;
    if (index < 0 || index >= profiles.length) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _vpnController,
        _latencyProbe,
        _appUpdateController,
      ]),
      builder: (BuildContext context, Widget? child) {
        final ResolvedProfileLink? selectedProfileLink = _selectedProfileLink;
        final VpnStatusSnapshot vpnSnapshot = _vpnController.snapshot;
        final AppUpdateSnapshot appUpdateSnapshot =
            _appUpdateController.snapshot;
        final Widget activeTab = _buildActiveTab(
          context: context,
          strings: strings,
          selectedProfileLink: selectedProfileLink,
          vpnSnapshot: vpnSnapshot,
          appUpdateSnapshot: appUpdateSnapshot,
        );

        final bool shouldShowBottomNav = _shouldShowBottomNav;
        if (_lastBottomNavEligibility != shouldShowBottomNav) {
          _lastBottomNavEligibility = shouldShowBottomNav;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncBottomNavReveal(shouldShowBottomNav);
          });
        }

        return Scaffold(
          extendBody: true,
          body: Stack(
            children: <Widget>[
              const _Backdrop(),
              SafeArea(
                bottom: false,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 480),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    _isBottomNavVisible ? 112 : 20,
                  ),
                  child: activeTab,
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  child: IgnorePointer(
                    ignoring: !_isBottomNavVisible,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 520),
                      curve: Curves.easeOutCubic,
                      offset: _isBottomNavVisible
                          ? Offset.zero
                          : const Offset(0, 0.55),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 460),
                        curve: Curves.easeOutCubic,
                        opacity: _isBottomNavVisible ? 1 : 0,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 520),
                          curve: Curves.easeOutCubic,
                          scale: _isBottomNavVisible ? 1 : 0.96,
                          child: HomeBottomNavigation(
                            strings: strings,
                            currentTab: _currentTab,
                            onSelectTab: _selectHomeTab,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveTab({
    required BuildContext context,
    required AppStrings strings,
    required ResolvedProfileLink? selectedProfileLink,
    required VpnStatusSnapshot vpnSnapshot,
    required AppUpdateSnapshot appUpdateSnapshot,
  }) {
    if (_isBootstrapping) {
      return const _StartupLoadingState();
    }

    if (_isAuthenticating && _resolvedImport == null) {
      return _StartupLoadingState(message: strings.authProfileLoadingMessage);
    }

    switch (_currentTab) {
      case HomeTab.vpn:
        if (_resolvedImport == null &&
            !_isGuestModeEnabled &&
            _cabinetSnapshot.state == CabinetBootstrapState.unauthenticated) {
          return AuthGatePanel(
            strings: strings,
            isLoading: _isAuthenticating,
            onLogin: _showEmailLoginSheet,
            onContinueAsGuest: _continueAsGuest,
          );
        }
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < 980;
            final ResolvedProfileGroup? selectedGroup = _selectedGroup;
            final String? selectedConnectionId = _connectionIdForSelection(
              selectedGroup,
              selectedProfileLink,
            );
            final bool selectedConnectionActive =
                selectedConnectionId != null &&
                _vpnController.isActiveConnection(selectedConnectionId);
            return compact
                ? _CompactLayout(
                    strings: strings,
                    resolvedImport: _resolvedImport,
                    cabinetSubscriptionStatus:
                        _cabinetSnapshot.subscriptionStatus,
                    hasCabinetSession: _hasCabinetSession,
                    groups: _visibleGroups,
                    visibleProfiles: _visibleProfiles,
                    showGroupsAsPrimaryList: _showsGroupsAsPrimaryList,
                    selectedGroup: selectedGroup,
                    selectedGroupIndex: _selectedGroupIndex,
                    selectedProfileLink: selectedProfileLink,
                    selectedIndex: _selectedIndex,
                    latencyProbe: _latencyProbe,
                    vpnSnapshot: vpnSnapshot,
                    selectedConnectionActive: selectedConnectionActive,
                    appUpdateSnapshot: appUpdateSnapshot,
                    error: _error,
                    isResolving: _isResolving,
                    onSelectGroup: _selectGroup,
                    onSelectServer: _selectServer,
                    onAddLink: _showImportDialog,
                    onLogin: _showEmailLoginSheet,
                    onOpenSettings: _showSettingsDialog,
                    onRefreshSubscription: _refreshSubscription,
                    onUpdateApp: _handleAppUpdateAction,
                    onRefreshLatency: _refreshLatencies,
                    onPrimaryAction: _handlePrimaryAction,
                  )
                : _WideLayout(
                    strings: strings,
                    resolvedImport: _resolvedImport,
                    cabinetSubscriptionStatus:
                        _cabinetSnapshot.subscriptionStatus,
                    hasCabinetSession: _hasCabinetSession,
                    groups: _visibleGroups,
                    visibleProfiles: _visibleProfiles,
                    showGroupsAsPrimaryList: _showsGroupsAsPrimaryList,
                    selectedGroup: selectedGroup,
                    selectedProfileLink: selectedProfileLink,
                    selectedGroupIndex: _selectedGroupIndex,
                    selectedIndex: _selectedIndex,
                    latencyProbe: _latencyProbe,
                    vpnSnapshot: vpnSnapshot,
                    selectedConnectionActive: selectedConnectionActive,
                    appUpdateSnapshot: appUpdateSnapshot,
                    error: _error,
                    isResolving: _isResolving,
                    onSelectGroup: _selectGroup,
                    onSelectServer: _selectServer,
                    onAddLink: _showImportDialog,
                    onLogin: _showEmailLoginSheet,
                    onOpenSettings: _showSettingsDialog,
                    onRefreshSubscription: _refreshSubscription,
                    onUpdateApp: _handleAppUpdateAction,
                    onRefreshLatency: _refreshLatencies,
                    onPrimaryAction: _handlePrimaryAction,
                  );
          },
        );
      case HomeTab.subscription:
        return SubscriptionTabView(
          strings: strings,
          session: _cabinetSnapshot.session,
          controller: _cabinetPurchaseController,
          onLogin: _showEmailLoginSheet,
          onPurchased: _handlePurchaseCompleted,
          onOpenCheckout: _openPurchaseCheckout,
        );
      case HomeTab.support:
        return SupportTabView(
          strings: strings,
          session: _cabinetSnapshot.session,
          controller: _supportController,
          onLogin: _showEmailLoginSheet,
        );
      case HomeTab.profile:
        return ProfileTabView(
          strings: strings,
          snapshot: _cabinetSnapshot,
          onLogin: _showEmailLoginSheet,
          onRefresh: _refreshCabinetSnapshot,
          onLogout: _logoutCabinetSession,
        );
    }
  }
}

class _ImportLinkSheet extends StatefulWidget {
  const _ImportLinkSheet({
    required this.initialValue,
    required this.clipboardValue,
  });

  final String initialValue;
  final String clipboardValue;

  @override
  State<_ImportLinkSheet> createState() => _ImportLinkSheetState();
}

class _ImportLinkSheetState extends State<_ImportLinkSheet> {
  late final TextEditingController _draftController = TextEditingController(
    text: widget.clipboardValue.isNotEmpty
        ? widget.clipboardValue
        : widget.initialValue,
  );

  bool get _hasClipboardImport {
    final String clipboardValue = widget.clipboardValue.trim();
    return clipboardValue.isNotEmpty &&
        clipboardValue != _draftController.text.trim();
  }

  void _applyClipboardValue() {
    final String clipboardValue = widget.clipboardValue.trim();
    if (clipboardValue.isEmpty) {
      return;
    }
    _draftController
      ..text = clipboardValue
      ..selection = TextSelection.collapsed(offset: clipboardValue.length);
    setState(() {});
  }

  @override
  void dispose() {
    _draftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + viewInsets.bottom),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xF20F172A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.importTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.importHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFCBD5E1),
                    height: 1.35,
                  ),
                ),
                if (widget.clipboardValue.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _ClipboardBanner(
                    strings: strings,
                    onUseClipboard: _applyClipboardValue,
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _draftController,
                  onChanged: (_) => setState(() {}),
                  minLines: 4,
                  maxLines: 8,
                  style: const TextStyle(color: Color(0xFFF8FAFC)),
                  decoration: InputDecoration(
                    hintText: strings.inputHint,
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0x1F0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFF14B8A6)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(strings.closeAction),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(_draftController.text.trim()),
                        icon: const Icon(Icons.add_link_rounded),
                        label: Text(strings.applyLinkAction),
                      ),
                    ),
                  ],
                ),
                if (_hasClipboardImport) ...<Widget>[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(widget.clipboardValue.trim()),
                      icon: const Icon(Icons.content_paste_go_rounded),
                      label: Text(strings.importFromClipboardAction),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClipboardBanner extends StatelessWidget {
  const _ClipboardBanner({required this.strings, required this.onUseClipboard});

  final AppStrings strings;
  final VoidCallback onUseClipboard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1414B8A6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x332DD4BF)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.content_paste_rounded, color: Color(0xFF5EEAD4)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.clipboardReadyLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onUseClipboard,
            child: Text(strings.useClipboardAction),
          ),
        ],
      ),
    );
  }
}

class _SplitTunnelSheet extends StatefulWidget {
  const _SplitTunnelSheet({
    required this.strings,
    required this.apps,
    required this.initiallyBlockedPackages,
  });

  final AppStrings strings;
  final List<SplitTunnelApp> apps;
  final Set<String> initiallyBlockedPackages;

  @override
  State<_SplitTunnelSheet> createState() => _SplitTunnelSheetState();
}

class _SplitTunnelSheetState extends State<_SplitTunnelSheet> {
  late final Set<String> _selectedPackages = <String>{
    ...widget.initiallyBlockedPackages,
  };
  String _query = '';

  Iterable<SplitTunnelApp> get _visibleApps {
    final String normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return widget.apps;
    }

    return widget.apps.where((SplitTunnelApp app) {
      return app.label.toLowerCase().contains(normalizedQuery) ||
          app.packageName.toLowerCase().contains(normalizedQuery);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<SplitTunnelApp> visibleApps = _visibleApps.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 720),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xF20F172A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.strings.splitTunnelTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.strings.splitTunnelBody,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFCBD5E1),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (String value) => setState(() => _query = value),
                  style: const TextStyle(color: Color(0xFFF8FAFC)),
                  decoration: InputDecoration(
                    hintText: widget.strings.splitTunnelSearchHint,
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: const Color(0x1F0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFF14B8A6)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.strings.splitTunnelSelectedCount(
                    _selectedPackages.length,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFCBD5E1),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: visibleApps.isEmpty
                      ? Center(
                          child: Text(
                            _query.trim().isEmpty
                                ? widget.strings.splitTunnelUnavailable
                                : widget.strings.splitTunnelEmptySearch,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFFCBD5E1)),
                          ),
                        )
                      : ListView.separated(
                          itemCount: visibleApps.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (BuildContext context, int index) {
                            final SplitTunnelApp app = visibleApps[index];
                            final bool selected = _selectedPackages.contains(
                              app.packageName,
                            );
                            return CheckboxListTile(
                              value: selected,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedPackages.add(app.packageName);
                                  } else {
                                    _selectedPackages.remove(app.packageName);
                                  }
                                });
                              },
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              tileColor: Colors.white.withValues(alpha: 0.04),
                              activeColor: const Color(0xFF14B8A6),
                              title: Text(
                                app.label,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              subtitle: Text(
                                app.packageName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: const Color(0xFF94A3B8)),
                              ),
                              secondary: app.isSystemApp
                                  ? const Icon(
                                      Icons.shield_rounded,
                                      color: Color(0xFFF59E0B),
                                    )
                                  : const Icon(
                                      Icons.android_rounded,
                                      color: Color(0xFF5EEAD4),
                                    ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                OverflowBar(
                  alignment: MainAxisAlignment.spaceBetween,
                  overflowAlignment: OverflowBarAlignment.center,
                  spacing: 8,
                  overflowSpacing: 8,
                  children: <Widget>[
                    SizedBox(
                      width: 132,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(widget.strings.closeAction),
                      ),
                    ),
                    SizedBox(
                      width: 132,
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _selectedPackages.clear();
                        }),
                        child: Text(widget.strings.clearSplitTunnelAction),
                      ),
                    ),
                    SizedBox(
                      width: 132,
                      child: FilledButton(
                        onPressed: () =>
                            Navigator.of(context).pop(_selectedPackages),
                        child: Text(widget.strings.saveSplitTunnelAction),
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

class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.strings,
    required this.resolvedImport,
    required this.cabinetSubscriptionStatus,
    required this.hasCabinetSession,
    required this.groups,
    required this.visibleProfiles,
    required this.showGroupsAsPrimaryList,
    required this.selectedGroup,
    required this.selectedProfileLink,
    required this.selectedGroupIndex,
    required this.selectedIndex,
    required this.latencyProbe,
    required this.vpnSnapshot,
    required this.selectedConnectionActive,
    required this.appUpdateSnapshot,
    required this.error,
    required this.isResolving,
    required this.onSelectGroup,
    required this.onSelectServer,
    required this.onAddLink,
    required this.onLogin,
    required this.onOpenSettings,
    required this.onRefreshSubscription,
    required this.onUpdateApp,
    required this.onRefreshLatency,
    required this.onPrimaryAction,
  });

  final AppStrings strings;
  final ResolvedImportLink? resolvedImport;
  final CabinetSubscriptionStatus? cabinetSubscriptionStatus;
  final bool hasCabinetSession;
  final List<ResolvedProfileGroup> groups;
  final List<ResolvedProfileLink> visibleProfiles;
  final bool showGroupsAsPrimaryList;
  final ResolvedProfileGroup? selectedGroup;
  final ResolvedProfileLink? selectedProfileLink;
  final int selectedGroupIndex;
  final int selectedIndex;
  final ServerLatencyProbe latencyProbe;
  final VpnStatusSnapshot vpnSnapshot;
  final bool selectedConnectionActive;
  final AppUpdateSnapshot appUpdateSnapshot;
  final ImportLinkError? error;
  final bool isResolving;
  final ValueChanged<int> onSelectGroup;
  final ValueChanged<int> onSelectServer;
  final Future<void> Function() onAddLink;
  final Future<void> Function() onLogin;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onRefreshSubscription;
  final Future<void> Function() onUpdateApp;
  final Future<void> Function() onRefreshLatency;
  final Future<void> Function() onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    if (resolvedImport == null) {
      return _NoSubscriptionPanel(
        strings: strings,
        hasCabinetSession: hasCabinetSession,
        appUpdateSnapshot: appUpdateSnapshot,
        onAddLink: onAddLink,
        onLogin: onLogin,
        onUpdateApp: onUpdateApp,
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1260),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 320,
              child: _HeroPanel(
                strings: strings,
                resolvedImport: resolvedImport,
                cabinetSubscriptionStatus: cabinetSubscriptionStatus,
                compact: false,
                appUpdateSnapshot: appUpdateSnapshot,
                isRefreshing: isResolving,
                onAddLink: onAddLink,
                onOpenSettings: onOpenSettings,
                onRefreshSubscription: onRefreshSubscription,
                onUpdateApp: onUpdateApp,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _ServerSelectionPanel(
                strings: strings,
                resolvedImport: resolvedImport,
                groups: groups,
                visibleProfiles: visibleProfiles,
                showGroupsAsPrimaryList: showGroupsAsPrimaryList,
                selectedGroupIndex: selectedGroupIndex,
                selectedIndex: selectedIndex,
                latencyProbe: latencyProbe,
                error: error,
                isResolving: isResolving,
                onSelectGroup: onSelectGroup,
                onSelectServer: onSelectServer,
                onRefreshLatency: onRefreshLatency,
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 260,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _ActionMenu(
                  strings: strings,
                  vpnState: vpnSnapshot.state,
                  selectedConnectionActive: selectedConnectionActive,
                  connectionDuration: vpnSnapshot.connectionDuration,
                  onPrimaryAction: onPrimaryAction,
                  compact: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactLayout extends StatelessWidget {
  const _CompactLayout({
    required this.strings,
    required this.resolvedImport,
    required this.cabinetSubscriptionStatus,
    required this.hasCabinetSession,
    required this.groups,
    required this.visibleProfiles,
    required this.showGroupsAsPrimaryList,
    required this.selectedGroup,
    required this.selectedProfileLink,
    required this.selectedGroupIndex,
    required this.selectedIndex,
    required this.latencyProbe,
    required this.vpnSnapshot,
    required this.selectedConnectionActive,
    required this.appUpdateSnapshot,
    required this.error,
    required this.isResolving,
    required this.onSelectGroup,
    required this.onSelectServer,
    required this.onAddLink,
    required this.onLogin,
    required this.onOpenSettings,
    required this.onRefreshSubscription,
    required this.onUpdateApp,
    required this.onRefreshLatency,
    required this.onPrimaryAction,
  });

  final AppStrings strings;
  final ResolvedImportLink? resolvedImport;
  final CabinetSubscriptionStatus? cabinetSubscriptionStatus;
  final bool hasCabinetSession;
  final List<ResolvedProfileGroup> groups;
  final List<ResolvedProfileLink> visibleProfiles;
  final bool showGroupsAsPrimaryList;
  final ResolvedProfileGroup? selectedGroup;
  final ResolvedProfileLink? selectedProfileLink;
  final int selectedGroupIndex;
  final int selectedIndex;
  final ServerLatencyProbe latencyProbe;
  final VpnStatusSnapshot vpnSnapshot;
  final bool selectedConnectionActive;
  final AppUpdateSnapshot appUpdateSnapshot;
  final ImportLinkError? error;
  final bool isResolving;
  final ValueChanged<int> onSelectGroup;
  final ValueChanged<int> onSelectServer;
  final Future<void> Function() onAddLink;
  final Future<void> Function() onLogin;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onRefreshSubscription;
  final Future<void> Function() onUpdateApp;
  final Future<void> Function() onRefreshLatency;
  final Future<void> Function() onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    if (resolvedImport == null) {
      return _NoSubscriptionPanel(
        strings: strings,
        hasCabinetSession: hasCabinetSession,
        appUpdateSnapshot: appUpdateSnapshot,
        onAddLink: onAddLink,
        onLogin: onLogin,
        onUpdateApp: onUpdateApp,
      );
    }

    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double heroHeight = screenHeight < 560
        ? 122
        : screenHeight < 740
        ? 136
        : 152;

    final Widget heroPanel = SizedBox(
      height: heroHeight,
      child: _HeroPanel(
        strings: strings,
        resolvedImport: resolvedImport,
        cabinetSubscriptionStatus: cabinetSubscriptionStatus,
        compact: true,
        appUpdateSnapshot: appUpdateSnapshot,
        isRefreshing: isResolving,
        onAddLink: onAddLink,
        onOpenSettings: onOpenSettings,
        onRefreshSubscription: onRefreshSubscription,
        onUpdateApp: onUpdateApp,
      ),
    );
    final Widget actionButton = _ActionMenu(
      strings: strings,
      vpnState: vpnSnapshot.state,
      selectedConnectionActive: selectedConnectionActive,
      connectionDuration: vpnSnapshot.connectionDuration,
      onPrimaryAction: onPrimaryAction,
      compact: true,
    );
    final Widget serverPanel = _ServerSelectionPanel(
      strings: strings,
      resolvedImport: resolvedImport,
      groups: groups,
      visibleProfiles: visibleProfiles,
      showGroupsAsPrimaryList: showGroupsAsPrimaryList,
      selectedGroupIndex: selectedGroupIndex,
      selectedIndex: selectedIndex,
      latencyProbe: latencyProbe,
      error: error,
      isResolving: isResolving,
      onSelectGroup: onSelectGroup,
      onSelectServer: onSelectServer,
      onRefreshLatency: onRefreshLatency,
    );

    final Widget content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        children: <Widget>[
          heroPanel,
          const SizedBox(height: 10),
          actionButton,
          const SizedBox(height: 12),
          Expanded(child: serverPanel),
        ],
      ),
    );

    return Center(child: content);
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.strings,
    required this.resolvedImport,
    required this.cabinetSubscriptionStatus,
    required this.compact,
    required this.appUpdateSnapshot,
    required this.isRefreshing,
    required this.onAddLink,
    required this.onOpenSettings,
    required this.onRefreshSubscription,
    required this.onUpdateApp,
  });

  final AppStrings strings;
  final ResolvedImportLink? resolvedImport;
  final CabinetSubscriptionStatus? cabinetSubscriptionStatus;
  final bool compact;
  final AppUpdateSnapshot appUpdateSnapshot;
  final bool isRefreshing;
  final Future<void> Function() onAddLink;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onRefreshSubscription;
  final Future<void> Function() onUpdateApp;

  @override
  Widget build(BuildContext context) {
    final ResolvedSubscriptionInfo? subscriptionInfo =
        resolvedImport?.subscriptionInfo;
    final String trafficValue = _formatTrafficValue(
      subscriptionInfo,
      cabinetSubscriptionStatus,
      strings,
    );
    final String validityValue = _formatValidityValue(
      subscriptionInfo,
      cabinetSubscriptionStatus,
      strings,
    );
    final String? announcement = _announcementPreview(
      subscriptionInfo?.announce,
    );
    final bool canRefresh = resolvedImport?.isRemote == true && !isRefreshing;
    final List<Widget> badges = <Widget>[
      _Pill(
        icon: Icons.verified_rounded,
        label: strings.subscriptionActiveLabel,
        accent: const Color(0xFF34D399),
      ),
    ];

    final Widget content = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: badges.take(2).toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _HeroActions(
                    strings: strings,
                    compact: true,
                    appUpdateSnapshot: appUpdateSnapshot,
                    isRefreshing: isRefreshing,
                    onAddLink: onAddLink,
                    onOpenSettings: onOpenSettings,
                    onRefreshSubscription: canRefresh
                        ? onRefreshSubscription
                        : null,
                    onUpdateApp: onUpdateApp,
                  ),
                ],
              ),
              if (_showsUpdateBanner(appUpdateSnapshot)) ...<Widget>[
                const SizedBox(height: 10),
                AppUpdateBanner(
                  snapshot: appUpdateSnapshot,
                  onPrimaryAction: onUpdateApp,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _CompactMetricChip(
                      value: trafficValue,
                      label: strings.trafficUsedLabel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CompactMetricChip(
                      value: validityValue,
                      label: strings.expiresInLabel,
                    ),
                  ),
                ],
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: _HeroActions(
                  strings: strings,
                  compact: false,
                  appUpdateSnapshot: appUpdateSnapshot,
                  isRefreshing: isRefreshing,
                  onAddLink: onAddLink,
                  onOpenSettings: onOpenSettings,
                  onRefreshSubscription: canRefresh
                      ? onRefreshSubscription
                      : null,
                  onUpdateApp: onUpdateApp,
                ),
              ),
              if (_showsUpdateBanner(appUpdateSnapshot)) ...<Widget>[
                const SizedBox(height: 12),
                AppUpdateBanner(
                  snapshot: appUpdateSnapshot,
                  onPrimaryAction: onUpdateApp,
                ),
              ],
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: badges),
              if (announcement != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  announcement,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFCBD5E1),
                    height: 1.35,
                  ),
                ),
              ],
              const Spacer(),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _Metric(
                      value: trafficValue,
                      label: strings.trafficUsedLabel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Metric(
                      value: validityValue,
                      label: strings.expiresInLabel,
                    ),
                  ),
                ],
              ),
            ],
          );

    return _GlassPanel(compact: compact, child: content);
  }
}

class _NoSubscriptionPanel extends StatelessWidget {
  const _NoSubscriptionPanel({
    required this.strings,
    required this.hasCabinetSession,
    required this.appUpdateSnapshot,
    required this.onAddLink,
    required this.onLogin,
    required this.onUpdateApp,
  });

  final AppStrings strings;
  final bool hasCabinetSession;
  final AppUpdateSnapshot appUpdateSnapshot;
  final Future<void> Function() onAddLink;
  final Future<void> Function() onLogin;
  final Future<void> Function() onUpdateApp;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _GlassPanel(
          compact: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_showsUpdateBanner(appUpdateSnapshot)) ...<Widget>[
                AppUpdateBanner(
                  snapshot: appUpdateSnapshot,
                  onPrimaryAction: onUpdateApp,
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => unawaited(onAddLink()),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    textStyle: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  icon: const Icon(Icons.add_link_rounded),
                  label: Text(strings.addFirstSubscriptionAction),
                ),
              ),
              if (!hasCabinetSession) ...<Widget>[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => unawaited(onLogin()),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(strings.authLoginAction),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroActions extends StatelessWidget {
  const _HeroActions({
    required this.strings,
    required this.compact,
    required this.appUpdateSnapshot,
    required this.isRefreshing,
    required this.onAddLink,
    required this.onOpenSettings,
    required this.onRefreshSubscription,
    required this.onUpdateApp,
  });

  final AppStrings strings;
  final bool compact;
  final AppUpdateSnapshot appUpdateSnapshot;
  final bool isRefreshing;
  final Future<void> Function() onAddLink;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function()? onRefreshSubscription;
  final Future<void> Function() onUpdateApp;

  bool get _showsUpdateAction {
    return appUpdateSnapshot.status == AppUpdateStatus.available ||
        appUpdateSnapshot.status == AppUpdateStatus.error ||
        appUpdateSnapshot.status == AppUpdateStatus.installPermissionRequired;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool useCompactActions = compact || constraints.maxWidth < 340;

        if (useCompactActions) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_showsUpdateAction) ...<Widget>[
                IconButton(
                  onPressed: () => unawaited(onUpdateApp()),
                  tooltip: strings.updateNowAction,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0x1FF59E0B),
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(
                    appUpdateSnapshot.status ==
                            AppUpdateStatus.installPermissionRequired
                        ? Icons.system_update_alt_rounded
                        : Icons.system_update_rounded,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              IconButton(
                onPressed: () => unawaited(onOpenSettings()),
                tooltip: strings.settingsTitle,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.settings_rounded),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () => unawaited(onAddLink()),
                tooltip: strings.addLinkAction,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_link_rounded),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: onRefreshSubscription == null
                    ? null
                    : () => unawaited(onRefreshSubscription!.call()),
                tooltip: strings.refreshSubscriptionAction,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  foregroundColor: Colors.white,
                ),
                icon: isRefreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_showsUpdateAction) ...<Widget>[
              FilledButton.icon(
                onPressed: () => unawaited(onUpdateApp()),
                icon: Icon(
                  appUpdateSnapshot.status ==
                          AppUpdateStatus.installPermissionRequired
                      ? Icons.system_update_alt_rounded
                      : Icons.system_update_rounded,
                ),
                label: Text(strings.updateNowAction),
              ),
              const SizedBox(width: 8),
            ],
            FilledButton.icon(
              onPressed: () => unawaited(onOpenSettings()),
              icon: const Icon(Icons.settings_rounded),
              label: Text(strings.settingsTitle),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => unawaited(onAddLink()),
              icon: const Icon(Icons.add_link_rounded),
              label: Text(strings.addLinkAction),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onRefreshSubscription == null
                  ? null
                  : () => unawaited(onRefreshSubscription!.call()),
              icon: isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(strings.refreshSubscriptionAction),
            ),
          ],
        );
      },
    );
  }
}

bool _showsUpdateBanner(AppUpdateSnapshot snapshot) {
  return snapshot.status != AppUpdateStatus.idle &&
      snapshot.status != AppUpdateStatus.checking &&
      snapshot.status != AppUpdateStatus.upToDate;
}

String _formatTrafficValue(
  ResolvedSubscriptionInfo? info,
  CabinetSubscriptionStatus? cabinetSubscriptionStatus,
  AppStrings strings,
) {
  final String usedValue = info?.usedBytes != null
      ? _formatBytes(info!.usedBytes!)
      : _formatGigabytes(cabinetSubscriptionStatus?.trafficUsedGb ?? 0);
  final int? totalBytes = info?.totalBytes;
  if (totalBytes != null) {
    if (totalBytes <= 0) {
      return '$usedValue / ${strings.unlimitedValue}';
    }
    return '$usedValue / ${_formatBytes(totalBytes)}';
  }

  final double? trafficLimitGb = cabinetSubscriptionStatus?.trafficLimitGb;
  if (trafficLimitGb != null) {
    if (trafficLimitGb <= 0) {
      return '$usedValue / ${strings.unlimitedValue}';
    }
    return '$usedValue / ${_formatGigabytes(trafficLimitGb)}';
  }

  return usedValue;
}

String _formatValidityValue(
  ResolvedSubscriptionInfo? info,
  CabinetSubscriptionStatus? cabinetSubscriptionStatus,
  AppStrings strings,
) {
  final DateTime? expireAt = info?.expireAt;
  if (expireAt == null) {
    final String? cabinetDisplay = cabinetSubscriptionStatus?.timeLeftDisplay
        ?.trim();
    if (cabinetDisplay != null && cabinetDisplay.isNotEmpty) {
      return cabinetDisplay;
    }
    final int? cabinetDaysLeft = cabinetSubscriptionStatus?.daysLeft;
    if (cabinetDaysLeft != null && cabinetDaysLeft > 0) {
      return '$cabinetDaysLeft ${strings.daysSuffix}';
    }
    return strings.subscriptionActiveLabel;
  }

  final Duration diff = expireAt.difference(DateTime.now());
  if (diff.isNegative) {
    return '0 ${strings.daysSuffix}';
  }

  final int days = diff.inDays + (diff.inHours % 24 == 0 ? 0 : 1);
  return '$days ${strings.daysSuffix}';
}

String? _announcementPreview(String? announce) {
  final String normalized = (announce ?? '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String _formatConnectionDuration(Duration? duration) {
  if (duration == null) {
    return '00:00';
  }

  final int hours = duration.inHours;
  final int minutes = duration.inMinutes.remainder(60);
  final int seconds = duration.inSeconds.remainder(60);

  String twoDigits(int value) => value.toString().padLeft(2, '0');

  if (hours > 0) {
    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  return '${twoDigits(minutes)}:${twoDigits(seconds)}';
}

String _formatBytes(int bytes) {
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  final String formatted = value >= 100 || unitIndex == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$formatted ${units[unitIndex]}';
}

String _formatGigabytes(double value) {
  final int fractionDigits = value % 1 == 0 ? 0 : 1;
  return '${value.toStringAsFixed(fractionDigits)} GB';
}

class _ServerSelectionPanel extends StatelessWidget {
  const _ServerSelectionPanel({
    required this.strings,
    required this.resolvedImport,
    required this.groups,
    required this.visibleProfiles,
    required this.showGroupsAsPrimaryList,
    required this.selectedGroupIndex,
    required this.selectedIndex,
    required this.latencyProbe,
    required this.error,
    required this.isResolving,
    required this.onSelectGroup,
    required this.onSelectServer,
    required this.onRefreshLatency,
  });

  final AppStrings strings;
  final ResolvedImportLink? resolvedImport;
  final List<ResolvedProfileGroup> groups;
  final List<ResolvedProfileLink> visibleProfiles;
  final bool showGroupsAsPrimaryList;
  final int selectedGroupIndex;
  final int selectedIndex;
  final ServerLatencyProbe latencyProbe;
  final ImportLinkError? error;
  final bool isResolving;
  final ValueChanged<int> onSelectGroup;
  final ValueChanged<int> onSelectServer;
  final Future<void> Function() onRefreshLatency;

  @override
  Widget build(BuildContext context) {
    final List<ResolvedProfileLink> profiles = visibleProfiles;
    final int visibleCount = showGroupsAsPrimaryList
        ? groups.length
        : profiles.length;

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      showGroupsAsPrimaryList
                          ? strings.groupsTitle
                          : strings.serversTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      showGroupsAsPrimaryList
                          ? strings.groupsCount(visibleCount)
                          : strings.serversCount(
                              visibleCount,
                              total: resolvedImport?.profiles.length,
                            ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: visibleCount == 0 || isResolving
                    ? null
                    : onRefreshLatency,
                tooltip: strings.pingRefreshTooltip,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  foregroundColor: const Color(0xFFCBD5E1),
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.03),
                  disabledForegroundColor: const Color(0xFF64748B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                icon: const Icon(Icons.network_ping_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (groups.isNotEmpty && !showGroupsAsPrimaryList) ...<Widget>[
            SizedBox(
              height: 38,
              child: ScrollConfiguration(
                behavior: const _SmoothScrollBehavior(),
                child: StretchingOverscrollIndicator(
                  axisDirection: AxisDirection.right,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final ResolvedProfileGroup group = groups[index];
                      final bool selected = index == selectedGroupIndex;
                      return RepaintBoundary(
                        child: _GroupChip(
                          title: group.name,
                          count: group.profiles.length,
                          selected: selected,
                          onTap: () => onSelectGroup(index),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (isResolving)
            const Expanded(
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
            )
          else if (error != null)
            Expanded(
              child: _EmptyState(
                title: strings.noServersTitle,
                body: strings.parseError(error!),
              ),
            )
          else if (showGroupsAsPrimaryList && groups.isEmpty)
            Expanded(
              child: _EmptyState(
                title: strings.noServersTitle,
                body: strings.noServersBody,
              ),
            )
          else if (!showGroupsAsPrimaryList && profiles.isEmpty)
            Expanded(
              child: _EmptyState(
                title: strings.noServersTitle,
                body: strings.noServersBody,
              ),
            )
          else
            Expanded(
              child: RepaintBoundary(
                child: ScrollConfiguration(
                  behavior: const _SmoothScrollBehavior(),
                  child: StretchingOverscrollIndicator(
                    axisDirection: AxisDirection.down,
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.only(bottom: 32),
                      cacheExtent: 900,
                      itemCount: showGroupsAsPrimaryList
                          ? groups.length
                          : profiles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (BuildContext context, int index) {
                        if (showGroupsAsPrimaryList) {
                          final ResolvedProfileGroup group = groups[index];
                          final ServerLatencySnapshot latency =
                              group.profiles.isEmpty
                              ? ServerLatencySnapshot.unknownState
                              : _bestLatencyForProfiles(group.profiles);
                          return RepaintBoundary(
                            child: _GroupCard(
                              title: group.name,
                              profilesCount: group.profiles.length,
                              latency: latency,
                              strings: strings,
                              selected: index == selectedGroupIndex,
                              onTap: () => onSelectGroup(index),
                            ),
                          );
                        }

                        final ResolvedProfileLink profileLink = profiles[index];
                        final VlessProfile profile = profileLink.profile;
                        final ServerLatencySnapshot latency = latencyProbe
                            .snapshotFor(profileLink.resolvedLink);
                        final bool selected = index == selectedIndex;

                        return RepaintBoundary(
                          child: _ServerCard(
                            profile: profile,
                            latency: latency,
                            strings: strings,
                            selected: selected,
                            onTap: () => onSelectServer(index),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  ServerLatencySnapshot _bestLatencyForProfiles(
    List<ResolvedProfileLink> profiles,
  ) {
    ServerLatencySnapshot? best;
    for (final ResolvedProfileLink profile in profiles) {
      final ServerLatencySnapshot current = latencyProbe.snapshotFor(
        profile.resolvedLink,
      );
      if (best == null) {
        best = current;
        continue;
      }

      if (current.pingMs != null &&
          (best.pingMs == null || current.pingMs! < best.pingMs!)) {
        best = current;
      }
    }
    return best ?? ServerLatencySnapshot.unknownState;
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.profile,
    required this.latency,
    required this.strings,
    required this.selected,
    required this.onTap,
  });

  final VlessProfile profile;
  final ServerLatencySnapshot latency;
  final AppStrings strings;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = _latencyColor(latency.state);
    final String title = profile.remark ?? strings.unlabeledValue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0x302DD4BF), Color(0x12111B2E)],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0x16172234), Color(0x0B0F172A)],
                  ),
            border: Border.all(
              color: selected
                  ? const Color(0xCC5EEAD4)
                  : Colors.white.withValues(alpha: 0.075),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x2614B8A6),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0x1F5EEAD4)
                      : accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: selected
                        ? const Color(0x445EEAD4)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Icon(
                  latency.state == ServerLatencyState.online
                      ? Icons.hub_rounded
                      : Icons.cloud_off_rounded,
                  color: selected ? const Color(0xFF5EEAD4) : accent,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.security.toUpperCase()} • ${profile.transport.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    strings.latencyValue(latency),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StatusDotLabel(
                    label: strings.latencyState(latency),
                    color: accent,
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

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.title,
    required this.profilesCount,
    required this.latency,
    required this.strings,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final int profilesCount;
  final ServerLatencySnapshot latency;
  final AppStrings strings;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = _latencyColor(latency.state);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0x332DD4BF), Color(0x12111B2E)],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0x15172234), Color(0x0A0F172A)],
                  ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? const Color(0xCC5EEAD4)
                  : Colors.white.withValues(alpha: 0.075),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x2414B8A6),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0x1F5EEAD4)
                      : accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? const Color(0x445EEAD4)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Icon(
                  Icons.hub_rounded,
                  color: selected ? const Color(0xFF5EEAD4) : accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$profilesCount профилей',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    strings.latencyValue(latency),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StatusDotLabel(
                    label: strings.latencyState(latency),
                    color: selected ? const Color(0xFF5EEAD4) : accent,
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

class _StatusDotLabel extends StatelessWidget {
  const _StatusDotLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _StartupLoadingState extends StatelessWidget {
  const _StartupLoadingState({this.message = 'Загружаем подписку'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(strokeWidth: 2.2),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.hub_outlined,
                size: 36,
                color: Color(0xFF7DD3FC),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFCBD5E1),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFF020617),
            Color(0xFF0F172A),
            Color(0xFF132238),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -100,
            right: -30,
            child: _Glow(size: 220, color: Color(0x5514B8A6)),
          ),
          Positioned(
            bottom: -80,
            left: -40,
            child: _Glow(size: 180, color: Color(0x4038BDF8)),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: <Color>[color, Colors.transparent]),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, this.compact = false});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Widget panel = Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xCC0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: RepaintBoundary(child: child),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: compact
          ? panel
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: panel,
            ),
    );
  }
}

class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return StretchingOverscrollIndicator(
      axisDirection: details.direction,
      child: child,
    );
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.accent});

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class _CompactMetricChip extends StatelessWidget {
  const _CompactMetricChip({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.title,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0x242DD4BF)
              : Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? const Color(0xFF2DD4BF)
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF0F2F35)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected
                      ? const Color(0xFF5EEAD4)
                      : const Color(0xFFCBD5E1),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({
    required this.strings,
    required this.vpnState,
    required this.selectedConnectionActive,
    required this.connectionDuration,
    required this.onPrimaryAction,
    this.compact = false,
  });

  final AppStrings strings;
  final VpnConnectionState vpnState;
  final bool selectedConnectionActive;
  final Duration? connectionDuration;
  final Future<void> Function() onPrimaryAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final String? timerValue = vpnState == VpnConnectionState.connected
        ? _formatConnectionDuration(connectionDuration)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!compact) ...<Widget>[
          Text(
            strings.serverMenuTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onPrimaryAction,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 14 : 16,
                vertical: compact ? 10 : 14,
              ),
              textStyle: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(compact ? 18 : 22),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  _statusActionIcon(
                    vpnState,
                    selectedConnectionActive: selectedConnectionActive,
                  ),
                  size: compact ? 18 : 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.primaryAction(
                      vpnState,
                      selectedConnectionActive: selectedConnectionActive,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (timerValue != null) ...<Widget>[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      timerValue,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

IconData _statusActionIcon(
  VpnConnectionState state, {
  required bool selectedConnectionActive,
}) {
  switch (state) {
    case VpnConnectionState.connected:
      if (!selectedConnectionActive) {
        return Icons.swap_horiz_rounded;
      }
      return Icons.stop_circle_outlined;
    case VpnConnectionState.disconnecting:
      return Icons.stop_circle_outlined;
    case VpnConnectionState.connecting:
      return Icons.sync_rounded;
    case VpnConnectionState.error:
    case VpnConnectionState.idle:
      return Icons.play_circle_fill_rounded;
  }
}

Color _latencyColor(ServerLatencyState state) {
  switch (state) {
    case ServerLatencyState.online:
      return const Color(0xFF22C55E);
    case ServerLatencyState.probing:
      return const Color(0xFFF59E0B);
    case ServerLatencyState.offline:
      return const Color(0xFFEF4444);
    case ServerLatencyState.unsupported:
      return const Color(0xFF38BDF8);
    case ServerLatencyState.unknown:
      return const Color(0xFF94A3B8);
  }
}
