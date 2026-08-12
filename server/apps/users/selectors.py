from django.db.models import Q, QuerySet, Sum

from apps.posts.models import Post, PostLike

from .models import User


def _visible_posts_for_profile(user: User, viewer=None) -> QuerySet[Post]:
    queryset = user.posts.all()
    can_view_unpublished = bool(
        viewer
        and getattr(viewer, "is_authenticated", False)
        and (getattr(viewer, "is_post_manager", False) or viewer.id == user.id)
    )
    if not can_view_unpublished:
        queryset = queryset.filter(is_published=True)
    return queryset


def get_profile_stats(user: User, viewer=None) -> dict[str, int]:
    visible_posts = _visible_posts_for_profile(user, viewer=viewer)
    views_received = visible_posts.aggregate(total=Sum("view_count")).get("total") or 0

    return {
        "posts_count": visible_posts.count(),
        "likes_given_count": user.post_likes.count(),
        "likes_received_count": PostLike.objects.filter(post__in=visible_posts).count(),
        "comments_count": user.post_comments.count(),
        "views_received_count": views_received,
    }


def search_users(query: str | None = None) -> QuerySet[User]:
    queryset = User.objects.all().order_by("username", "id")
    normalized = (query or "").strip()
    if normalized:
        queryset = queryset.filter(
            Q(username__icontains=normalized)
            | Q(display_name__icontains=normalized)
        )
    return queryset
