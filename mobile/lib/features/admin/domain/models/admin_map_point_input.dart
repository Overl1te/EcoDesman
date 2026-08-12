class AdminMapPointInput {
  const AdminMapPointInput({
    required this.slug,
    required this.title,
    required this.shortDescription,
    required this.description,
    required this.address,
    required this.workingHours,
    required this.latitude,
    required this.longitude,
    required this.isActive,
    required this.sortOrder,
    required this.categoryIds,
    required this.imageUrls,
  });

  final String slug;
  final String title;
  final String shortDescription;
  final String description;
  final String address;
  final String workingHours;
  final double latitude;
  final double longitude;
  final bool isActive;
  final int sortOrder;
  final List<int> categoryIds;
  final List<String> imageUrls;

  Map<String, dynamic> toJson() {
    return {
      "slug": slug,
      "title": title,
      "short_description": shortDescription,
      "description": description,
      "address": address,
      "working_hours": workingHours,
      "latitude": latitude,
      "longitude": longitude,
      "is_active": isActive,
      "sort_order": sortOrder,
      "category_ids": categoryIds,
      "image_urls": imageUrls,
    };
  }
}
