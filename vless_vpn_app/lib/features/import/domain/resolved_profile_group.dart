import 'resolved_profile_link.dart';

class ResolvedProfileGroup {
  const ResolvedProfileGroup({
    required this.name,
    required this.profiles,
    this.runtimeConfig,
  });

  final String name;
  final List<ResolvedProfileLink> profiles;
  final String? runtimeConfig;
}
