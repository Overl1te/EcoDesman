import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../../core/network/error_message.dart";
import "../../../../core/routing/app_routes.dart";
import "../../../../core/utils/date_formatter.dart";
import "../../../../shared/widgets/app_empty_state.dart";
import "../../../../shared/widgets/app_error_state.dart";
import "../../../../shared/widgets/role_chip.dart";
import "../../../auth/data/repositories/auth_repository_impl.dart";
import "../../../auth/domain/models/app_user.dart";
import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../../feed/domain/models/feed_post.dart";
import "../../../map/domain/models/eco_map_category.dart";
import "../../data/datasources/admin_remote_data_source.dart";
import "../../domain/models/admin_map_point.dart";
import "../../domain/models/admin_map_point_input.dart";
import "../../domain/models/admin_overview.dart";

enum _MapMode { list, create }

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  final _postSearchController = TextEditingController();
  final _userSearchController = TextEditingController();
  final _pointSearchController = TextEditingController();

  late final TabController _tabController;

  AdminOverview? _overview;
  List<FeedPost> _posts = const [];
  List<AppUser> _users = const [];
  List<AdminMapPoint> _points = const [];
  List<EcoMapCategory> _categories = const [];

  bool _isLoadingOverview = false;
  bool _isLoadingPosts = false;
  bool _isLoadingUsers = false;
  bool _isLoadingPoints = false;
  String? _postsError;
  String? _usersError;
  String? _pointsError;
  String? _busyKey;

  String _postKind = "all";
  String _postStatus = "all";
  String _postOrdering = "recent";
  String _userRole = "all";
  String _userStatus = "all";
  String _pointStatus = "all";
  _MapMode _mapMode = _MapMode.list;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(_loadAll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _postSearchController.dispose();
    _userSearchController.dispose();
    _pointSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadOverview(),
      _loadPosts(),
      _loadUsers(),
      _loadCategoriesAndPoints(),
    ]);
  }

  Future<void> _loadOverview() async {
    setState(() => _isLoadingOverview = true);
    try {
      _overview = await ref.read(adminRemoteDataSourceProvider).fetchOverview();
    } catch (error) {
      _showSnack(
        humanizeNetworkError(error, fallback: "Не удалось загрузить обзор"),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoadingOverview = false);
    }
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoadingPosts = true;
      _postsError = null;
    });
    try {
      _posts = await ref.read(adminRemoteDataSourceProvider).fetchPosts(
        search: _postSearchController.text,
        kind: _postKind,
        publicationStatus: _postStatus,
      );
    } catch (error) {
      _postsError = humanizeNetworkError(error, fallback: "Не удалось загрузить посты");
    } finally {
      if (mounted) setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _usersError = null;
    });
    try {
      _users = await ref.read(adminRemoteDataSourceProvider).fetchUsers(
        search: _userSearchController.text,
        role: _userRole,
        status: _userStatus,
      );
    } catch (error) {
      _usersError = humanizeNetworkError(error, fallback: "Не удалось загрузить пользователей");
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _loadCategoriesAndPoints() async {
    setState(() {
      _isLoadingPoints = true;
      _pointsError = null;
    });
    try {
      final categories = await ref.read(adminRemoteDataSourceProvider).fetchMapCategories();
      final points = await ref.read(adminRemoteDataSourceProvider).fetchMapPoints(
        search: _pointSearchController.text,
        isActive: switch (_pointStatus) {
          "active" => true,
          "hidden" => false,
          _ => null,
        },
      );
      _categories = categories;
      _points = points;
    } catch (error) {
      _pointsError = humanizeNetworkError(error, fallback: "Не удалось загрузить точки");
    } finally {
      if (mounted) setState(() => _isLoadingPoints = false);
    }
  }

  Future<void> _runAction(String key, Future<void> Function() action) async {
    setState(() => _busyKey = key);
    try {
      await action();
    } catch (error) {
      _showSnack(
        humanizeNetworkError(error, fallback: "Не удалось выполнить действие"),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Отмена")),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Подтвердить")),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _togglePostPublished(FeedPost post) async {
    await _runAction("post-${post.id}", () async {
      await ref.read(adminRemoteDataSourceProvider).togglePostPublished(
        postId: post.id,
        isPublished: !post.isPublished,
      );
      await Future.wait([_loadPosts(), _loadOverview()]);
    });
  }

  Future<void> _deletePost(FeedPost post) async {
    final confirmed = await _confirm("Удалить пост", "Пост будет удалён без восстановления.");
    if (!confirmed) return;
    await _runAction("post-delete-${post.id}", () async {
      await ref.read(adminRemoteDataSourceProvider).deletePost(post.id);
      await Future.wait([_loadPosts(), _loadOverview()]);
    });
  }

  Future<void> _updateUserRole(AppUser user, String role) async {
    await _runAction("user-role-${user.id}", () async {
      await ref.read(authRepositoryProvider).updateUserRole(userId: user.id, role: role);
      await _loadUsers();
    });
  }

  Future<void> _moderateUser(AppUser user, String action) async {
    await _runAction("user-$action-${user.id}", () async {
      if (action == "warn") {
        await ref.read(authRepositoryProvider).warnUser(user.id);
      } else if (action == "ban") {
        await ref.read(authRepositoryProvider).banUser(user.id);
      } else {
        await ref.read(authRepositoryProvider).unbanUser(user.id);
      }
      await Future.wait([_loadUsers(), _loadOverview()]);
    });
  }

  Future<void> _openPointEditor([AdminMapPoint? point]) async {
    if (_categories.isEmpty) {
      _showSnack("Сначала дождитесь загрузки категорий.", isError: true);
      return;
    }

    final input = await showModalBottomSheet<AdminMapPointInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _PointEditorSheet(categories: _categories, point: point),
    );

    if (input == null) return;

    await _runAction(
      point == null ? "point-create" : "point-save-${point.id}",
      () async {
        if (point == null) {
          await ref.read(adminRemoteDataSourceProvider).createMapPoint(input);
        } else {
          await ref.read(adminRemoteDataSourceProvider).updateMapPoint(pointId: point.id, input: input);
        }
        await Future.wait([_loadCategoriesAndPoints(), _loadOverview()]);
      },
    );
  }

  Future<void> _deletePoint(AdminMapPoint point) async {
    final confirmed = await _confirm("Удалить точку", "Точка будет удалена с карты.");
    if (!confirmed) return;
    await _runAction("point-delete-${point.id}", () async {
      await ref.read(adminRemoteDataSourceProvider).deleteMapPoint(point.id);
      await Future.wait([_loadCategoriesAndPoints(), _loadOverview()]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    if (!authState.isAuthenticated || user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Админка")),
        body: const AppEmptyState(
          title: "Нужен вход",
          message: "Войдите в аккаунт с правами администратора.",
        ),
      );
    }

    if (!user.canAccessAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text("Админка")),
        body: const AppEmptyState(
          title: "Недостаточно прав",
          message: "Раздел доступен только для админов и суперпользователей.",
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Админка"),
        actions: [
          IconButton(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
            tooltip: "Обновить",
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.article_outlined, size: 18), text: "Посты"),
              Tab(icon: Icon(Icons.people_outline, size: 18), text: "Люди"),
              Tab(icon: Icon(Icons.place_outlined, size: 18), text: "Точки"),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _buildStatsBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostsTab(),
                _buildUsersTab(),
                _buildPointsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats bar ──────────────────────────────────────────────────────────────
  Widget _buildStatsBar() {
    if (_isLoadingOverview && _overview == null) {
      return const LinearProgressIndicator();
    }
    if (_overview == null) return const SizedBox.shrink();

    final ov = _overview!;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _StatChip(icon: Icons.article_outlined, label: "Посты", value: "${ov.postsCount}", sub: "${ov.publishedPostsCount} опубл · ${ov.draftPostsCount} черн"),
            _statSep(muted),
            _StatChip(icon: Icons.place_outlined, label: "Точки", value: "${ov.mapPointsCount}", sub: "${ov.activeMapPointsCount} акт · ${ov.hiddenMapPointsCount} скрыты"),
            _statSep(muted),
            _StatChip(icon: Icons.people_outline, label: "Люди", value: "${ov.usersCount}", sub: "${ov.adminsCount} адм · ${ov.bannedUsersCount} бан"),
          ],
        ),
      ),
    );
  }

  Widget _statSep(Color color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Text("|", style: TextStyle(color: color)),
  );

  // ── Posts tab ──────────────────────────────────────────────────────────────
  Widget _buildPostsTab() {
    if (_isLoadingPosts && _posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_postsError != null && _posts.isEmpty) {
      return AppErrorState(
        title: "Не удалось загрузить посты",
        message: _postsError!,
        onRetry: _loadPosts,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Inline filters
        _buildSearchField(_postSearchController, "Поиск постов", _loadPosts),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                value: _postKind,
                items: const {"all": "Все типы", "news": "Новости", "story": "Истории", "event": "События"},
                onChanged: (v) { setState(() => _postKind = v); _loadPosts(); },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDropdown(
                value: _postStatus,
                items: const {"all": "Все", "published": "Опубл.", "draft": "Черновики"},
                onChanged: (v) { setState(() => _postStatus = v); _loadPosts(); },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildDropdown(
          value: _postOrdering,
          items: const {"recent": "По дате", "popular": "По популярности", "recommended": "По рекомендациям"},
          onChanged: (v) { setState(() => _postOrdering = v); _loadPosts(); },
        ),
        const SizedBox(height: 12),
        if (_posts.isEmpty)
          const AppEmptyState(title: "Посты не найдены", message: "Попробуйте изменить фильтры.")
        else
          for (final post in _posts) ...[
            _PostCard(
              post: post,
              busyKey: _busyKey,
              onView: (post) => context.push(
                AppRoutes.postDetail(postId: post.id, authorUsername: post.author.username, postSlug: post.slug),
              ),
              onEdit: (post) => context.push(AppRoutes.postEditor(post.id)),
              onTogglePublished: _togglePostPublished,
              onDelete: _deletePost,
            ),
            const SizedBox(height: 6),
          ],
      ],
    );
  }

  // ── Users tab ──────────────────────────────────────────────────────────────
  Widget _buildUsersTab() {
    if (_isLoadingUsers && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_usersError != null && _users.isEmpty) {
      return AppErrorState(
        title: "Не удалось загрузить пользователей",
        message: _usersError!,
        onRetry: _loadUsers,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildSearchField(_userSearchController, "Поиск пользователей", _loadUsers),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                value: _userRole,
                items: const {"all": "Все роли", "admin": "Админы", "support": "Поддержка", "moderator": "Моды", "user": "Юзеры"},
                onChanged: (v) { setState(() => _userRole = v); _loadUsers(); },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDropdown(
                value: _userStatus,
                items: const {"all": "Все", "active": "Активные", "banned": "Заблок."},
                onChanged: (v) { setState(() => _userStatus = v); _loadUsers(); },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_users.isEmpty)
          const AppEmptyState(title: "Пользователи не найдены", message: "Проверьте фильтры.")
        else
          for (final user in _users) ...[
            _UserCard(
              user: user,
              busyKey: _busyKey,
              onRoleChanged: _updateUserRole,
              onWarn: (u) => _moderateUser(u, "warn"),
              onBan: (u) => _moderateUser(u, "ban"),
              onUnban: (u) => _moderateUser(u, "unban"),
            ),
            const SizedBox(height: 6),
          ],
      ],
    );
  }

  // ── Points tab ─────────────────────────────────────────────────────────────
  Widget _buildPointsTab() {
    return Column(
      children: [
        // Mode selector
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: "Список",
                  icon: Icons.list,
                  isActive: _mapMode == _MapMode.list,
                  onTap: () => setState(() => _mapMode = _MapMode.list),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeButton(
                  label: "Создать / Редактировать",
                  icon: Icons.add_location_alt_outlined,
                  isActive: _mapMode == _MapMode.create,
                  onTap: () => setState(() => _mapMode = _MapMode.create),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _mapMode == _MapMode.list
              ? _buildPointsListView()
              : _buildPointCreateButton(),
        ),
      ],
    );
  }

  Widget _buildPointsListView() {
    if (_isLoadingPoints && _points.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pointsError != null && _points.isEmpty) {
      return AppErrorState(
        title: "Не удалось загрузить точки",
        message: _pointsError!,
        onRetry: _loadCategoriesAndPoints,
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        _buildSearchField(_pointSearchController, "Поиск точек", _loadCategoriesAndPoints),
        const SizedBox(height: 8),
        _buildDropdown(
          value: _pointStatus,
          items: const {"all": "Все точки", "active": "Активные", "hidden": "Скрытые"},
          onChanged: (v) { setState(() => _pointStatus = v); _loadCategoriesAndPoints(); },
        ),
        const SizedBox(height: 12),
        if (_points.isEmpty)
          const AppEmptyState(title: "Точки не найдены", message: "Измените фильтры или создайте точку.")
        else
          for (final point in _points) ...[
            _PointCard(
              point: point,
              busyKey: _busyKey,
              onEdit: () => _openPointEditor(point),
              onDelete: () => _deletePoint(point),
            ),
            const SizedBox(height: 6),
          ],
      ],
    );
  }

  Widget _buildPointCreateButton() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text("Новая точка"),
              onPressed: _categories.isEmpty ? null : () => _openPointEditor(),
            ),
            if (_categories.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                "Загрузка категорий...",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _buildSearchField(TextEditingController controller, String hint, VoidCallback onSubmit) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 18),
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onSubmitted: (_) => onSubmit(),
      textInputAction: TextInputAction.search,
    );
  }

  Widget _buildDropdown({
    required String value,
    required Map<String, String> items,
    required void Function(String) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isDense: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }
}

