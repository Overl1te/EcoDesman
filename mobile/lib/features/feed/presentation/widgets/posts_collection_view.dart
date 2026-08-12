import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../../core/routing/app_routes.dart";
import "../../../../shared/widgets/app_empty_state.dart";
import "../../../../shared/widgets/app_error_state.dart";
import "../../domain/models/feed_post.dart";
import "../controllers/feed_controller.dart";
import "post_card.dart";

class PostsCollectionView extends StatelessWidget {
  const PostsCollectionView({
    super.key,
    required this.state,
    required this.scrollController,
    required this.onRefresh,
    required this.onRetry,
    required this.onLikeTap,
    required this.onFavoriteTap,
    required this.errorMessageBuilder,
    required this.emptyTitle,
    required this.emptyMessage,
    this.header,
    this.errorTitle = "Не удалось загрузить публикации",
  });

  final AsyncValue<FeedState> state;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final Future<void> Function(FeedPost post) onLikeTap;
  final Future<void> Function(FeedPost post) onFavoriteTap;
  final String Function(Object error) errorMessageBuilder;
  final String errorTitle;
  final String emptyTitle;
  final String emptyMessage;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) {
        return AppErrorState(
          title: errorTitle,
          message: errorMessageBuilder(error),
          onRetry: onRetry,
        );
      },
      data: (data) {
        final itemCount =
            1 +
            (data.items.isEmpty ? 1 : data.items.length) +
            (data.isLoadingMore ? 1 : 0);

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.separated(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: itemCount,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                if (header != null) {
                  return header!;
                }
                return const SizedBox.shrink();
              }

              final dataIndex = index - 1;
              if (data.items.isEmpty && dataIndex == 0) {
                return Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: AppEmptyState(
                    title: emptyTitle,
                    message: emptyMessage,
                  ),
                );
              }

              if (dataIndex >= data.items.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final post = data.items[dataIndex];
              return PostCard(
                post: post,
                onTap: () => context.push(
                  AppRoutes.postDetail(
                    postId: post.id,
                    authorUsername: post.author.username,
                    postSlug: post.slug,
                  ),
                ),
                onAuthorTap: () => context.push(
                  AppRoutes.profile(
                    userId: post.author.id,
                    username: post.author.username,
                  ),
                ),
                onLikeTap: () => onLikeTap(post),
                onFavoriteTap: () => onFavoriteTap(post),
              );
            },
          ),
        );
      },
    );
  }
}
