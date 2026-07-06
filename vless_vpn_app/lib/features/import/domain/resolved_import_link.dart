import 'resolved_profile_link.dart';
import 'resolved_profile_group.dart';
import 'resolved_subscription_info.dart';

class ResolvedImportLink {
  const ResolvedImportLink({
    required this.sourceLink,
    required this.profiles,
    required this.groups,
    required this.isRemote,
    this.subscriptionInfo,
  });

  final String sourceLink;
  final List<ResolvedProfileLink> profiles;
  final List<ResolvedProfileGroup> groups;
  final bool isRemote;
  final ResolvedSubscriptionInfo? subscriptionInfo;
}
