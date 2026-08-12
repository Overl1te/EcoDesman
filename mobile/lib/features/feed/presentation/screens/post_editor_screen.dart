import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../../core/network/error_message.dart";
import "../../../../core/network/image_upload_service.dart";
import "../../../../core/routing/app_routes.dart";
import "../../../../core/utils/date_formatter.dart";
import "../../../../shared/widgets/app_error_state.dart";
import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../../profile/presentation/controllers/profile_controller.dart";
import "../../data/repositories/posts_repository_impl.dart";
import "../../domain/models/post_details.dart";
import "../../domain/models/post_write_input.dart";
import "../controllers/feed_controller.dart";

class PostEditorScreen extends ConsumerStatefulWidget {
  const PostEditorScreen({super.key, this.postId});

  final int? postId;

  bool get isEditing => postId != null;

  @override
  ConsumerState<PostEditorScreen> createState() => _PostEditorScreenState();
}

class _PostEditorScreenState extends ConsumerState<PostEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _imageUrlsController = TextEditingController();
  final _eventLocationController = TextEditingController();

  bool _isPublished = true;
  bool _isSaving = false;
  bool _isUploadingImages = false;
  bool _didHydrate = false;
  String _selectedKind = "news";
  DateTime? _eventDate;
  DateTime? _eventStartsAt;
  DateTime? _eventEndsAt;
  String? _errorMessage;

  bool get _isEvent => _selectedKind == "event";

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _imageUrlsController.dispose();
    _eventLocationController.dispose();
    super.dispose();
  }

  void _hydrate(PostDetails post) {
    if (_didHydrate) {
      return;
    }

    _titleController.text = post.title;
    _bodyController.text = post.body;
    _imageUrlsController.text = post.images
        .map((image) => image.imageUrl)
        .join("\n");
    _eventLocationController.text = post.eventLocation;
    _selectedKind = post.kind;
    _eventDate = post.eventDate ?? post.eventStartsAt;
    _eventStartsAt = post.eventStartsAt;
    _eventEndsAt = post.eventEndsAt;
    _isPublished = post.isPublished;
    _didHydrate = true;
  }

  Future<void> _pickAndUploadImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final paths = result.files
          .map((file) => file.path)
          .whereType<String>()
          .toList();
      if (paths.isEmpty) {
        setState(() {
          _errorMessage = "Не удалось получить выбранные изображения";
        });
        return;
      }

      setState(() {
        _isUploadingImages = true;
        _errorMessage = null;
      });

      final uploader = ref.read(imageUploadServiceProvider);
      final uploadedUrls = <String>[];
      for (final path in paths) {
        uploadedUrls.add(await uploader.uploadImage(path));
      }

      final currentLines = _imageUrlsController.text
          .split("\n")
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      _imageUrlsController.text = [...currentLines, ...uploadedUrls].join("\n");
    } catch (error) {
      setState(() {
        _errorMessage = humanizeNetworkError(
          error,
          fallback: "Не удалось загрузить изображения",
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImages = false;
        });
      }
    }
  }

  Future<void> _pickEventDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _eventDate ?? _eventStartsAt ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _eventDate = DateTime(picked.year, picked.month, picked.day);
      _eventStartsAt = _syncWithDate(_eventStartsAt, _eventDate);
      _eventEndsAt = _syncWithDate(_eventEndsAt, _eventDate);
      _errorMessage = null;
    });
  }

  Future<void> _pickEventStartTime() async {
    if (_eventDate == null) {
      await _pickEventDate();
      if (!mounted || _eventDate == null) {
        return;
      }
    }

    final initial =
        _eventStartsAt ??
        DateTime(_eventDate!.year, _eventDate!.month, _eventDate!.day, 12, 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _eventStartsAt = DateTime(
        _eventDate!.year,
        _eventDate!.month,
        _eventDate!.day,
        picked.hour,
        picked.minute,
      );
      _eventEndsAt ??= _eventStartsAt!.add(const Duration(hours: 2));
    });
  }

  Future<void> _pickEventEndTime() async {
    if (_eventDate == null) {
      await _pickEventDate();
      if (!mounted || _eventDate == null) {
        return;
      }
    }

    final initial =
        _eventEndsAt ??
        _eventStartsAt?.add(const Duration(hours: 2)) ??
        DateTime(_eventDate!.year, _eventDate!.month, _eventDate!.day, 14, 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _eventEndsAt = DateTime(
        _eventDate!.year,
        _eventDate!.month,
        _eventDate!.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final currentUser = ref.read(authControllerProvider).user;
    if (currentUser == null) {
      return;
    }

    if (_isEvent && _eventDate == null) {
      setState(() {
        _errorMessage = "Для мероприятия нужно указать дату";
      });
      return;
    }

    if (_isEvent &&
        _eventStartsAt != null &&
        _eventEndsAt != null &&
        _eventEndsAt!.isBefore(_eventStartsAt!)) {
      setState(() {
        _errorMessage = "Время окончания не может быть раньше времени начала";
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final input = PostWriteInput(
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      kind: _selectedKind,
      isPublished: _isPublished,
      imageUrls: _imageUrlsController.text
          .split("\n")
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      eventDate: _isEvent ? _eventDate : null,
      eventStartsAt: _isEvent ? _eventStartsAt : null,
      eventEndsAt: _isEvent ? _eventEndsAt : null,
      eventLocation: _isEvent ? _eventLocationController.text.trim() : "",
    );

    try {
      final repository = ref.read(postsRepositoryProvider);
      final saved = widget.isEditing
          ? await repository.updatePost(postId: widget.postId!, input: input)
          : await repository.createPost(input);

      ref.read(feedControllerProvider.notifier).upsertPost(saved);
      ref.invalidate(postsCollectionControllerProvider(defaultEventsQuery));
      ref.invalidate(postsCollectionControllerProvider(favoritePostsQuery));
      ref.invalidate(userPostsProvider(saved.author.id));
      for (final lookup in AppRoutes.profileLookups(
        userId: saved.author.id,
        username: saved.author.username,
      )) {
        ref.invalidate(publicProfileProvider(lookup));
      }
      if (saved.author.id != currentUser.id) {
        ref.invalidate(userPostsProvider(currentUser.id));
      }
      if (widget.postId != null) {
        ref
            .read(
              postDetailsControllerProvider(
                PostRouteTarget.byId(widget.postId!),
              ).notifier,
            )
            .replacePost(saved);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing ? "Пост обновлён" : "Пост сохранён"),
        ),
      );

      if (widget.isEditing) {
        context.pop();
      } else {
        context.go(
          AppRoutes.postDetail(
            postId: saved.id,
            authorUsername: saved.author.username,
            postSlug: saved.slug,
          ),
        );
      }
    } catch (error) {
      setState(() {
        _errorMessage = humanizeNetworkError(
          error,
          fallback: widget.isEditing
              ? "Не удалось обновить пост"
              : "Не удалось создать пост",
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    if (!authState.isAuthenticated || authState.user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Редактор поста")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Чтобы публиковать посты, нужно войти в аккаунт.",
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go("/login"),
                  child: const Text("Перейти ко входу"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.isEditing) {
      final postAsync = ref.watch(
        postDetailsControllerProvider(PostRouteTarget.byId(widget.postId!)),
      );
      return Scaffold(
        appBar: AppBar(title: const Text("Редактирование поста")),
        body: postAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            return AppErrorState(
              title: "Не удалось открыть пост",
              message: "Попробуйте снова чуть позже.",
              onRetry: () {
                ref.invalidate(
                  postDetailsControllerProvider(
                    PostRouteTarget.byId(widget.postId!),
                  ),
                );
              },
            );
          },
          data: (post) {
            _hydrate(post);
            return _PostEditorForm(
              formKey: _formKey,
              titleController: _titleController,
              bodyController: _bodyController,
              imageUrlsController: _imageUrlsController,
              eventLocationController: _eventLocationController,
              isPublished: _isPublished,
              selectedKind: _selectedKind,
              errorMessage: _errorMessage,
              isSaving: _isSaving,
              isUploadingImages: _isUploadingImages,
              eventDate: _eventDate,
              eventStartsAt: _eventStartsAt,
              eventEndsAt: _eventEndsAt,
              onUploadImages: _pickAndUploadImages,
              onKindChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedKind = value;
                  if (value != "event") {
                    _eventDate = null;
                    _eventStartsAt = null;
                    _eventEndsAt = null;
                    _eventLocationController.clear();
                  }
                });
              },
              onPickEventDate: _pickEventDate,
              onPickEventStartTime: _pickEventStartTime,
              onPickEventEndTime: _pickEventEndTime,
              onPublishedChanged: (value) {
                setState(() {
                  _isPublished = value;
                });
              },
              onSave: _save,
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Новый пост")),
      body: _PostEditorForm(
        formKey: _formKey,
        titleController: _titleController,
        bodyController: _bodyController,
        imageUrlsController: _imageUrlsController,
        eventLocationController: _eventLocationController,
        isPublished: _isPublished,
        selectedKind: _selectedKind,
        errorMessage: _errorMessage,
        isSaving: _isSaving,
        isUploadingImages: _isUploadingImages,
        eventDate: _eventDate,
        eventStartsAt: _eventStartsAt,
        eventEndsAt: _eventEndsAt,
        onUploadImages: _pickAndUploadImages,
        onKindChanged: (value) {
          if (value == null) {
            return;
          }
          setState(() {
            _selectedKind = value;
            if (value != "event") {
              _eventDate = null;
              _eventStartsAt = null;
              _eventEndsAt = null;
              _eventLocationController.clear();
            }
          });
        },
        onPickEventDate: _pickEventDate,
        onPickEventStartTime: _pickEventStartTime,
        onPickEventEndTime: _pickEventEndTime,
        onPublishedChanged: (value) {
          setState(() {
            _isPublished = value;
          });
        },
        onSave: _save,
      ),
    );
  }
}

class _PostEditorForm extends StatelessWidget {
  const _PostEditorForm({
    required this.formKey,
    required this.titleController,
    required this.bodyController,
    required this.imageUrlsController,
    required this.eventLocationController,
    required this.isPublished,
    required this.selectedKind,
    required this.errorMessage,
    required this.isSaving,
    required this.isUploadingImages,
    required this.eventDate,
    required this.eventStartsAt,
    required this.eventEndsAt,
    required this.onUploadImages,
    required this.onKindChanged,
    required this.onPickEventDate,
    required this.onPickEventStartTime,
    required this.onPickEventEndTime,
    required this.onPublishedChanged,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final TextEditingController imageUrlsController;
  final TextEditingController eventLocationController;
  final bool isPublished;
  final String selectedKind;
  final String? errorMessage;
  final bool isSaving;
  final bool isUploadingImages;
  final DateTime? eventDate;
  final DateTime? eventStartsAt;
  final DateTime? eventEndsAt;
  final VoidCallback onUploadImages;
  final ValueChanged<String?> onKindChanged;
  final VoidCallback onPickEventDate;
  final VoidCallback onPickEventStartTime;
  final VoidCallback onPickEventEndTime;
  final ValueChanged<bool> onPublishedChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEvent = selectedKind == "event";

    return SafeArea(
      child: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "Заголовок",
                border: OutlineInputBorder(),
              ),
              maxLength: 160,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedKind,
              decoration: const InputDecoration(
                labelText: "Тип публикации",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "news", child: Text("Новость")),
                DropdownMenuItem(value: "story", child: Text("История")),
                DropdownMenuItem(value: "event", child: Text("Мероприятие")),
              ],
              onChanged: onKindChanged,
            ),
            if (isEvent) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onPickEventDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    eventDate == null
                        ? "Выбрать дату мероприятия"
                        : formatEventDay(eventDate),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPickEventStartTime,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          eventStartsAt == null
                              ? "Время начала"
                              : formatEventTime(eventStartsAt),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPickEventEndTime,
                      icon: const Icon(Icons.timer_outlined),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          eventEndsAt == null
                              ? "Время окончания"
                              : formatEventTime(eventEndsAt),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: eventLocationController,
                decoration: const InputDecoration(
                  labelText: "Место проведения",
                  hintText: "Необязательно",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: bodyController,
              decoration: const InputDecoration(
                labelText: "Текст",
                border: OutlineInputBorder(),
              ),
              minLines: 8,
              maxLines: 12,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Введите текст публикации";
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Изображения",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: isUploadingImages ? null : onUploadImages,
                  icon: isUploadingImages
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: const Text("Загрузить"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: imageUrlsController,
              decoration: const InputDecoration(
                labelText: "Ссылки на изображения",
                helperText:
                    "Можно загрузить файл или вставить URL. По одной ссылке на строку.",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.multiline,
              minLines: 3,
              maxLines: 6,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: isPublished,
              onChanged: onPublishedChanged,
              title: Text(
                isPublished ? "Опубликовано" : "Черновик",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                isPublished
                    ? "Пост сразу появится в ленте."
                    : "Черновик сохранится без публикации.",
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: isSaving ? null : onSave,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Сохранить пост"),
            ),
          ],
        ),
      ),
    );
  }
}

DateTime? _syncWithDate(DateTime? source, DateTime? targetDate) {
  if (source == null || targetDate == null) {
    return source;
  }

  return DateTime(
    targetDate.year,
    targetDate.month,
    targetDate.day,
    source.hour,
    source.minute,
  );
}
