import "post_author.dart";

class FeedPost {
  const FeedPost({
    required this.id,
    required this.slug,
    required this.title,
    required this.body,
    required this.previewText,
    required this.kind,
    required this.publishedAt,
    required this.isPublished,
    required this.author,
    required this.previewImageUrl,
    required this.likesCount,
    required this.commentsCount,
    required this.favoritesCount,
    required this.viewCount,
    required this.isLiked,
    required this.isFavorited,
    required this.hasImages,
    required this.isOwner,
    required this.canEdit,
    required this.eventDate,
    required this.eventStartsAt,
    required this.eventEndsAt,
    required this.eventLocation,
    required this.isEventCancelled,
    required this.eventCancelledAt,
  });

  final int id;
  final String slug;
  final String title;
  final String body;
  final String previewText;
  final String kind;
  final DateTime publishedAt;
  final bool isPublished;
  final PostAuthor author;
  final String? previewImageUrl;
  final int likesCount;
  final int commentsCount;
  final int favoritesCount;
  final int viewCount;
  final bool isLiked;
  final bool isFavorited;
  final bool hasImages;
  final bool isOwner;
  final bool canEdit;
  final DateTime? eventDate;
  final DateTime? eventStartsAt;
  final DateTime? eventEndsAt;
  final String eventLocation;
  final bool isEventCancelled;
  final DateTime? eventCancelledAt;

  bool get isEvent => kind == "event";

  FeedPost copyWith({
    String? slug,
    String? title,
    String? body,
    String? previewText,
    String? kind,
    DateTime? publishedAt,
    bool? isPublished,
    PostAuthor? author,
    String? previewImageUrl,
    int? likesCount,
    int? commentsCount,
    int? favoritesCount,
    int? viewCount,
    bool? isLiked,
    bool? isFavorited,
    bool? hasImages,
    bool? isOwner,
    bool? canEdit,
    DateTime? eventDate,
    DateTime? eventStartsAt,
    DateTime? eventEndsAt,
    String? eventLocation,
    bool? isEventCancelled,
    DateTime? eventCancelledAt,
    bool clearPreviewImage = false,
  }) {
    return FeedPost(
      id: id,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      body: body ?? this.body,
      previewText: previewText ?? this.previewText,
      kind: kind ?? this.kind,
      publishedAt: publishedAt ?? this.publishedAt,
      isPublished: isPublished ?? this.isPublished,
      author: author ?? this.author,
      previewImageUrl: clearPreviewImage
          ? null
          : previewImageUrl ?? this.previewImageUrl,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      favoritesCount: favoritesCount ?? this.favoritesCount,
      viewCount: viewCount ?? this.viewCount,
      isLiked: isLiked ?? this.isLiked,
      isFavorited: isFavorited ?? this.isFavorited,
      hasImages: hasImages ?? this.hasImages,
      isOwner: isOwner ?? this.isOwner,
      canEdit: canEdit ?? this.canEdit,
      eventDate: eventDate ?? this.eventDate,
      eventStartsAt: eventStartsAt ?? this.eventStartsAt,
      eventEndsAt: eventEndsAt ?? this.eventEndsAt,
      eventLocation: eventLocation ?? this.eventLocation,
      isEventCancelled: isEventCancelled ?? this.isEventCancelled,
      eventCancelledAt: eventCancelledAt ?? this.eventCancelledAt,
    );
  }

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: json["id"] as int,
      slug: json["slug"] as String? ?? "",
      title: json["title"] as String? ?? "",
      body: json["body"] as String? ?? "",
      previewText: json["preview_text"] as String? ?? "",
      kind: json["kind"] as String? ?? "",
      publishedAt: DateTime.parse(json["published_at"] as String),
      isPublished: json["is_published"] as bool? ?? true,
      author: PostAuthor.fromJson(
        Map<String, dynamic>.from(json["author"] as Map),
      ),
      previewImageUrl: json["preview_image_url"] as String?,
      likesCount: json["likes_count"] as int? ?? 0,
      commentsCount: json["comments_count"] as int? ?? 0,
      favoritesCount: json["favorites_count"] as int? ?? 0,
      viewCount: json["view_count"] as int? ?? 0,
      isLiked: json["is_liked"] as bool? ?? false,
      isFavorited: json["is_favorited"] as bool? ?? false,
      hasImages: json["has_images"] as bool? ?? false,
      isOwner: json["is_owner"] as bool? ?? false,
      canEdit: json["can_edit"] as bool? ?? false,
      eventDate: _parseDateTime(json["event_date"]),
      eventStartsAt: _parseDateTime(json["event_starts_at"]),
      eventEndsAt: _parseDateTime(json["event_ends_at"]),
      eventLocation: json["event_location"] as String? ?? "",
      isEventCancelled: json["is_event_cancelled"] as bool? ?? false,
      eventCancelledAt: _parseDateTime(json["event_cancelled_at"]),
    );
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.parse(value);
}
