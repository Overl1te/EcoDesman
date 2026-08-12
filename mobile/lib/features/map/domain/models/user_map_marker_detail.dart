import "user_map_marker.dart";
import "user_map_marker_comment.dart";
import "user_map_marker_media.dart";

class UserMapMarkerDetail extends UserMapMarker {
  const UserMapMarkerDetail({
    required super.id,
    required super.title,
    required super.description,
    required super.latitude,
    required super.longitude,
    required super.author,
    required super.isPublic,
    required super.isActive,
    required super.coverMediaUrl,
    required super.coverMediaType,
    required super.commentsCount,
    required super.isOwner,
    required super.createdAt,
    required super.updatedAt,
    required this.media,
    required this.comments,
  });

  final List<UserMapMarkerMedia> media;
  final List<UserMapMarkerComment> comments;

  factory UserMapMarkerDetail.fromJson(Map<String, dynamic> json) {
    final summary = UserMapMarker.fromJson(json);

    return UserMapMarkerDetail(
      id: summary.id,
      title: summary.title,
      description: summary.description,
      latitude: summary.latitude,
      longitude: summary.longitude,
      author: summary.author,
      isPublic: summary.isPublic,
      isActive: summary.isActive,
      coverMediaUrl: summary.coverMediaUrl,
      coverMediaType: summary.coverMediaType,
      commentsCount: summary.commentsCount,
      isOwner: summary.isOwner,
      createdAt: summary.createdAt,
      updatedAt: summary.updatedAt,
      media: (json["media"] as List<dynamic>? ?? const [])
          .map(
            (item) => UserMapMarkerMedia.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      comments: (json["comments"] as List<dynamic>? ?? const [])
          .map(
            (item) => UserMapMarkerComment.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}
