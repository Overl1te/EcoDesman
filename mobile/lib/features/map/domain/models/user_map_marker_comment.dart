import "../../../auth/domain/models/app_user.dart";

class UserMapMarkerComment {
  const UserMapMarkerComment({
    required this.id,
    required this.authorName,
    required this.author,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    required this.isOwner,
    required this.canEdit,
  });

  final int id;
  final String authorName;
  final AppUser? author;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isOwner;
  final bool canEdit;

  factory UserMapMarkerComment.fromJson(Map<String, dynamic> json) {
    final rawAuthor = json["author"];

    return UserMapMarkerComment(
      id: json["id"] as int,
      authorName: json["author_name"] as String? ?? "",
      author: rawAuthor is Map
          ? AppUser.fromJson(Map<String, dynamic>.from(rawAuthor))
          : null,
      body: json["body"] as String? ?? "",
      createdAt: _parseDateTime(json["created_at"]),
      updatedAt: _parseDateTime(json["updated_at"]),
      isOwner: json["is_owner"] as bool? ?? false,
      canEdit: json["can_edit"] as bool? ?? false,
    );
  }
}

DateTime _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
}
