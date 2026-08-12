class EcoMapPointImage {
  const EcoMapPointImage({
    required this.id,
    required this.imageUrl,
    required this.caption,
    required this.position,
  });

  final int id;
  final String imageUrl;
  final String caption;
  final int position;

  factory EcoMapPointImage.fromJson(Map<String, dynamic> json) {
    return EcoMapPointImage(
      id: json["id"] as int,
      imageUrl: json["image_url"] as String? ?? "",
      caption: json["caption"] as String? ?? "",
      position: json["position"] as int? ?? 0,
    );
  }
}
