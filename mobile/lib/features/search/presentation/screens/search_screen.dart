import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../../core/routing/app_routes.dart";
import "../../../auth/data/repositories/auth_repository_impl.dart";
import "../../../auth/domain/models/app_user.dart";
import "../../../feed/data/repositories/posts_repository_impl.dart";
import "../../../feed/domain/models/feed_post.dart";
import "../../../feed/domain/models/paginated_posts.dart";
import "../../../feed/domain/models/posts_query.dart";
import "../../../feed/presentation/widgets/post_card.dart";
import "../../../../shared/widgets/remote_avatar.dart";

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Future<_SearchResults>? _searchFuture;
  String _submittedQuery = "";
  String _scope = "all";
  String _kind = "all";
  String _ordering = "recommended";
  bool _hasImages = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final query = _controller.text.trim();
    if (query.length < 2) {
      setState(() {
        _submittedQuery = query;
        _searchFuture = null;
      });
      return;
    }

    setState(() {
      _submittedQuery = query;
      _searchFuture = _loadResults(query);
    });
  }

  Future<_SearchResults> _loadResults(String query) async {
    final includeUsers = _scope == "all" || _scope == "users";
    final includePosts = _scope != "users";
    final postKind = _scope == "events"
        ? "event"
        : (_kind == "all" ? null : _kind);

    final postsPage = includePosts
        ? await ref
              .read(postsRepositoryProvider)
              .fetchPosts(
                query: PostsQuery(
                  search: query,
                  kind: postKind,
                  ordering: _ordering,
                  hasImages: _hasImages,
                  eventScope: _scope == "events" ? "upcoming" : "all",
                ),
              )
        : const PaginatedPosts(items: [], nextPage: null, totalCount: 0);
    final users = includeUsers
        ? await ref.read(authRepositoryProvider).searchUsers(query)
        : const <AppUser>[];

    return _SearchResults(posts: postsPage.items, users: users);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Поиск")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submitSearch(),
                  decoration: const InputDecoration(
                    hintText: "Посты, события, пользователи",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _submitSearch,
                child: const Text("Найти"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final scope in const [
                ("all", "Все"),
                ("posts", "Посты"),
                ("events", "События"),
                ("users", "Люди"),
              ])
                ChoiceChip(
                  label: Text(scope.$2),
                  selected: _scope == scope.$1,
                  onSelected: (_) => setState(() {
                    _scope = scope.$1;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_scope != "users")
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in const [
                  ("all", "Любой тип"),
                  ("news", "Новости"),
                  ("story", "Истории"),
                  ("event", "События"),
                ])
                  ChoiceChip(
                    label: Text(kind.$2),
                    selected:
                        (_scope == "events" && kind.$1 == "event") ||
                        _kind == kind.$1,
                    onSelected: _scope == "events"
                        ? null
                        : (_) => setState(() {
                            _kind = kind.$1;
                          }),
                  ),
                ChoiceChip(
                  label: const Text("Для вас"),
                  selected: _ordering == "recommended",
                  onSelected: (_) => setState(() {
                    _ordering = "recommended";
                  }),
                ),
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
                FilterChip(
                  label: const Text("Только с фото"),
                  selected: _hasImages,
                  onSelected: (value) => setState(() {
                    _hasImages = value;
                  }),
                ),
              ],
            ),
          const SizedBox(height: 20),
          if (_submittedQuery.isEmpty)
            Text(
              "Введите минимум 2 символа. Поиск работает по тексту постов, событиям, локациям и username.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else if (_searchFuture == null)
            Text(
              "Запрос слишком короткий.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            FutureBuilder<_SearchResults>(
              future: _searchFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Text(
                    "Не удалось выполнить поиск.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  );
                }

                final data = snapshot.data!;
                if (data.users.isEmpty && data.posts.isEmpty) {
                  return const Text("Ничего не найдено.");
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.users.isNotEmpty) ...[
                      Text(
                        "Пользователи",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            for (final user in data.users)
                              ListTile(
                                leading: RemoteAvatar(
                                  imageUrl: user.avatarUrl,
                                  fallbackLabel: user.displayName,
                                ),
                                title: Text(user.displayName),
                                subtitle: Text("@${user.username}"),
                                trailing: user.isBanned
                                    ? const Icon(
                                        Icons.block,
                                        color: Colors.redAccent,
                                      )
                                    : null,
                                onTap: () => context.push(
                                  AppRoutes.profile(
                                    userId: user.id,
                                    username: user.username,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (data.posts.isNotEmpty) ...[
                      Text(
                        _scope == "events" ? "Мероприятия" : "Публикации",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final post in data.posts) ...[
                        PostCard(
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
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SearchResults {
  const _SearchResults({required this.posts, required this.users});

  final List<FeedPost> posts;
  final List<AppUser> users;
}
