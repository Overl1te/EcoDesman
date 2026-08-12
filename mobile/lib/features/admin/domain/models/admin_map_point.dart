import "../../../map/domain/models/eco_map_category.dart";
import "../../../map/domain/models/eco_map_point_image.dart";

class AdminMapPoint {
  const AdminMapPoint({
    required this.id,
    required this.slug,
    required this.title,
    required this.shortDescription,
    required this.description,
    required this.address,
    required this.workingHours,
    required this.latitude,
    required this.longitude,
    required this.categories,
    required this.primaryCategory,
    required this.images,
    required this.isActive,
    required this.sortOrder,
    required this.reviewCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String slug;
  final String title;
  final String shortDescription;
  final String description;
  final String address;
  final String workingHours;
  final double latitude;
  final double longitude;
  final List<EcoMapCategory> categories;
  final EcoMapCategory? primaryCategory;
  final List<EcoMapPointImage> images;
  final bool isActive;
  final int sortOrder;
  final int reviewCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AdminMapPoint.fromJson(Map<String, dynamic> json) {
    final rawCategories = json["categories"] as List<dynamic>? ?? const [];
    final rawPrimaryCategory = json["primary_category"];
    final rawImages = json["images"] as List<dynamic>? ?? const [];

    return AdminMapPoint(
      id: json["id"] as int,
      slug: json["slug"] as String? ?? "",
      title: json["title"] as String? ?? "",
      shortDescription: json["short_description"] as String? ?? "",
      description: json["description"] as String? ?? "",
      address: json["address"] as String? ?? "",
      workingHours: json["working_hours"] as String? ?? "",
      latitude: (json["latitude"] as num?)?.toDouble() ?? 0,
      longitude: (json["longitude"] as num?)?.toDouble() ?? 0,
      categories: rawCategories
          .map(
            (item) =>
                EcoMapCategory.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      primaryCategory: rawPrimaryCategory is Map
          ? EcoMapCategory.fromJson(Map<String, dynamic>.from(rawPrimaryCategory))
          : null,
      images: rawImages
          .map(
            (item) => EcoMapPointImage.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      isActive: json["is_active"] as bool? ?? true,
      sortOrder: (json["sort_order"] as num?)?.toInt() ?? 0,
      reviewCount: (json["review_count"] as num?)?.toInt() ?? 0,
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
