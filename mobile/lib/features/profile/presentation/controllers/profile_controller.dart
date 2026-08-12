import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/routing/app_routes.dart";
import "../../../auth/data/repositories/auth_repository_impl.dart";
import "../../../auth/domain/models/app_user.dart";
import "../../../feed/data/repositories/posts_repository_impl.dart";
import "../../../feed/domain/models/paginated_posts.dart";
import "../../../feed/domain/models/posts_query.dart";

final publicProfileProvider =
    FutureProvider.family<AppUser, ProfileRouteTarget>((ref, target) {
      final repository = ref.watch(authRepositoryProvider);
      if (target.hasUsername) {
        return repository.fetchPublicProfileByUsername(
          target.normalizedUsername,
        );
      }
      return repository.fetchPublicProfile(target.userId!);
    });

final userPostsProvider = FutureProvider.family<PaginatedPosts, int>((
  ref,
  userId,
) {
  return ref
      .watch(postsRepositoryProvider)
      .fetchPosts(query: PostsQuery(authorId: userId));
});
