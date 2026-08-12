import "eco_map_category.dart";
import "eco_map_point_image.dart";
import "eco_map_point_review.dart";

class EcoMapPointDetail {
  const EcoMapPointDetail({
    required this.id,
    required this.slug,
    required this.title,
    required this.shortDescription,
    required this.description,
    required this.address,
    required this.workingHours,
    required this.latitude,
    required this.longitude,
    required this.markerColor,
    required this.categories,
    required this.primaryCategory,
    required this.images,
    required this.reviews,
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
  final String markerColor;
  final List<EcoMapCategory> categories;
  final EcoMapCategory? primaryCategory;
  final List<EcoMapPointImage> images;
  final List<EcoMapPointReview> reviews;

  factory EcoMapPointDetail.fromJson(Map<String, dynamic> json) {
    final rawCategories = json["categories"] as List<dynamic>? ?? const [];
    final rawPrimaryCategory = json["primary_category"];
    final rawImages = json["images"] as List<dynamic>? ?? const [];
    final rawReviews = json["reviews"] as List<dynamic>? ?? const [];

    return EcoMapPointDetail(
      id: json["id"] as int,
      slug: json["slug"] as String? ?? "",
      title: json["title"] as String? ?? "",
      shortDescription: json["short_description"] as String? ?? "",
      description: json["description"] as String? ?? "",
      address: json["address"] as String? ?? "",
      workingHours: json["working_hours"] as String? ?? "",
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
      images: rawImages
          .map(
            (item) => EcoMapPointImage.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      reviews: rawReviews
          .map(
            (item) => EcoMapPointReview.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}
