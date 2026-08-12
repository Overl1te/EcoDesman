class PostImage {
  const PostImage({
    required this.id,
    required this.imageUrl,
    required this.position,
  });

  final int id;
  final String imageUrl;
  final int position;

  factory PostImage.fromJson(Map<String, dynamic> json) {
    return PostImage(
      id: json["id"] as int,
      imageUrl: json["image_url"] as String? ?? "",
      position: json["position"] as int? ?? 0,
    );
  }
}
