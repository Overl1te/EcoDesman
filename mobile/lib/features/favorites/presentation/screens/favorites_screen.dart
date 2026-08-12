import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../../feed/presentation/controllers/feed_controller.dart";
import "../../../feed/presentation/widgets/posts_collection_view.dart";

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Избранное")),
      body: const SafeArea(child: FavoritesScreen()),
    );
  }
}

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  late final ScrollController _scrollController;
  String _ordering = "recent";

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 320) {
      ref
          .read(
            postsCollectionControllerProvider(
              favoritePostsQuery.copyWith(ordering: _ordering),
            ).notifier,
          )
          .loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    if (!authState.isAuthenticated) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bookmark_outline, size: 52),
              const SizedBox(height: 16),
              const Text(
                "Избранное доступно после входа",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go("/login"),
                child: const Text("Войти"),
              ),
            ],
          ),
        ),
      );
    }

    final provider = postsCollectionControllerProvider(
      favoritePostsQuery.copyWith(ordering: _ordering),
    );
    final state = ref.watch(provider);

    return PostsCollectionView(
      state: state,
      scrollController: _scrollController,
      onRefresh: () => ref.read(provider.notifier).refreshFeed(),
      onRetry: () => ref.invalidate(provider),
      errorMessageBuilder: ref.read(provider.notifier).toErrorMessage,
      emptyTitle: "Избранное пока пусто",
      emptyMessage:
          "Добавляйте публикации в закладки, чтобы быстро вернуться к ним позже.",
      header: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text("Сначала новые"),
            selected: _ordering == "recent",
            onSelected: (_) => setState(() {
              _ordering = "recent";
            }),
          ),
          ChoiceChip(
            label: const Text("Популярные"),
            selected: _ordering == "popular",
            onSelected: (_) => setState(() {
              _ordering = "popular";
            }),
          ),
        ],
      ),
      onLikeTap: (post) async {
        await ref.read(provider.notifier).toggleLike(post);
      },
      onFavoriteTap: (post) async {
        await ref.read(provider.notifier).toggleFavorite(post);
      },
    );
  }
}
