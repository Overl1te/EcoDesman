class UserStats {
  const UserStats({
    required this.postsCount,
    required this.likesGivenCount,
    required this.likesReceivedCount,
    required this.commentsCount,
    required this.viewsReceivedCount,
  });

  const UserStats.empty()
    : postsCount = 0,
      likesGivenCount = 0,
      likesReceivedCount = 0,
      commentsCount = 0,
      viewsReceivedCount = 0;

  final int postsCount;
  final int likesGivenCount;
  final int likesReceivedCount;
  final int commentsCount;
  final int viewsReceivedCount;

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      postsCount: json["posts_count"] as int? ?? 0,
      likesGivenCount: json["likes_given_count"] as int? ?? 0,
      likesReceivedCount: json["likes_received_count"] as int? ?? 0,
      commentsCount: json["comments_count"] as int? ?? 0,
      viewsReceivedCount: json["views_received_count"] as int? ?? 0,
    );
  }
}
