class LikeState {
  const LikeState({required this.likesCount, required this.isLiked});

  final int likesCount;
  final bool isLiked;

  factory LikeState.fromJson(Map<String, dynamic> json) {
    return LikeState(
      likesCount: json["likes_count"] as int? ?? 0,
      isLiked: json["is_liked"] as bool? ?? false,
    );
  }
}