// ── Stat chip ──────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label, required this.value, required this.sub});

  final IconData icon;
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text("$label: ", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text(value, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(width: 4),
        Text(sub, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
      ],
    );
  }
}

// ── Mode button ────────────────────────────────────────────────────────────
class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.label, required this.icon, required this.isActive, required this.onTap});

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status badge ───────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bg = color.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

Color _postStatusColor(BuildContext context, bool isPublished) {
  return isPublished ? Colors.green.shade700 : Colors.grey.shade600;
}

Color _pointStatusColor(bool isActive) =>
    isActive ? Colors.green.shade700 : Colors.amber.shade800;

Color _userStatusColor(bool isBanned) =>
    isBanned ? Colors.red.shade700 : Colors.green.shade700;

// ── Post card ──────────────────────────────────────────────────────────────
class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.busyKey,
    required this.onView,
    required this.onEdit,
    required this.onTogglePublished,
    required this.onDelete,
  });

  final FeedPost post;
  final String? busyKey;
  final void Function(FeedPost) onView;
  final void Function(FeedPost) onEdit;
  final Future<void> Function(FeedPost) onTogglePublished;
  final Future<void> Function(FeedPost) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _postStatusColor(context, post.isPublished);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusBadge(
                  label: post.isPublished ? "Опубликован" : "Черновик",
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    post.title.isEmpty ? "Без заголовка" : post.title,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "@${post.author.name} · ${formatPostDate(post.publishedAt)}",
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text("👁 ${post.viewCount}", style: theme.textTheme.labelSmall),
                const SizedBox(width: 10),
                Text("❤️ ${post.likesCount}", style: theme.textTheme.labelSmall),
                const SizedBox(width: 10),
                Text("💬 ${post.commentsCount}", style: theme.textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ActionChip(
                  label: const Text("Открыть"),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onView(post),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text("Изменить"),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onEdit(post),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, size: 20),
                  onSelected: (v) {
                    if (v == "toggle") onTogglePublished(post);
                    if (v == "delete") onDelete(post);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: "toggle",
                      enabled: busyKey != "post-${post.id}",
                      child: Text(post.isPublished ? "В черновик" : "Опубликовать"),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: "delete",
                      enabled: busyKey != "post-delete-${post.id}",
                      child: const Text("Удалить", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── User card ──────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.busyKey,
    required this.onRoleChanged,
    required this.onWarn,
    required this.onBan,
    required this.onUnban,
  });

  final AppUser user;
  final String? busyKey;
  final Future<void> Function(AppUser, String) onRoleChanged;
  final Future<void> Function(AppUser) onWarn;
  final Future<void> Function(AppUser) onBan;
  final Future<void> Function(AppUser) onUnban;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _userStatusColor(user.isBanned);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                      Text("@${user.username} · ${user.email}", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                _StatusBadge(
                  label: user.isBanned ? "Забанен" : "Активен",
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                RoleChip(role: user.role),
                const SizedBox(width: 8),
                // Compact role dropdown
                Expanded(
                  child: DropdownButton<String>(
                    value: user.role,
                    isDense: true,
                    isExpanded: true,
                    underline: Container(height: 1, color: theme.colorScheme.outlineVariant),
                    items: const [
                      DropdownMenuItem(value: "admin", child: Text("Админ")),
                      DropdownMenuItem(value: "support", child: Text("Поддержка")),
                      DropdownMenuItem(value: "moderator", child: Text("Модератор")),
                      DropdownMenuItem(value: "user", child: Text("Пользователь")),
                    ],
                    onChanged: busyKey == "user-role-${user.id}"
                        ? null
                        : (v) { if (v != null) onRoleChanged(user, v); },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Text("⚠️", style: TextStyle(fontSize: 18)),
                  tooltip: "Предупредить",
                  onPressed: busyKey == "user-warn-${user.id}" ? null : () => onWarn(user),
                  visualDensity: VisualDensity.compact,
                ),
                if (user.isBanned)
                  IconButton(
                    icon: const Text("🔓", style: TextStyle(fontSize: 18)),
                    tooltip: "Разблокировать",
                    onPressed: busyKey == "user-unban-${user.id}" ? null : () => onUnban(user),
                    visualDensity: VisualDensity.compact,
                  )
                else
                  IconButton(
                    icon: const Text("🚫", style: TextStyle(fontSize: 18)),
                    tooltip: "Заблокировать",
                    onPressed: busyKey == "user-ban-${user.id}" ? null : () => onBan(user),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Point card ─────────────────────────────────────────────────────────────
class _PointCard extends StatelessWidget {
  const _PointCard({required this.point, required this.busyKey, required this.onEdit, required this.onDelete});

  final AdminMapPoint point;
  final String? busyKey;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _pointStatusColor(point.isActive);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusBadge(label: point.isActive ? "Активна" : "Скрыта", color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(point.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            if (point.address.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(point.address, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            if (point.categories.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final cat in point.categories)
                    Chip(
                      label: Text(cat.title, style: const TextStyle(fontSize: 11)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                ActionChip(
                  label: const Text("Редактировать"),
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text("Удалить"),
                  visualDensity: VisualDensity.compact,
                  onPressed: busyKey == "point-delete-${point.id}" ? null : onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Point editor sheet ─────────────────────────────────────────────────────
class _PointEditorSheet extends StatefulWidget {
  const _PointEditorSheet({required this.categories, this.point});

  final List<EcoMapCategory> categories;
  final AdminMapPoint? point;

  @override
  State<_PointEditorSheet> createState() => _PointEditorSheetState();
}

class _PointEditorSheetState extends State<_PointEditorSheet> {
  late final TextEditingController _slugController;
  late final TextEditingController _titleController;
  late final TextEditingController _shortDescController;
  late final TextEditingController _descController;
  late final TextEditingController _addressController;
  late final TextEditingController _workingHoursController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _sortOrderController;
  late final TextEditingController _imageUrlsController;
  late bool _isActive;
  late Set<int> _selectedCategoryIds;

  bool _coordsExpanded = false;
  bool _catsExpanded = true;
  bool _extraExpanded = false;

  @override
  void initState() {
    super.initState();
    final p = widget.point;
    _slugController = TextEditingController(text: p?.slug ?? "");
    _titleController = TextEditingController(text: p?.title ?? "");
    _shortDescController = TextEditingController(text: p?.shortDescription ?? "");
    _descController = TextEditingController(text: p?.description ?? "");
    _addressController = TextEditingController(text: p?.address ?? "");
    _workingHoursController = TextEditingController(text: p?.workingHours ?? "");
    _latController = TextEditingController(text: p != null ? "${p.latitude}" : "");
    _lngController = TextEditingController(text: p != null ? "${p.longitude}" : "");
    _sortOrderController = TextEditingController(text: p != null ? "${p.sortOrder}" : "0");
    _imageUrlsController = TextEditingController(
      text: p?.images.map((i) => i.imageUrl).join("\n") ?? "",
    );
    _isActive = p?.isActive ?? true;
    _selectedCategoryIds = p?.categories.map((c) => c.id).toSet() ?? <int>{};
  }

  @override
  void dispose() {
    for (final c in [_slugController, _titleController, _shortDescController, _descController, _addressController, _workingHoursController, _latController, _lngController, _sortOrderController, _imageUrlsController]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.point == null ? "Новая точка" : "Редактор точки",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),

            // Основное
            _section("Основное", true, [
              _field(_titleController, "Название"),
              _field(_slugController, "Slug"),
              _field(_shortDescController, "Краткое описание", maxLines: 2),
              _field(_descController, "Описание", maxLines: 4),
              _field(_addressController, "Адрес"),
              _field(_workingHoursController, "Часы работы"),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                title: const Text("Показывать на карте"),
                dense: true,
              ),
            ]),

            // Координаты
            _expandable("Координаты", _coordsExpanded, (v) => setState(() => _coordsExpanded = v), [
              Row(
                children: [
                  Expanded(child: _field(_latController, "Широта")),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_lngController, "Долгота")),
                ],
              ),
            ]),

            // Категории
            _expandable("Категории", _catsExpanded, (v) => setState(() => _catsExpanded = v), [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.categories.map((cat) {
                  final selected = _selectedCategoryIds.contains(cat.id);
                  return FilterChip(
                    label: Text(cat.title),
                    selected: selected,
                    onSelected: (s) => setState(() {
                      if (s) { _selectedCategoryIds.add(cat.id); } else { _selectedCategoryIds.remove(cat.id); }
                    }),
                  );
                }).toList(),
              ),
            ]),

            // Дополнительно
            _expandable("Дополнительно", _extraExpanded, (v) => setState(() => _extraExpanded = v), [
              _field(_sortOrderController, "Порядок сортировки"),
              _field(_imageUrlsController, "Изображения (одна ссылка на строку)", maxLines: 3),
            ]),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(widget.point == null ? "Создать точку" : "Сохранить"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, bool open, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        ...children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: c)),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _expandable(String title, bool open, void Function(bool) onToggle, List<Widget> children) {
    return Column(
      children: [
        InkWell(
          onTap: () => onToggle(!open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const Spacer(),
                Icon(open ? Icons.expand_less : Icons.expand_more, size: 18),
              ],
            ),
          ),
        ),
        if (open) ...[
          ...children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: c)),
        ],
        const Divider(height: 1),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, {int maxLines = 1}) {
    return TextField(
      controller: c,
      minLines: maxLines,
      maxLines: maxLines == 1 ? 1 : maxLines + 2,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
    );
  }

  void _submit() {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 0;

    if (_titleController.text.trim().isEmpty || _slugController.text.trim().isEmpty || lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Заполните название, slug и координаты.")),
      );
      return;
    }

    Navigator.of(context).pop(
      AdminMapPointInput(
        slug: _slugController.text.trim(),
        title: _titleController.text.trim(),
        shortDescription: _shortDescController.text.trim(),
        description: _descController.text.trim(),
        address: _addressController.text.trim(),
        workingHours: _workingHoursController.text.trim(),
        latitude: lat,
        longitude: lng,
        isActive: _isActive,
        sortOrder: sortOrder,
        categoryIds: _selectedCategoryIds.toList(),
        imageUrls: _imageUrlsController.text.split("\n").map((v) => v.trim()).where((v) => v.isNotEmpty).toList(),
      ),
    );
  }
}
