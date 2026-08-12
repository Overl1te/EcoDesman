import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../../../core/network/error_message.dart";
import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../../feed/presentation/screens/post_images_viewer_screen.dart";
import "../../../support/data/repositories/support_repository_impl.dart";
import "../../../support/presentation/widgets/report_content_sheet.dart";
import "../../data/repositories/map_repository_impl.dart";
import "../../domain/models/eco_map_category.dart";
import "../../domain/models/eco_map_point_detail.dart";
import "../../domain/models/eco_map_point_review.dart";
import "../controllers/map_controller.dart";
import "../map_point_style.dart";

Future<void> showMapPointDetailsSheet(
  BuildContext context, {
  required int pointId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MapPointDetailsSheet(pointId: pointId),
  );
}

class MapPointDetailsSheet extends ConsumerStatefulWidget {
  const MapPointDetailsSheet({super.key, required this.pointId});

  final int pointId;

  @override
  ConsumerState<MapPointDetailsSheet> createState() =>
      _MapPointDetailsSheetState();
}

class _MapPointDetailsSheetState extends ConsumerState<MapPointDetailsSheet> {
  int _currentImageIndex = 0;
  bool _isSubmittingReview = false;

  Future<void> _openAddReviewSheet() async {
    final payload = await showModalBottomSheet<_NewReviewPayload>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _AddReviewSheet(),
    );

    if (!mounted || payload == null) {
      return;
    }

    setState(() {
      _isSubmittingReview = true;
    });

    try {
      await ref
          .read(mapRepositoryProvider)
          .createReview(
            pointId: widget.pointId,
            rating: payload.rating,
            body: payload.body,
          );
      ref.invalidate(mapPointDetailProvider(widget.pointId));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Отзыв добавлен.")));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            humanizeNetworkError(error, fallback: "Не удалось отправить отзыв"),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingReview = false;
        });
      }
    }
  }

  Future<void> _reportReview(EcoMapPointReview review) async {
    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Войдите, чтобы отправить жалобу")),
      );
      return;
    }

    final input = await showSupportReportSheet(
      context,
      title: "Пожаловаться на отзыв",
      subtitle:
          "Жалоба попадёт в техподдержку и будет привязана к отдельному чату.",
    );
    if (!mounted || input == null) {
      return;
    }

    try {
      final report = await ref
          .read(supportRepositoryProvider)
          .createMapReviewReport(
            pointId: widget.pointId,
            reviewId: review.id,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detailAsync = ref.watch(mapPointDetailProvider(widget.pointId));

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
          child: detailAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) {
              return _SheetErrorState(
                onRetry: () =>
                    ref.refresh(mapPointDetailProvider(widget.pointId)),
              );
            },
            data: (point) {
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
                  Text(
                    point.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (point.shortDescription.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      point.shortDescription,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                  if (point.categories.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in point.categories)
                          _CategoryPill(category: category),
                      ],
                    ),
                  ],
                  if (point.images.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 240,
                      child: PageView.builder(
                        itemCount: point.images.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentImageIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final image = point.images[index];
                          return GestureDetector(
                            onTap: () => openPostImagesViewer(
                              context,
                              imageUrls: [
                                for (final item in point.images) item.imageUrl,
                              ],
                              initialIndex: index,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    image.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                          size: 40,
                                        ),
                                      );
                                    },
                                  ),
                                  Positioned(
                                    left: 14,
                                    right: 14,
                                    bottom: 14,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.48,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        image.caption.isNotEmpty
                                            ? image.caption
                                            : "Фотография точки",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (point.images.length > 1) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (
                            var index = 0;
                            index < point.images.length;
                            index++
                          )
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: index == _currentImageIndex ? 22 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: index == _currentImageIndex
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                  const SizedBox(height: 22),
                  _PointMetaGrid(point: point),
                  if (point.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text(
                      "Описание",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      point.description,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Отзывы",
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _isSubmittingReview
                            ? null
                            : _openAddReviewSheet,
                        icon: const Icon(Icons.rate_review_outlined),
                        label: Text(
                          _isSubmittingReview
                              ? "Отправляем..."
                              : "Добавить отзыв",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (point.reviews.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        "Пока отзывов нет.",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (final review in point.reviews) ...[
                          _ReviewCard(
                            review: review,
                            onReport: !review.isOwner
                                ? () => _reportReview(review)
                                : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _NewReviewPayload {
  const _NewReviewPayload({required this.rating, required this.body});

  final int rating;
  final String body;
}

class _AddReviewSheet extends StatefulWidget {
  const _AddReviewSheet();

  @override
  State<_AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<_AddReviewSheet> {
  final _formKey = GlobalKey<FormState>();
  final _bodyController = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _NewReviewPayload(rating: _rating, body: _bodyController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              "Новый отзыв",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Оцените место и коротко расскажите, чем оно вам запомнилось.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "Оценка",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (var index = 1; index <= 5; index++)
                  ChoiceChip(
                    label: Text("$index"),
                    selected: _rating == index,
                    onSelected: (_) {
                      setState(() {
                        _rating = index;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _bodyController,
              minLines: 4,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: "Текст отзыва",
                hintText:
                    "Например: тихое место, удобный маршрут, хорошие виды",
                alignLabelWithHint: true,
              ),
              validator: (value) {
                final text = value?.trim() ?? "";
                if (text.length < 3) {
                  return "Напишите хотя бы пару слов";
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text("Отправить отзыв"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointMetaGrid extends StatelessWidget {
  const _PointMetaGrid({required this.point});

  final EcoMapPointDetail point;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (point.address.trim().isNotEmpty)
          _MetaCard(
            icon: Icons.place_outlined,
            title: "Адрес",
            value: point.address,
          ),
        if (point.workingHours.trim().isNotEmpty)
          _MetaCard(
            icon: Icons.schedule_outlined,
            title: "Режим работы",
            value: point.workingHours,
          ),
        _MetaCard(
          icon: Icons.explore_outlined,
          title: "Координаты",
          value:
              "${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}",
        ),
      ],
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});

  final EcoMapCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appearance = getMapPointAppearance(category);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: appearance.haloColor,
        border: Border.all(color: appearance.color.withValues(alpha: 0.36)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: appearance.color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            category.title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: appearance.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, this.onReport});

  final EcoMapPointReview review;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat("d MMMM yyyy", "ru");

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.authorName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatter.format(review.createdAt.toLocal()),
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
          Row(
            children: [
              for (var index = 0; index < 5; index++)
                Icon(
                  index < review.rating
                      ? Icons.star_rounded
                      : Icons.star_border,
                  size: 18,
                  color: const Color(0xFFF3B63F),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _SheetErrorState extends StatelessWidget {
  const _SheetErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 42,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              "Не удалось открыть точку",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Попробуйте загрузить данные еще раз.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text("Повторить")),
          ],
        ),
      ),
    );
  }
}
