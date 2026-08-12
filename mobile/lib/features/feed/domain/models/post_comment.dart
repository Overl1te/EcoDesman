import "post_author.dart";

class PostComment {
  const PostComment({
    required this.id,
    required this.body,
    required this.author,
    required this.createdAt,
    required this.updatedAt,
    required this.isOwner,
    required this.canEdit,
  });

  final int id;
  final String body;
  final PostAuthor author;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isOwner;
  final bool canEdit;

  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      id: json["id"] as int,
      body: json["body"] as String? ?? "",
      author: PostAuthor.fromJson(
        Map<String, dynamic>.from(json["author"] as Map),
      ),
      createdAt: DateTime.parse(json["created_at"] as String),
      updatedAt: DateTime.parse(json["updated_at"] as String),
      isOwner: json["is_owner"] as bool? ?? false,
      canEdit: json["can_edit"] as bool? ?? false,
    );
  }
}
