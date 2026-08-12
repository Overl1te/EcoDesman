class AdminOverview {
  const AdminOverview({
    required this.postsCount,
    required this.publishedPostsCount,
    required this.draftPostsCount,
    required this.mapPointsCount,
    required this.activeMapPointsCount,
    required this.hiddenMapPointsCount,
    required this.usersCount,
    required this.bannedUsersCount,
    required this.adminsCount,
  });

  final int postsCount;
  final int publishedPostsCount;
  final int draftPostsCount;
  final int mapPointsCount;
  final int activeMapPointsCount;
  final int hiddenMapPointsCount;
  final int usersCount;
  final int bannedUsersCount;
  final int adminsCount;

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    return AdminOverview(
      postsCount: (json["posts_count"] as num?)?.toInt() ?? 0,
      publishedPostsCount: (json["published_posts_count"] as num?)?.toInt() ?? 0,
      draftPostsCount: (json["draft_posts_count"] as num?)?.toInt() ?? 0,
      mapPointsCount: (json["map_points_count"] as num?)?.toInt() ?? 0,
      activeMapPointsCount: (json["active_map_points_count"] as num?)?.toInt() ?? 0,
      hiddenMapPointsCount: (json["hidden_map_points_count"] as num?)?.toInt() ?? 0,
      usersCount: (json["users_count"] as num?)?.toInt() ?? 0,
      bannedUsersCount: (json["banned_users_count"] as num?)?.toInt() ?? 0,
      adminsCount: (json["admins_count"] as num?)?.toInt() ?? 0,
    );
  }
}
