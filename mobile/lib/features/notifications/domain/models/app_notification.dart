class NotificationActor {
  const NotificationActor({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.role,
  });

  final int id;
  final String name;
  final String avatarUrl;
  final String role;

  factory NotificationActor.fromJson(Map<String, dynamic> json) {
    return NotificationActor(
      id: json["id"] as int,
      name: json["name"] as String? ?? "",
      avatarUrl: json["avatar_url"] as String? ?? "",
      role: json["role"] as String? ?? "user",
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    required this.actor,
    required this.postId,
    required this.postSlug,
    required this.postAuthorUsername,
    required this.commentId,
    required this.supportThreadId,
    required this.reportId,
  });

  final int id;
  final String kind;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final NotificationActor actor;
  final int? postId;
  final String? postSlug;
  final String? postAuthorUsername;
  final int? commentId;
  final int? supportThreadId;
  final int? reportId;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      kind: kind,
      title: title,
      body: body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      actor: actor,
      postId: postId,
      postSlug: postSlug,
      postAuthorUsername: postAuthorUsername,
      commentId: commentId,
      supportThreadId: supportThreadId,
      reportId: reportId,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json["id"] as int,
      kind: json["kind"] as String? ?? "",
      title: json["title"] as String? ?? "",
      body: json["body"] as String? ?? "",
      isRead: json["is_read"] as bool? ?? false,
      createdAt: DateTime.parse(json["created_at"] as String),
      actor: NotificationActor.fromJson(
        Map<String, dynamic>.from(json["actor"] as Map),
      ),
      postId: json["post_id"] as int?,
      postSlug: json["post_slug"] as String?,
      postAuthorUsername: json["post_author_username"] as String?,
      commentId: json["comment_id"] as int?,
      supportThreadId: json["support_thread_id"] as int?,
      reportId: json["report_id"] as int?,
    );
  }
}
