import "../../../auth/domain/models/app_user.dart";

class UserMapMarker {
  const UserMapMarker({
    required this.id,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.author,
    required this.isPublic,
    required this.isActive,
    required this.coverMediaUrl,
    required this.coverMediaType,
    required this.commentsCount,
    required this.isOwner,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final AppUser? author;
  final bool isPublic;
  final bool isActive;
  final String coverMediaUrl;
  final String coverMediaType;
  final int commentsCount;
  final bool isOwner;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserMapMarker.fromJson(Map<String, dynamic> json) {
    final rawAuthor = json["author"];

    return UserMapMarker(
      id: json["id"] as int,
      title: json["title"] as String? ?? "",
      description: json["description"] as String? ?? "",
      latitude: (json["latitude"] as num?)?.toDouble() ?? 0,
      longitude: (json["longitude"] as num?)?.toDouble() ?? 0,
      author: rawAuthor is Map
          ? AppUser.fromJson(Map<String, dynamic>.from(rawAuthor))
          : null,
      isPublic: json["is_public"] as bool? ?? true,
      isActive: json["is_active"] as bool? ?? true,
      coverMediaUrl: json["cover_media_url"] as String? ?? "",
      coverMediaType: json["cover_media_type"] as String? ?? "",
      commentsCount: (json["comments_count"] as num?)?.toInt() ?? 0,
      isOwner: json["is_owner"] as bool? ?? false,
      createdAt: _parseDateTime(json["created_at"]),
      updatedAt: _parseDateTime(json["updated_at"]),
    );
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
