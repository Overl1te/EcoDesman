import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/network/error_message.dart";
import "../../../../core/utils/date_formatter.dart";
import "../../../../shared/widgets/app_empty_state.dart";
import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../data/repositories/support_repository_impl.dart";
import "../../domain/models/support_models.dart";

class SupportThreadScreen extends ConsumerStatefulWidget {
  const SupportThreadScreen({super.key, required this.threadId});

  final int threadId;

  @override
  ConsumerState<SupportThreadScreen> createState() =>
      _SupportThreadScreenState();
}

class _SupportThreadScreenState extends ConsumerState<SupportThreadScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollTimer;

  SupportThreadDetail? _thread;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUpdatingThread = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadThread();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _loadThread(silent: true);
    });
  }

  Future<void> _loadThread({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final thread = await ref
          .read(supportRepositoryProvider)
          .fetchThread(widget.threadId);
      if (!mounted) {
        return;
      }
      setState(() {
        _thread = thread;
        _isLoading = false;
        _error = null;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = humanizeNetworkError(
          error,
          fallback: "Не удалось открыть чат поддержки",
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated) {
      _showSnack("Войдите, чтобы писать в чат");
      return;
    }

    final text = _messageController.text.trim();
    if (text.length < 2) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await ref
          .read(supportRepositoryProvider)
          .sendMessage(threadId: widget.threadId, body: text);
      _messageController.clear();
      await _loadThread(silent: true);
    } catch (error) {
      _showSnack(
        humanizeNetworkError(error, fallback: "Не удалось отправить сообщение"),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _assignToMe() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) {
      return;
    }

    setState(() {
      _isUpdatingThread = true;
    });

    try {
      final updated = await ref
          .read(supportRepositoryProvider)
          .updateThread(threadId: widget.threadId, assignedToId: user.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _thread = updated;
      });
      _showSnack("Чат назначен на вас");
    } catch (error) {
      _showSnack(
        humanizeNetworkError(error, fallback: "Не удалось назначить чат"),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingThread = false;
        });
      }
    }
  }

  Future<void> _changeStatus(String status) async {
    setState(() {
      _isUpdatingThread = true;
    });

    try {
      final updated = await ref
          .read(supportRepositoryProvider)
          .updateThread(threadId: widget.threadId, status: status);
      if (!mounted) {
        return;
      }
      setState(() {
        _thread = updated;
      });
    } catch (error) {
      _showSnack(
        humanizeNetworkError(error, fallback: "Не удалось обновить статус"),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingThread = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
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
    final authState = ref.watch(authControllerProvider);
    final currentUser = authState.user;
    final canAccessSupport = currentUser?.canAccessSupport ?? false;

    if (!authState.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text("Чат поддержки")),
        body: const AppEmptyState(
          title: "Нужен вход",
          message:
              "Авторизуйтесь, чтобы видеть историю обращений и переписку с поддержкой.",
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _thread == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Чат поддержки")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chat_bubble_outline),
                const SizedBox(height: 12),
                Text(_error ?? "Чат не найден"),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadThread,
                  child: const Text("Повторить"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final thread = _thread!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          thread.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: _loadThread,
            icon: const Icon(Icons.refresh),
            tooltip: "Обновить",
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          getSupportThreadCategoryLabel(thread.category),
                        ),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                      ),
                      Chip(
                        label: Text(getSupportThreadStatusLabel(thread.status)),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                      ),
                      if (thread.report != null)
                        Chip(
                          label: Text(
                            "Жалоба: ${getSupportReportReasonLabel(thread.report!.reason)}",
                          ),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Создал: ${thread.createdBy.displayName} · ${formatPostDate(thread.createdAt.toLocal())}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (thread.assignedTo != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      "Назначено: ${thread.assignedTo!.displayName}",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (canAccessSupport) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _isUpdatingThread ? null : _assignToMe,
                          icon: const Icon(Icons.assignment_ind_outlined),
                          label: const Text("Назначить себе"),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            initialValue: thread.status,
                            decoration: const InputDecoration(
                              labelText: "Статус чата",
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: "open",
                                child: Text("Открыт"),
                              ),
                              DropdownMenuItem(
                                value: "waiting_support",
                                child: Text("Ждёт поддержки"),
                              ),
                              DropdownMenuItem(
                                value: "waiting_user",
                                child: Text("Ждёт пользователя"),
                              ),
                              DropdownMenuItem(
                                value: "closed",
                                child: Text("Закрыт"),
                              ),
                            ],
                            onChanged: _isUpdatingThread
                                ? null
                                : (value) {
                                    if (value != null &&
                                        value != thread.status) {
                                      _changeStatus(value);
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: thread.messages.length,
                itemBuilder: (context, index) {
                  final message = thread.messages[index];
                  final isMine = currentUser?.id == message.author?.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 340),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isMine
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.author?.displayName.isNotEmpty == true
                                    ? message.author!.displayName
                                    : message.senderName,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                message.body,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(height: 1.45),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                formatPostDate(message.createdAt.toLocal()),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: "Сообщение",
                        hintText: "Напишите ответ или уточнение",
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isSending ? null : _sendMessage,
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
