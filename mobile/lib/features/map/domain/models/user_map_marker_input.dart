class UserMapMarkerInput {
  const UserMapMarkerInput({
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.isPublic,
    required this.media,
  });

  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final bool isPublic;
  final List<UserMapMarkerMediaInput> media;

  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "description": description,
      "latitude": latitude,
      "longitude": longitude,
      "is_public": isPublic,
      "media": media.map((item) => item.toJson()).toList(),
    };
  }
}

class UserMapMarkerMediaInput {
  const UserMapMarkerMediaInput({
    required this.mediaUrl,
    required this.mediaType,
  });

  final String mediaUrl;
  final String mediaType;

  Map<String, dynamic> toJson() {
    return {"media_url": mediaUrl, "media_type": mediaType};
  }
}
