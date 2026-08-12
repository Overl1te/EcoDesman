import "eco_map_point_image.dart";

class EcoMapPointReview {
  const EcoMapPointReview({
    required this.id,
    required this.authorName,
    required this.rating,
    required this.body,
    required this.createdAt,
    required this.images,
    required this.isOwner,
    required this.canEdit,
  });

  final int id;
  final String authorName;
  final int rating;
  final String body;
  final DateTime createdAt;
  final List<EcoMapPointImage> images;
  final bool isOwner;
  final bool canEdit;

  factory EcoMapPointReview.fromJson(Map<String, dynamic> json) {
    return EcoMapPointReview(
      id: json["id"] as int,
      authorName: json["author_name"] as String? ?? "",
      rating: json["rating"] as int? ?? 0,
      body: json["body"] as String? ?? "",
      createdAt:
          DateTime.tryParse(json["created_at"] as String? ?? "") ??
          DateTime.fromMillisecondsSinceEpoch(0),
      images: (json["images"] as List<dynamic>? ?? const [])
          .map(
            (item) => EcoMapPointImage.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      isOwner: json["is_owner"] as bool? ?? false,
      canEdit: json["can_edit"] as bool? ?? false,
    );
  }
}
