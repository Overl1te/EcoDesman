class SocialAuthProvider {
  const SocialAuthProvider({
    required this.id,
    required this.label,
    required this.enabled,
    required this.authorizationUrl,
  });

  final String id;
  final String label;
  final bool enabled;
  final String authorizationUrl;

  factory SocialAuthProvider.fromJson(Map<String, dynamic> json) {
    return SocialAuthProvider(
      id: json["id"] as String? ?? "",
      label: json["label"] as String? ?? "",
      enabled: json["enabled"] as bool? ?? false,
      authorizationUrl: json["authorization_url"] as String? ?? "",
    );
  }
}
