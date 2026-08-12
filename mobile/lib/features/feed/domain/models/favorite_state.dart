class FavoriteState {
  const FavoriteState({
    required this.favoritesCount,
    required this.isFavorited,
  });

  final int favoritesCount;
  final bool isFavorited;

  factory FavoriteState.fromJson(Map<String, dynamic> json) {
    return FavoriteState(
      favoritesCount: json["favorites_count"] as int? ?? 0,
      isFavorited: json["is_favorited"] as bool? ?? false,
    );
  }
}
