import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../../core/routing/app_routes.dart";
import "../../../../shared/widgets/app_empty_state.dart";
import "../../../../shared/widgets/app_error_state.dart";
import "../../../auth/data/repositories/auth_repository_impl.dart";
import "../../../auth/domain/models/app_user.dart";
import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../../feed/presentation/widgets/post_card.dart";
import "../controllers/profile_controller.dart";
import "../widgets/profile_summary_card.dart";

class PublicProfileScreen extends ConsumerStatefulWidget {
  const PublicProfileScreen({super.key, required this.target});

  PublicProfileScreen.byId({super.key, required int userId})
    : target = ProfileRouteTarget.byId(userId);

  PublicProfileScreen.byUsername({super.key, required String username})
    : target = ProfileRouteTarget.byUsername(username);

  final ProfileRouteTarget target;

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  bool _isBusy = false;

  Future<void> _refreshData() async {
    ref.invalidate(publicProfileProvider(widget.target));
    final user = await ref.refresh(publicProfileProvider(widget.target).future);
    ref.invalidate(userPostsProvider(user.id));
    final _ = await ref.refresh(userPostsProvider(user.id).future);
  }

  Future<void> _runModerationAction(
    Future<AppUser> Function() action, {
    required String successMessage,
  }) async {
    setState(() {
      _isBusy = true;
    });

    try {
      await action();
      await _refreshData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(publicProfileProvider(widget.target));
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("РџСЂРѕС„РёР»СЊ")),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          return AppErrorState(
            title: "РќРµ СѓРґР°Р»РѕСЃСЊ РѕС‚РєСЂС‹С‚СЊ РїСЂРѕС„РёР»СЊ",
            message:
                "РџСЂРѕРІРµСЂСЊС‚Рµ РїРѕРґРєР»СЋС‡РµРЅРёРµ Рё РїРѕРїСЂРѕР±СѓР№С‚Рµ СЃРЅРѕРІР°.",
            onRetry: _refreshData,
          );
        },
        data: (user) {
          final postsAsync = ref.watch(userPostsProvider(user.id));
          final canAdminister =
              authState.user?.isAdmin == true && authState.user!.id != user.id;

          return RefreshIndicator(
            onRefresh: _refreshData,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                ProfileSummaryCard(
                  user: user,
                  actions: canAdminister
                      ? [
                          FilledButton.tonalIcon(
                            onPressed: _isBusy
                                ? null
                                : () {
                                    _runModerationAction(
                                      () => ref
                                          .read(authRepositoryProvider)
                                          .warnUser(user.id),
                                      successMessage:
                                          "РџСЂРµРґСѓРїСЂРµР¶РґРµРЅРёРµ РІС‹РґР°РЅРѕ",
                                    );
                                  },
                            icon: const Icon(Icons.warning_amber_rounded),
                            label: const Text("РџСЂРµРґСѓРїСЂРµРґРёС‚СЊ"),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _isBusy
                                ? null
                                : () {
                                    _runModerationAction(
                                      () => user.isBanned
                                          ? ref
                                                .read(authRepositoryProvider)
                                                .unbanUser(user.id)
                                          : ref
                                                .read(authRepositoryProvider)
                                                .banUser(user.id),
                                      successMessage: user.isBanned
                                          ? "РџРѕР»СЊР·РѕРІР°С‚РµР»СЊ СЂР°Р·Р±Р»РѕРєРёСЂРѕРІР°РЅ"
                                          : "РџРѕР»СЊР·РѕРІР°С‚РµР»СЊ Р·Р°Р±Р»РѕРєРёСЂРѕРІР°РЅ",
                                    );
                                  },
                            icon: Icon(
                              user.isBanned ? Icons.lock_open : Icons.block,
                            ),
                            label: Text(
                              user.isBanned
                                  ? "Р Р°Р·Р±Р°РЅРёС‚СЊ"
                                  : "Р—Р°Р±Р°РЅРёС‚СЊ",
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: user.role,
                              items: const [
                                DropdownMenuItem(
                                  value: "user",
                                  child: Text("РџРѕР»СЊР·РѕРІР°С‚РµР»СЊ"),
                                ),
                                DropdownMenuItem(
                                  value: "moderator",
                                  child: Text("РњРѕРґРµСЂР°С‚РѕСЂ"),
                                ),
                                DropdownMenuItem(
                                  value: "admin",
                                  child: Text("РђРґРјРёРЅ"),
                                ),
                              ],
                              onChanged: _isBusy
                                  ? null
                                  : (value) {
                                      if (value == null || value == user.role) {
                                        return;
                                      }
                                      _runModerationAction(
                                        () => ref
                                            .read(authRepositoryProvider)
                                            .updateUserRole(
                                              userId: user.id,
                                              role: value,
                                            ),
                                        successMessage:
                                            "Р РѕР»СЊ РѕР±РЅРѕРІР»РµРЅР°",
                                      );
                                    },
                            ),
                          ),
                        ]
                      : const [],
                ),
                const SizedBox(height: 20),
                Text(
                  "РџСѓР±Р»РёРєР°С†РёРё",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                postsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stackTrace) {
                    return AppErrorState(
                      title:
                          "РќРµ СѓРґР°Р»РѕСЃСЊ Р·Р°РіСЂСѓР·РёС‚СЊ РїРѕСЃС‚С‹",
                      message:
                          "РџРѕРїСЂРѕР±СѓР№С‚Рµ РѕР±РЅРѕРІРёС‚СЊ СЃС‚СЂР°РЅРёС†Сѓ РїСЂРѕС„РёР»СЏ.",
                      onRetry: () {
                        ref.invalidate(userPostsProvider(user.id));
                      },
                    );
                  },
                  data: (page) {
                    if (page.items.isEmpty) {
                      return const AppEmptyState(
                        title: "РџРѕРєР° РЅРµС‚ РїСѓР±Р»РёРєР°С†РёР№",
                        message:
                            "РљР°Рє С‚РѕР»СЊРєРѕ РїРѕР»СЊР·РѕРІР°С‚РµР»СЊ РѕРїСѓР±Р»РёРєСѓРµС‚ РїРѕСЃС‚С‹, РѕРЅРё РїРѕСЏРІСЏС‚СЃСЏ Р·РґРµСЃСЊ.",
                      );
                    }

                    return Column(
                      children: [
                        for (final post in page.items) ...[
                          PostCard(
                            post: post,
                            onTap: () => context.push(
                              AppRoutes.postDetail(
                                postId: post.id,
                                authorUsername: post.author.username,
                                postSlug: post.slug,
                              ),
                            ),
                            onAuthorTap: () {},
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
