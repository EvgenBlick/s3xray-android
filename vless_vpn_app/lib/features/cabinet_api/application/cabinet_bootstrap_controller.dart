import 'package:flutter/foundation.dart';

import 'cabinet_api_exception.dart';
import 'cabinet_auth_repository.dart';
import 'cabinet_bootstrap_snapshot.dart';
import 'cabinet_subscription_repository.dart';
import '../domain/cabinet_session.dart';
import '../domain/cabinet_subscription_status.dart';
import '../domain/cabinet_trial_info.dart';

class CabinetBootstrapController extends ChangeNotifier {
  CabinetBootstrapController({
    required CabinetAuthRepository authRepository,
    required CabinetSubscriptionRepository subscriptionRepository,
  }) : _authRepository = authRepository,
       _subscriptionRepository = subscriptionRepository;

  final CabinetAuthRepository _authRepository;
  final CabinetSubscriptionRepository _subscriptionRepository;

  CabinetBootstrapSnapshot _snapshot = CabinetBootstrapSnapshot.initial;

  CabinetBootstrapSnapshot get snapshot => _snapshot;

  Future<CabinetBootstrapSnapshot> initialize() async {
    _snapshot = _snapshot.copyWith(
      state: CabinetBootstrapState.loading,
      errorMessage: null,
    );
    notifyListeners();

    CabinetSession? session;

    try {
      session = await _authRepository.bootstrapSession();
      if (session == null) {
        _snapshot = const CabinetBootstrapSnapshot(
          state: CabinetBootstrapState.unauthenticated,
        );
        notifyListeners();
        return _snapshot;
      }

      final user = await _authRepository.getCurrentUser(session);
      CabinetSubscriptionStatus subscriptionStatus = await _subscriptionRepository
          .getSubscriptionStatus(session);
      bool trialActivated = false;
      if (!subscriptionStatus.hasSubscription) {
        final CabinetTrialInfo trialInfo = await _subscriptionRepository
            .getTrialInfo(session);
        if (trialInfo.isAvailable) {
          await _subscriptionRepository.activateTrial(session);
          subscriptionStatus = await _subscriptionRepository
              .getSubscriptionStatus(session);
          trialActivated = true;
        }
      }
      final importLink = await _subscriptionRepository.resolveImportLink(session);

      _snapshot = CabinetBootstrapSnapshot(
        state: CabinetBootstrapState.ready,
        session: session,
        user: user,
        subscriptionStatus: subscriptionStatus,
        importLink: importLink,
        activatedTrialDuringBootstrap: trialActivated,
      );
    } on CabinetApiException catch (error) {
      _snapshot = CabinetBootstrapSnapshot(
        state: CabinetBootstrapState.error,
        session: session,
        errorMessage: error.message,
      );
    }

    notifyListeners();
    return _snapshot;
  }
}
