import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../../core/network/error_message.dart";
import "../../../../core/utils/date_formatter.dart";
import "../../../../shared/widgets/app_empty_state.dart";
import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../data/repositories/support_repository_impl.dart";
import "../../domain/models/support_models.dart";

class SupportCenterScreen extends ConsumerStatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  ConsumerState<SupportCenterScreen> createState() =>
      _SupportCenterScreenState();
}

class _SupportCenterScreenState extends ConsumerState<SupportCenterScreen> {
  final _searchController = TextEditingController();
  Timer? _pollTimer;

  SupportKnowledgeResponse _knowledge = const SupportKnowledgeResponse.empty();
  String _selectedCategory = "Аккаунт";
  String _query = "";
  bool _isLoading = true;
  String? _error;

  static const _categories = <_HelpCategory>[
    _HelpCategory(
      id: "Аккаунт",
      title: "Аккаунт",
      description: "Вход, профиль и доступ.",
      icon: Icons.person_outline,
    ),
    _HelpCategory(
      id: "Карта",
      title: "Карта",
      description: "Точки, адреса и геолокация.",
      icon: Icons.map_outlined,
    ),
    _HelpCategory(
      id: "Отзывы",
      title: "Отзывы",
      description: "Публикация, фото и оценки.",
      icon: Icons.rate_review_outlined,
    ),
    _HelpCategory(
      id: "Прочее",
      title: "Прочее",
      description: "Уведомления и другие вопросы.",
      icon: Icons.help_outline,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
    Future.microtask(_loadKnowledge);
    _pollTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _loadKnowledge(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadKnowledge({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final knowledge = await ref
          .read(supportRepositoryProvider)
          .fetchKnowledge();
      if (!mounted) {
        return;
      }
      setState(() {
        _knowledge = knowledge;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = humanizeNetworkError(
          error,
          fallback: "Не удалось загрузить раздел помощи",
        );
      });
    }
  }

  List<SupportKnowledgeEntry> get _filteredArticles {
    return _knowledge.faq.where((entry) {
      if (entry.category != _selectedCategory) {
        return false;
      }
      if (_query.isEmpty) {
        return true;
      }
      final haystack = [
        entry.title,
        entry.answer,
        entry.category,
        ...entry.keywords,
      ].join(" ").toLowerCase();
      return haystack.contains(_query);
    }).toList();
  }

  Future<void> _openCreateThreadSheet([SupportKnowledgeEntry? article]) async {
    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated) {
      _showSnack("Войдите, чтобы написать в поддержку");
      context.push("/login");
      return;
    }

    final input = await showModalBottomSheet<_CreateThreadInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _CreateThreadSheet(article: article),
    );

    if (input == null) {
      return;
    }

    try {
      final thread = await ref
          .read(supportRepositoryProvider)
          .createThread(
            subject: input.subject,
            body: input.body,
            category: input.category,
          );
      if (!mounted) {
        return;
      }
      context.push("/profile/support/thread/${thread.id}");
    } catch (error) {
      _showSnack(
        humanizeNetworkError(error, fallback: "Не удалось создать обращение"),
        isError: true,
      );
    }
  }

  void _showArticle(SupportKnowledgeEntry entry) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(entry.title),
          content: SingleChildScrollView(child: Text(entry.answer)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Закрыть"),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openCreateThreadSheet(entry);
              },
              child: const Text("Не помогло? Написать"),
            ),
          ],
        );
      },
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final articles = _filteredArticles;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F4),
      appBar: AppBar(
        title: const Text("Помощь"),
        actions: [
          IconButton(
            onPressed: () => context.push("/profile/support/requests"),
            icon: const Icon(Icons.forum_outlined),
            tooltip: "Мои обращения",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadKnowledge,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text(
              "Помощь",
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Ответы на вопросы и поддержка пользователей",
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: "Опишите проблему или вопрос",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openCreateThreadSheet(),
                icon: const Icon(Icons.support_agent_outlined),
                label: const Text("Написать в поддержку"),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push("/profile/support/requests"),
              icon: const Icon(Icons.forum_outlined),
              label: const Text("Мои обращения"),
            ),
            const SizedBox(height: 24),
            Text(
              "Категории",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            for (final category in _categories)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CategoryTile(
                  category: category,
                  active: category.id == _selectedCategory,
                  onTap: () {
                    setState(() {
                      _selectedCategory = category.id;
                    });
                  },
                ),
              ),
            const SizedBox(height: 14),
            Text(
              "Статьи",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AppEmptyState(
                title: "Раздел помощи временно недоступен",
                message: _error!,
              )
            else if (articles.isEmpty)
              _EmptyActionState(
                title: "Ничего не найдено",
                message: "Попробуйте другой запрос или напишите нам.",
                actionLabel: "Написать в поддержку",
                onAction: () => _openCreateThreadSheet(),
              )
            else
              for (final entry in articles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ArticleTile(
                    entry: entry,
                    onOpen: () => _showArticle(entry),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class SupportRequestsScreen extends ConsumerStatefulWidget {
  const SupportRequestsScreen({super.key});

  @override
  ConsumerState<SupportRequestsScreen> createState() =>
      _SupportRequestsScreenState();
}

class _SupportRequestsScreenState extends ConsumerState<SupportRequestsScreen> {
  List<SupportThreadSummary> _threads = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadThreads);
  }

  Future<void> _loadThreads() async {
    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated) {
      setState(() {
        _threads = const [];
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final threads = await ref
          .read(supportRepositoryProvider)
          .fetchThreads(teamView: authState.user?.canAccessSupport ?? false);
      if (!mounted) {
        return;
      }
      setState(() {
        _threads = threads;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = humanizeNetworkError(
          error,
          fallback: "Не удалось загрузить обращения",
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F4),
      appBar: AppBar(title: const Text("Мои обращения")),
      body: RefreshIndicator(
        onRefresh: _loadThreads,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            if (!authState.isAuthenticated)
              _EmptyActionState(
                title: "Нужен вход",
                message:
                    "Войдите, чтобы видеть историю обращений и ответы поддержки.",
                actionLabel: "Войти",
                onAction: () => context.push("/login"),
              )
            else if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AppEmptyState(
                title: "Не удалось загрузить обращения",
                message: _error!,
              )
            else if (_threads.isEmpty)
              _EmptyActionState(
                title: "У вас пока нет обращений",
                message: "Попробуйте найти ответ в помощи или напишите нам.",
                actionLabel: "К помощи",
                onAction: () => context.go("/profile/support"),
              )
            else
              for (final thread in _threads)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ThreadTile(
                    thread: thread,
                    onTap: () =>
                        context.push("/profile/support/thread/${thread.id}"),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _HelpCategory {
  const _HelpCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.active,
    required this.onTap,
  });

  final _HelpCategory category;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? primary : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: primary.withValues(alpha: 0.12),
                child: Icon(category.icon, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      category.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({required this.entry, required this.onOpen});

  final SupportKnowledgeEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _shortAnswer(entry.answer),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onOpen,
                child: const Text("Открыть"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread, required this.onTap});

  final SupportThreadSummary thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        onTap: onTap,
        title: Text(
          thread.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          thread.lastMessagePreview.isNotEmpty
              ? thread.lastMessagePreview
              : "Пока без сообщений",
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              getSupportThreadStatusLabel(thread.status),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatPostDate(thread.lastMessageAt.toLocal()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyActionState extends StatelessWidget {
  const _EmptyActionState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppEmptyState(title: title, message: message),
        FilledButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _CreateThreadInput {
  const _CreateThreadInput({
    required this.subject,
    required this.body,
    required this.category,
  });

  final String subject;
  final String body;
  final String category;
}

class _CreateThreadSheet extends StatefulWidget {
  const _CreateThreadSheet({this.article});

  final SupportKnowledgeEntry? article;

  @override
  State<_CreateThreadSheet> createState() => _CreateThreadSheetState();
}

class _CreateThreadSheetState extends State<_CreateThreadSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _subjectController;
  late final TextEditingController _bodyController;
  String _category = "general";

  @override
  void initState() {
    super.initState();
    final article = widget.article;
    _subjectController = TextEditingController(text: article?.title ?? "");
    _bodyController = TextEditingController(
      text: article == null
          ? ""
          : "Не помогла статья «${article.title}».\n\nЧто именно не работает:",
    );
    _category = _categoryFromArticle(article);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  String _categoryFromArticle(SupportKnowledgeEntry? article) {
    switch (article?.category) {
      case "Аккаунт":
        return "account";
      case "Карта":
        return "map";
      case "Отзывы":
        return "content";
      default:
        return "general";
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _CreateThreadInput(
        subject: _subjectController.text.trim(),
        body: _bodyController.text.trim(),
        category: _category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Написать в поддержку",
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              "Опишите проблему коротко: где были, что сделали и что пошло не так.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: "Категория"),
              items: const [
                DropdownMenuItem(value: "general", child: Text("Прочее")),
                DropdownMenuItem(value: "account", child: Text("Аккаунт")),
                DropdownMenuItem(value: "content", child: Text("Отзывы")),
                DropdownMenuItem(value: "map", child: Text("Карта")),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _category = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: "Тема"),
              validator: (value) {
                if ((value?.trim().length ?? 0) < 3) {
                  return "Коротко сформулируйте тему";
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bodyController,
              minLines: 4,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: "Сообщение",
                hintText: "Опишите проблему, шаги и что уже пробовали.",
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if ((value?.trim().length ?? 0) < 6) {
                  return "Нужно немного больше деталей";
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send_outlined),
                label: const Text("Написать в поддержку"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _shortAnswer(String answer) {
  final parts = answer.split(RegExp(r"(?<=[.!?])\s+"));
  final sentence = parts.isEmpty ? answer : parts.first;
  if (sentence.length <= 120) {
    return sentence;
  }
  return "${sentence.substring(0, 117).trim()}...";
}
