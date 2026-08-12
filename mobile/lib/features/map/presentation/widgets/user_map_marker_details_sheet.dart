import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../../core/network/error_message.dart";
import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../../feed/presentation/screens/post_images_viewer_screen.dart";
import "../../../support/data/repositories/support_repository_impl.dart";
import "../../../support/presentation/widgets/report_content_sheet.dart";
import "../../data/repositories/map_repository_impl.dart";
import "../../domain/models/user_map_marker_comment.dart";
import "../../domain/models/user_map_marker_detail.dart";
import "../controllers/map_controller.dart";

Future<void> showUserMapMarkerDetailsSheet(
  BuildContext context, {
  required int markerId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => UserMapMarkerDetailsSheet(markerId: markerId),
  );
}

class UserMapMarkerDetailsSheet extends ConsumerStatefulWidget {
  const UserMapMarkerDetailsSheet({super.key, required this.markerId});

  final int markerId;

  @override
  ConsumerState<UserMapMarkerDetailsSheet> createState() =>
      _UserMapMarkerDetailsSheetState();
}

class _UserMapMarkerDetailsSheetState
    extends ConsumerState<UserMapMarkerDetailsSheet> {
  bool _isSubmittingComment = false;

  Future<void> _openAddCommentSheet() async {
    final body = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _AddMarkerCommentSheet(),
    );

    if (!mounted || body == null) {
      return;
    }

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      await ref
          .read(mapRepositoryProvider)
          .createUserMarkerComment(markerId: widget.markerId, body: body);
      ref.invalidate(userMapMarkerDetailProvider(widget.markerId));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Комментарий добавлен.")));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            humanizeNetworkError(
              error,
              fallback: "Не удалось отправить комментарий",
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingComment = false;
        });
      }
    }
  }

  Future<void> _reportMarker(UserMapMarkerDetail marker) async {
    final input = await showSupportReportSheet(
      context,
      title: "Пожаловаться на метку",
      subtitle: "Жалоба попадёт в техподдержку и будет привязана к чату.",
    );
    if (!mounted || input == null) {
      return;
    }

    try {
      final report = await ref
          .read(supportRepositoryProvider)
          .createUserMarkerReport(
            markerId: marker.id,
            reason: input.reason,
            details: input.details,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Жалоба отправлена")));
      if (report.threadId != null) {
        context.push("/profile/support/thread/${report.threadId}");
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            humanizeNetworkError(
              error,
              fallback: "Не удалось отправить жалобу",
            ),
          ),
        ),
      );
    }
  }

  Future<void> _reportComment(UserMapMarkerComment comment) async {
    final input = await showSupportReportSheet(
      context,
      title: "Пожаловаться на комментарий",
      subtitle: "Жалоба попадёт в техподдержку и будет привязана к чату.",
    );
    if (!mounted || input == null) {
      return;
    }

    try {
      final report = await ref
          .read(supportRepositoryProvider)
          .createUserMarkerCommentReport(
            markerId: widget.markerId,
            commentId: comment.id,
            reason: input.reason,
            details: input.details,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Жалоба отправлена")));
      if (report.threadId != null) {
        context.push("/profile/support/thread/${report.threadId}");
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            humanizeNetworkError(
              error,
              fallback: "Не удалось отправить жалобу",
            ),
          ),
        ),
      );
    }
  }

  Future<void> _openExternal(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final markerAsync = ref.watch(userMapMarkerDetailProvider(widget.markerId));

    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.34,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: markerAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: FilledButton(
                    onPressed: () {
                      ref.invalidate(
                        userMapMarkerDetailProvider(widget.markerId),
                      );
                    },
                    child: const Text("Повторить загрузку"),
                  ),
                ),
              );
            },
            data: (marker) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          marker.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (!marker.isOwner && authState.isAuthenticated)
                        IconButton(
                          onPressed: () => _reportMarker(marker),
                          tooltip: "Пожаловаться",
                          icon: const Icon(Icons.flag_outlined),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    marker.description,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.person_outline, size: 18),
                        label: Text(
                          marker.author?.displayName ?? "Пользователь",
                        ),
                      ),
                      Chip(
                        avatar: const Icon(Icons.place_outlined, size: 18),
                        label: Text(
                          "${marker.latitude.toStringAsFixed(6)}, ${marker.longitude.toStringAsFixed(6)}",
                        ),
                      ),
                    ],
                  ),
                  if (marker.media.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 190,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: marker.media.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final media = marker.media[index];
                          final isVideo = media.mediaType == "video";
                          return GestureDetector(
                            onTap: () {
                              if (isVideo) {
                                _openExternal(media.mediaUrl);
                                return;
                              }
                              final imageUrls = [
                                for (final item in marker.media)
                                  if (item.mediaType != "video") item.mediaUrl,
                              ];
                              final imageIndex = imageUrls.indexOf(
                                media.mediaUrl,
                              );
                              openPostImagesViewer(
                                context,
                                imageUrls: imageUrls,
                                initialIndex: imageIndex < 0 ? 0 : imageIndex,
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Container(
                                width: 220,
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                child: isVideo
                                    ? const Center(
                                        child: Icon(
                                          Icons.play_circle_outline,
                                          size: 48,
                                        ),
                                      )
                                    : Image.network(
                                        media.mediaUrl,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Комментарии",
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _isSubmittingComment
                            ? null
                            : _openAddCommentSheet,
                        icon: const Icon(Icons.add_comment_outlined),
                        label: Text(
                          _isSubmittingComment ? "Отправляем..." : "Добавить",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (marker.comments.isEmpty)
                    Text(
                      "Комментариев пока нет.",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    for (final comment in marker.comments) ...[
                      _MarkerCommentCard(
                        comment: comment,
                        onReport: !comment.isOwner && authState.isAuthenticated
                            ? () => _reportComment(comment)
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _AddMarkerCommentSheet extends StatefulWidget {
  const _AddMarkerCommentSheet();

  @override
  State<_AddMarkerCommentSheet> createState() => _AddMarkerCommentSheetState();
}

class _AddMarkerCommentSheetState extends State<_AddMarkerCommentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _bodyController = TextEditingController();

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(_bodyController.text.trim());
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
              "Новый комментарий",
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _bodyController,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: "Комментарий",
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if ((value ?? "").trim().length < 2) {
                  return "Напишите комментарий";
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text("Отправить"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkerCommentCard extends StatelessWidget {
  const _MarkerCommentCard({required this.comment, this.onReport});

  final UserMapMarkerComment comment;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat("d MMMM yyyy", "ru");

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  comment.authorName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatter.format(comment.createdAt.toLocal()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (onReport != null)
                IconButton(
                  onPressed: onReport,
                  tooltip: "Пожаловаться",
                  icon: const Icon(Icons.flag_outlined, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment.body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
