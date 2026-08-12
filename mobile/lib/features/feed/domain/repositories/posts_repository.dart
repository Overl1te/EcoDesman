import "../../../events/domain/models/event_calendar_month.dart";
import "../models/favorite_state.dart";
import "../models/like_state.dart";
import "../models/paginated_posts.dart";
import "../models/post_comment.dart";
import "../models/post_details.dart";
import "../models/posts_query.dart";
import "../models/post_write_input.dart";

abstract class PostsRepository {
  Future<PaginatedPosts> fetchPosts({
    PostsQuery query = const PostsQuery(),
    int page = 1,
  });

  Future<EventCalendarMonth> fetchEventCalendar({
    required int year,
    required int month,
  });

  Future<PostDetails> fetchPostDetails(int postId);

  Future<PostDetails> fetchPostDetailsBySlug({
    required String authorUsername,
    required String postSlug,
  });

  Future<LikeState> likePost(int postId);

  Future<LikeState> unlikePost(int postId);

  Future<FavoriteState> favoritePost(int postId);

  Future<FavoriteState> unfavoritePost(int postId);

  Future<PostComment> addComment({required int postId, required String body});

  Future<PostComment> updateComment({
    required int postId,
    required int commentId,
    required String body,
  });

  Future<void> deleteComment({required int postId, required int commentId});

  Future<PostDetails> createPost(PostWriteInput input);

  Future<PostDetails> updatePost({
    required int postId,
    required PostWriteInput input,
  });

  Future<PostDetails> setEventCancelled({
    required int postId,
    required bool isCancelled,
  });

  Future<void> deletePost(int postId);
}
