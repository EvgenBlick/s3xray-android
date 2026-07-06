class CabinetConnectionLink {
  const CabinetConnectionLink({
    required this.subscriptionUrl,
    required this.displayLink,
    required this.happRedirectLink,
    required this.happSchemeLink,
    required this.hideLink,
  });

  final String? subscriptionUrl;
  final String? displayLink;
  final String? happRedirectLink;
  final String? happSchemeLink;
  final bool hideLink;

  factory CabinetConnectionLink.fromJson(Map<String, Object?> json) {
    return CabinetConnectionLink(
      subscriptionUrl: json['subscription_url'] as String?,
      displayLink: json['display_link'] as String?,
      happRedirectLink: json['happ_redirect_link'] as String?,
      happSchemeLink: json['happ_scheme_link'] as String?,
      hideLink: json['hide_link'] == true,
    );
  }
}
