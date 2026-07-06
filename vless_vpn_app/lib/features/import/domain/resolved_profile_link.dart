import '../../vless/domain/vless_profile.dart';

class ResolvedProfileLink {
  const ResolvedProfileLink({
    required this.resolvedLink,
    required this.profile,
  });

  final String resolvedLink;
  final VlessProfile profile;
}
