import '../domain/cabinet_app_config.dart';
import '../domain/cabinet_connection_link.dart';
import '../domain/cabinet_session.dart';
import '../domain/cabinet_subscription_status.dart';
import '../domain/cabinet_trial_activation_result.dart';
import '../domain/cabinet_trial_info.dart';

abstract class CabinetSubscriptionRepository {
  Future<CabinetSubscriptionStatus> getSubscriptionStatus(CabinetSession session);

  Future<CabinetConnectionLink> getConnectionLink(CabinetSession session);

  Future<CabinetAppConfig> getAppConfig(CabinetSession session);

  Future<String?> resolveImportLink(CabinetSession session);

  Future<CabinetTrialInfo> getTrialInfo(CabinetSession session);

  Future<CabinetTrialActivationResult> activateTrial(CabinetSession session);
}
