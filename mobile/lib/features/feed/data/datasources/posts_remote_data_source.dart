import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/network/api_client.dart";
import "../../../events/domain/models/event_calendar_month.dart";
import "../../domain/models/favorite_state.dart";
import "../../domain/models/like_state.dart";
import "../../domain/models/paginated_posts.dart";
import "../../domain/models/post_comment.dart";
import "../../domain/models/post_details.dart";
import "../../domain/models/posts_query.dart";
import "../../domain/models/post_write_input.dart";

final postsRemoteDataSourceProvider = Provider<PostsRemoteDataSource>((ref) {
  return PostsRemoteDataSource(ref.watch(apiClientProvider));
});

class PostsRemoteDataSource {
  PostsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<PaginatedPosts> fetchPosts({
    PostsQuery query = const PostsQuery(),
    int page = 1,
  }) async {
    final queryParameters = <String, dynamic>{
      "page": page,
      "ordering": query.ordering,
      "has_images": query.hasImages,
      "favorites_only": query.favoritesOnly,
    };
    if (query.authorId != null) {
      queryParameters["author_id"] = query.authorId;
    }
    if (query.search != null && query.search!.trim().isNotEmpty) {
      queryParameters["search"] = query.search!.trim();
    }
    if (query.kind != null && query.kind!.trim().isNotEmpty) {
      queryParameters["kind"] = query.kind;
    }
    if (query.eventScope.trim().isNotEmpty && query.eventScope != "all") {
      queryParameters["event_scope"] = query.eventScope;
    }

    final response = await _dio.get("/posts", queryParameters: queryParameters);

    return PaginatedPosts.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<EventCalendarMonth> fetchEventCalendar({
    required int year,
    required int month,
  }) async {
    final response = await _dio.get(
      "/posts/calendar",
      queryParameters: {"year": year, "month": month},
    );
    return EventCalendarMonth.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<PostDetails> fetchPostDetails(int postId) async {
    final response = await _dio.get("/posts/$postId");

    return PostDetails.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<PostDetails> fetchPostDetailsBySlug({
    required String authorUsername,
    required String postSlug,
  }) async {
    final response = await _dio.get("/posts/by-slug/$authorUsername/$postSlug");

    return PostDetails.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<LikeState> likePost(int postId) async {
    final response = await _dio.post("/posts/$postId/like");
    return LikeState.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<LikeState> unlikePost(int postId) async {
    final response = await _dio.delete("/posts/$postId/like");
    return LikeState.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<FavoriteState> favoritePost(int postId) async {
    final response = await _dio.post("/posts/$postId/favorite");
    return FavoriteState.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<FavoriteState> unfavoritePost(int postId) async {
    final response = await _dio.delete("/posts/$postId/favorite");
    return FavoriteState.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<PostComment> addComment({
    required int postId,
    required String body,
  }) async {
    final response = await _dio.post(
      "/posts/$postId/comments",
      data: {"body": body},
    );
    return PostComment.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<PostComment> updateComment({
    required int postId,
    required int commentId,
    required String body,
  }) async {
    final response = await _dio.patch(
      "/posts/$postId/comments/$commentId",
      data: {"body": body},
    );
    return PostComment.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> deleteComment({required int postId, required int commentId}) {
    return _dio.delete("/posts/$postId/comments/$commentId");
  }

  Future<PostDetails> createPost(PostWriteInput input) async {
    final response = await _dio.post("/posts", data: _writePayload(input));
    return PostDetails.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<PostDetails> updatePost({
    required int postId,
    required PostWriteInput input,
  }) async {
    final response = await _dio.patch(
      "/posts/$postId",
      data: _writePayload(input),
    );
    return PostDetails.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<PostDetails> setEventCancelled({
    required int postId,
    required bool isCancelled,
  }) async {
    final response = isCancelled
        ? await _dio.post("/posts/$postId/cancel")
        : await _dio.delete("/posts/$postId/cancel");
    return PostDetails.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> deletePost(int postId) {
    return _dio.delete("/posts/$postId");
  }

  Map<String, dynamic> _writePayload(PostWriteInput input) {
    return {
      "title": input.title,
      "body": input.body,
      "kind": input.kind,
      "is_published": input.isPublished,
      "image_urls": input.imageUrls,
      "event_date": input.eventDate?.toIso8601String().split("T").first,
      "event_starts_at": input.eventStartsAt?.toIso8601String(),
      "event_ends_at": input.eventEndsAt?.toIso8601String(),
      "event_location": input.eventLocation,
    };
  }
}
