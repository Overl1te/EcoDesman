class UserMapMarkerMedia {
  const UserMapMarkerMedia({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    required this.caption,
    required this.position,
  });

  final int id;
  final String mediaUrl;
  final String mediaType;
  final String caption;
  final int position;

  factory UserMapMarkerMedia.fromJson(Map<String, dynamic> json) {
    return UserMapMarkerMedia(
      id: json["id"] as int,
      mediaUrl: json["media_url"] as String? ?? "",
      mediaType: json["media_type"] as String? ?? "image",
      caption: json["caption"] as String? ?? "",
      position: (json["position"] as num?)?.toInt() ?? 0,
    );
  }
}
