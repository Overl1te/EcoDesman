class PostsQuery {
  const PostsQuery({
    this.search,
    this.authorId,
    this.kind,
    this.ordering = "recent",
    this.hasImages = false,
    this.favoritesOnly = false,
    this.eventScope = "all",
  });

  final String? search;
  final int? authorId;
  final String? kind;
  final String ordering;
  final bool hasImages;
  final bool favoritesOnly;
  final String eventScope;

  PostsQuery copyWith({
    String? search,
    int? authorId,
    String? kind,
    String? ordering,
    bool? hasImages,
    bool? favoritesOnly,
    String? eventScope,
    bool clearSearch = false,
    bool clearAuthorId = false,
    bool clearKind = false,
  }) {
    return PostsQuery(
      search: clearSearch ? null : search ?? this.search,
      authorId: clearAuthorId ? null : authorId ?? this.authorId,
      kind: clearKind ? null : kind ?? this.kind,
      ordering: ordering ?? this.ordering,
      hasImages: hasImages ?? this.hasImages,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      eventScope: eventScope ?? this.eventScope,
    );
  }

  bool get isEventQuery => kind == "event";

  @override
  bool operator ==(Object other) {
    return other is PostsQuery &&
        other.search == search &&
        other.authorId == authorId &&
        other.kind == kind &&
        other.ordering == ordering &&
        other.hasImages == hasImages &&
        other.favoritesOnly == favoritesOnly &&
        other.eventScope == eventScope;
  }

  @override
  int get hashCode => Object.hash(
    search,
    authorId,
    kind,
    ordering,
    hasImages,
    favoritesOnly,
    eventScope,
  );
}
