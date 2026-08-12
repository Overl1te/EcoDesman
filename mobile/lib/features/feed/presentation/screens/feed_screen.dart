import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../domain/models/posts_query.dart";
import "../controllers/feed_controller.dart";
import "../widgets/posts_collection_view.dart";

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  late final ScrollController _scrollController;
  String _selectedKind = "all";
  String _ordering = "recommended";
  bool _hasImages = false;

  PostsQuery get _query => PostsQuery(
    kind: _selectedKind == "all" ? null : _selectedKind,
    ordering: _ordering,
    hasImages: _hasImages,
  );

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
    if (!_scrollController.hasClients) {
      return;
    }

    if (_scrollController.position.extentAfter < 320) {
      ref.read(postsCollectionControllerProvider(_query).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = postsCollectionControllerProvider(_query);
    final feedState = ref.watch(provider);
    final authState = ref.watch(authControllerProvider);

    return PostsCollectionView(
      state: feedState,
      scrollController: _scrollController,
      onRefresh: () => ref.read(provider.notifier).refreshFeed(),
      onRetry: () => ref.invalidate(provider),
      errorMessageBuilder: ref.read(provider.notifier).toErrorMessage,
      emptyTitle: "Пока нет публикаций",
      emptyMessage:
          "Попробуйте сменить фильтры или дождитесь новых материалов.",
      header: _FeedFilters(
        selectedKind: _selectedKind,
        ordering: _ordering,
        hasImages: _hasImages,
        onKindSelected: (value) {
          setState(() {
            _selectedKind = value;
          });
        },
        onOrderingSelected: (value) {
          setState(() {
            _ordering = value;
          });
        },
        onHasImagesChanged: (value) {
          setState(() {
            _hasImages = value;
          });
        },
      ),
      onLikeTap: (post) async {
        if (!authState.isAuthenticated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Войдите, чтобы ставить лайки")),
          );
          return;
        }
        await ref.read(provider.notifier).toggleLike(post);
      },
      onFavoriteTap: (post) async {
        if (!authState.isAuthenticated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Войдите, чтобы добавлять в избранное"),
            ),
          );
          return;
        }
        await ref.read(provider.notifier).toggleFavorite(post);
      },
    );
  }
}

class _FeedFilters extends StatelessWidget {
  const _FeedFilters({
    required this.selectedKind,
    required this.ordering,
    required this.hasImages,
    required this.onKindSelected,
    required this.onOrderingSelected,
    required this.onHasImagesChanged,
  });

  final String selectedKind;
  final String ordering;
  final bool hasImages;
  final ValueChanged<String> onKindSelected;
  final ValueChanged<String> onOrderingSelected;
  final ValueChanged<bool> onHasImagesChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in const [
              ("all", "Все"),
              ("news", "Новости"),
              ("story", "Истории"),
              ("event", "События"),
            ])
              ChoiceChip(
                label: Text(filter.$2),
                selected: selectedKind == filter.$1,
                onSelected: (_) => onKindSelected(filter.$1),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text("Для вас"),
              selected: ordering == "recommended",
              onSelected: (_) => onOrderingSelected("recommended"),
            ),
            ChoiceChip(
              label: const Text("Сначала новые"),
              selected: ordering == "recent",
              onSelected: (_) => onOrderingSelected("recent"),
            ),
            ChoiceChip(
              label: const Text("Популярные"),
              selected: ordering == "popular",
              onSelected: (_) => onOrderingSelected("popular"),
            ),
            FilterChip(
              label: const Text("Только с фото"),
              selected: hasImages,
              onSelected: onHasImagesChanged,
            ),
          ],
        ),
      ],
    );
  }
}
