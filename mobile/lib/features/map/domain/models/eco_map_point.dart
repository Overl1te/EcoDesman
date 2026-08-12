import "eco_map_category.dart";

class EcoMapPoint {
  const EcoMapPoint({
    required this.id,
    required this.slug,
    required this.title,
    required this.shortDescription,
    required this.latitude,
    required this.longitude,
    required this.markerColor,
    required this.categories,
    required this.primaryCategory,
    required this.coverImageUrl,
  });

  final int id;
  final String slug;
  final String title;
  final String shortDescription;
  final double latitude;
  final double longitude;
  final String markerColor;
  final List<EcoMapCategory> categories;
  final EcoMapCategory? primaryCategory;
  final String coverImageUrl;

  factory EcoMapPoint.fromJson(Map<String, dynamic> json) {
    final rawCategories = json["categories"] as List<dynamic>? ?? const [];
    final rawPrimaryCategory = json["primary_category"];

    return EcoMapPoint(
      id: json["id"] as int,
      slug: json["slug"] as String? ?? "",
      title: json["title"] as String? ?? "",
      shortDescription: json["short_description"] as String? ?? "",
      latitude: (json["latitude"] as num?)?.toDouble() ?? 0,
      longitude: (json["longitude"] as num?)?.toDouble() ?? 0,
      markerColor: json["marker_color"] as String? ?? "",
      categories: rawCategories
          .map(
            (item) =>
                EcoMapCategory.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      primaryCategory: rawPrimaryCategory is Map
          ? EcoMapCategory.fromJson(
              Map<String, dynamic>.from(rawPrimaryCategory),
            )
          : null,
      coverImageUrl: json["cover_image_url"] as String? ?? "",
    );
  }
}
