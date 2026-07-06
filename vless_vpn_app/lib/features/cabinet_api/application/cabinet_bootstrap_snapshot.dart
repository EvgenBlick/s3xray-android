import '../domain/cabinet_session.dart';
import '../domain/cabinet_subscription_status.dart';
import '../domain/cabinet_user.dart';

enum CabinetBootstrapState {
  idle,
  loading,
  ready,
  unauthenticated,
  error,
}

class CabinetBootstrapSnapshot {
  const CabinetBootstrapSnapshot({
    required this.state,
    this.session,
    this.user,
    this.subscriptionStatus,
    this.importLink,
    this.errorMessage,
    this.activatedTrialDuringBootstrap = false,
  });

  final CabinetBootstrapState state;
  final CabinetSession? session;
  final CabinetUser? user;
  final CabinetSubscriptionStatus? subscriptionStatus;
  final String? importLink;
  final String? errorMessage;
  final bool activatedTrialDuringBootstrap;

  bool get isLoading => state == CabinetBootstrapState.loading;

  CabinetBootstrapSnapshot copyWith({
    CabinetBootstrapState? state,
    CabinetSession? session,
    CabinetUser? user,
    CabinetSubscriptionStatus? subscriptionStatus,
    String? importLink,
    String? errorMessage,
    bool? activatedTrialDuringBootstrap,
  }) {
    return CabinetBootstrapSnapshot(
      state: state ?? this.state,
      session: session ?? this.session,
      user: user ?? this.user,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      importLink: importLink ?? this.importLink,
      errorMessage: errorMessage ?? this.errorMessage,
      activatedTrialDuringBootstrap:
          activatedTrialDuringBootstrap ?? this.activatedTrialDuringBootstrap,
    );
  }

  static const CabinetBootstrapSnapshot initial = CabinetBootstrapSnapshot(
    state: CabinetBootstrapState.idle,
  );
}
