import "user_stats.dart";

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.role,
    required this.statusText,
    required this.bio,
    required this.city,
    required this.websiteUrl,
    required this.telegramUrl,
    required this.vkUrl,
    required this.instagramUrl,
    required this.warningCount,
    required this.isBanned,
    required this.isActive,
    required this.isSuperuser,
    required this.canAccessAdmin,
    required this.canAccessSupport,
    required this.dateJoined,
    required this.lastLogin,
    required this.stats,
  });

  final int id;
  final String name;
  final String username;
  final String email;
  final String? phone;
  final String avatarUrl;
  final String role;
  final String statusText;
  final String bio;
  final String city;
  final String websiteUrl;
  final String telegramUrl;
  final String vkUrl;
  final String instagramUrl;
  final int warningCount;
  final bool isBanned;
  final bool isActive;
  final bool isSuperuser;
  final bool canAccessAdmin;
  final bool canAccessSupport;
  final DateTime? dateJoined;
  final DateTime? lastLogin;
  final UserStats stats;

  String get displayName => name.isNotEmpty ? name : username;

  bool get isAdmin => canAccessAdmin || role == "admin";

  bool get isSupport => canAccessSupport || role == "support";

  bool get isModerator => role == "moderator";

  AppUser copyWith({
    String? name,
    String? username,
    String? email,
    String? phone,
    String? avatarUrl,
    String? role,
    String? statusText,
    String? bio,
    String? city,
    String? websiteUrl,
    String? telegramUrl,
    String? vkUrl,
    String? instagramUrl,
    int? warningCount,
    bool? isBanned,
    bool? isActive,
    bool? isSuperuser,
    bool? canAccessAdmin,
    bool? canAccessSupport,
    DateTime? dateJoined,
    DateTime? lastLogin,
    UserStats? stats,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      statusText: statusText ?? this.statusText,
      bio: bio ?? this.bio,
      city: city ?? this.city,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      telegramUrl: telegramUrl ?? this.telegramUrl,
      vkUrl: vkUrl ?? this.vkUrl,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      warningCount: warningCount ?? this.warningCount,
      isBanned: isBanned ?? this.isBanned,
      isActive: isActive ?? this.isActive,
      isSuperuser: isSuperuser ?? this.isSuperuser,
      canAccessAdmin: canAccessAdmin ?? this.canAccessAdmin,
      canAccessSupport: canAccessSupport ?? this.canAccessSupport,
      dateJoined: dateJoined ?? this.dateJoined,
      lastLogin: lastLogin ?? this.lastLogin,
      stats: stats ?? this.stats,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json["id"] as int,
      name: json["name"] as String? ?? "",
      username: json["username"] as String? ?? "",
      email: json["email"] as String? ?? "",
      phone: json["phone"] as String?,
      avatarUrl: json["avatar_url"] as String? ?? "",
      role: json["role"] as String? ?? "user",
      statusText: json["status_text"] as String? ?? "",
      bio: json["bio"] as String? ?? "",
      city: json["city"] as String? ?? "",
      websiteUrl: json["website_url"] as String? ?? "",
      telegramUrl: json["telegram_url"] as String? ?? "",
      vkUrl: json["vk_url"] as String? ?? "",
      instagramUrl: json["instagram_url"] as String? ?? "",
      warningCount: json["warning_count"] as int? ?? 0,
      isBanned: json["is_banned"] as bool? ?? false,
      isActive: json["is_active"] as bool? ?? true,
      isSuperuser: json["is_superuser"] as bool? ?? false,
      canAccessAdmin: json["can_access_admin"] as bool? ?? false,
      canAccessSupport: json["can_access_support"] as bool? ?? false,
      dateJoined: _parseDateTime(json["date_joined"]),
      lastLogin: _parseDateTime(json["last_login"]),
      stats: UserStats.fromJson(
        Map<String, dynamic>.from(
          json["stats"] as Map? ?? const <String, dynamic>{},
        ),
      ),
    );
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
