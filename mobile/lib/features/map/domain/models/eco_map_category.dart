class EcoMapCategory {
  const EcoMapCategory({
    required this.id,
    required this.slug,
    required this.title,
    required this.sortOrder,
    required this.color,
  });

  final int id;
  final String slug;
  final String title;
  final int sortOrder;
  final String color;

  factory EcoMapCategory.fromJson(Map<String, dynamic> json) {
    return EcoMapCategory(
      id: json["id"] as int,
      slug: json["slug"] as String? ?? "",
      title: json["title"] as String? ?? "",
      sortOrder: (json["sort_order"] as num?)?.toInt() ?? 0,
      color: json["color"] as String? ?? "#56616F",
    );
  }
}
