import "package:flutter/material.dart";

import "../../../../core/utils/date_formatter.dart";
import "../../../../shared/widgets/remote_avatar.dart";
import "../../domain/models/feed_post.dart";
import "../screens/post_images_viewer_screen.dart";

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onAuthorTap,
    this.onLikeTap,
    this.onFavoriteTap,
  });

  final FeedPost post;
  final VoidCallback onTap;
  final VoidCallback onAuthorTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: onAuthorTap,
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: RemoteAvatar(
                        imageUrl: post.author.avatarUrl,
                        fallbackLabel: post.author.displayName,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: onAuthorTap,
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.author.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatPostDate(post.publishedAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (post.author.statusText.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              post.author.statusText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Chip(
                        label: Text(_kindLabel(post.kind)),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                      ),
                      if (post.isEvent && post.isEventCancelled)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Chip(
                            label: const Text("Отменено"),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: theme.colorScheme.errorContainer,
                            labelStyle: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w700,
                            ),
                            side: BorderSide.none,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (post.title.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  post.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              if (post.isEvent) ...[
                const SizedBox(height: 12),
                _EventSummary(post: post),
              ],
              const SizedBox(height: 12),
              Text(
                post.previewText.isNotEmpty ? post.previewText : post.body,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
              if (post.previewImageUrl != null &&
                  post.previewImageUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => openPostImagesViewer(
                    context,
                    imageUrls: [post.previewImageUrl!],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      post.previewImageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 220,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 220,
                          color: theme.colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        );
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _PostMetric(
                    icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                    value: post.likesCount,
                    color: post.isLiked ? theme.colorScheme.error : null,
                    onTap: onLikeTap,
                  ),
                  _PostMetric(
                    icon: post.isFavorited
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    value: post.favoritesCount,
                    color: post.isFavorited ? theme.colorScheme.primary : null,
                    onTap: onFavoriteTap,
                  ),
                  _PostMetric(
                    icon: Icons.chat_bubble_outline,
                    value: post.commentsCount,
                  ),
                  _PostMetric(
                    icon: Icons.visibility_outlined,
                    value: post.viewCount,
                  ),
                  if (post.canEdit)
                    Text(
                      "Можно редактировать",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case "event":
        return "Мероприятие";
      case "story":
        return "История";
      default:
        return "Новость";
    }
  }
}

class _EventSummary extends StatelessWidget {
  const _EventSummary({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: post.isEventCancelled
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.6)
            : theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                post.isEventCancelled
                    ? Icons.event_busy_outlined
                    : Icons.event_available_outlined,
                size: 18,
                color: post.isEventCancelled
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formatEventDay(post.eventDate ?? post.eventStartsAt),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: post.isEventCancelled
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          if (post.eventStartsAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 18,
                  color: post.isEventCancelled
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    formatEventRange(post.eventStartsAt, post.eventEndsAt),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: post.isEventCancelled
                          ? theme.colorScheme.onErrorContainer
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (post.eventLocation.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 18,
                  color: post.isEventCancelled
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    post.eventLocation,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: post.isEventCancelled
                          ? theme.colorScheme.onErrorContainer
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (post.isEventCancelled && post.eventCancelledAt != null) ...[
            const SizedBox(height: 8),
            Text(
              "Отменено ${formatPostDate(post.eventCancelledAt!)}",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PostMetric extends StatelessWidget {
  const _PostMetric({
    required this.icon,
    required this.value,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final int value;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: color ?? theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          "$value",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color ?? theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: content,
      ),
    );
  }
}
