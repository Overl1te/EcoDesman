import "feed_post.dart";

class PaginatedPosts {
  const PaginatedPosts({
    required this.items,
    required this.nextPage,
    required this.totalCount,
  });

  final List<FeedPost> items;
  final int? nextPage;
  final int totalCount;

  bool get hasMore => nextPage != null;

  factory PaginatedPosts.fromJson(Map<String, dynamic> json) {
    final nextUrl = json["next"] as String?;
    final nextPage = nextUrl == null
        ? null
        : int.tryParse(Uri.parse(nextUrl).queryParameters["page"] ?? "");

    return PaginatedPosts(
      items: (json["results"] as List<dynamic>? ?? [])
          .map(
            (item) => FeedPost.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      nextPage: nextPage,
      totalCount: json["count"] as int? ?? 0,
    );
  }
}
