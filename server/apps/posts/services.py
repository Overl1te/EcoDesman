from django.db.models import F
from django.utils import timezone

from apps.notifications.models import Notification
from apps.notifications.services import create_notification
from apps.users.services import can_manage_posts

from .models import Post, PostComment, PostFavorite, PostImage, PostLike, PostView
from .slugs import build_unique_post_slug


def can_edit_post(user, post: Post) -> bool:
    return bool(
        user
        and user.is_authenticated
        and (post.author_id == user.id or can_manage_posts(user))
    )


def can_edit_comment(user, comment: PostComment) -> bool:
    return bool(
        user
        and user.is_authenticated
        and (comment.author_id == user.id or can_manage_posts(user))
    )


def sync_post_images(post: Post, image_urls: list[str]) -> None:
    PostImage.objects.filter(post=post).delete()
    PostImage.objects.bulk_create(
        [
            PostImage(post=post, image_url=image_url, position=index)
            for index, image_url in enumerate(image_urls)
        ]
    )


def _normalize_event_fields(validated_data: dict) -> dict:
    if validated_data.get("kind") != Post.Kind.EVENT:
        validated_data.setdefault("event_date", None)
        validated_data.setdefault("event_starts_at", None)
        validated_data.setdefault("event_ends_at", None)
        validated_data.setdefault("event_location", "")
        validated_data.setdefault("is_event_cancelled", False)
        validated_data.setdefault("event_cancelled_at", None)
        validated_data.setdefault("event_cancelled_by", None)
    elif "event_ends_at" not in validated_data and "event_starts_at" in validated_data:
        validated_data.setdefault("event_ends_at", validated_data["event_starts_at"])
    if validated_data.get("kind") == Post.Kind.EVENT:
        if validated_data.get("event_date") is None and validated_data.get("event_starts_at") is not None:
            validated_data["event_date"] = timezone.localdate(validated_data["event_starts_at"])
    return validated_data


def create_post(*, author, validated_data: dict) -> Post:
    image_urls = validated_data.pop("image_urls", [])
    validated_data = _normalize_event_fields(validated_data)
    validated_data["slug"] = build_unique_post_slug(
        title=validated_data.get("title", ""),
        body=validated_data.get("body", ""),
        slug_exists=lambda value: Post.objects.filter(author_id=author.id, slug=value).exists(),
    )
    post = Post.objects.create(author=author, **validated_data)
    sync_post_images(post, image_urls)
    return post


def update_post(*, post: Post, validated_data: dict) -> Post:
    image_urls = validated_data.pop("image_urls", None)
    validated_data = _normalize_event_fields(validated_data)
    refresh_slug = (
        "title" in validated_data
        or "body" in validated_data
        or not post.slug
    )
    for field, value in validated_data.items():
        setattr(post, field, value)
    if refresh_slug:
        post.slug = build_unique_post_slug(
            title=post.title,
            body=post.body,
            slug_exists=lambda value: Post.objects.filter(author_id=post.author_id, slug=value)
            .exclude(id=post.id)
            .exists(),
        )
    if post.kind != Post.Kind.EVENT:
        post.event_date = None
        post.event_starts_at = None
        post.event_ends_at = None
        post.event_location = ""
        post.is_event_cancelled = False
        post.event_cancelled_at = None
        post.event_cancelled_by = None
    elif post.event_starts_at and not post.event_ends_at:
        post.event_ends_at = post.event_starts_at
    if post.kind == Post.Kind.EVENT and post.event_date is None and post.event_starts_at:
        post.event_date = timezone.localdate(post.event_starts_at)
    post.save()
    if image_urls is not None:
        sync_post_images(post, image_urls)
    return post


def set_event_cancellation(*, post: Post, actor, is_cancelled: bool) -> Post:
    if post.kind != Post.Kind.EVENT:
        raise ValueError("Only event posts can be cancelled")

    post.is_event_cancelled = is_cancelled
    if is_cancelled:
        post.event_cancelled_at = timezone.now()
        post.event_cancelled_by = actor
    else:
        post.event_cancelled_at = None
        post.event_cancelled_by = None
    post.save(update_fields=[
        "is_event_cancelled",
        "event_cancelled_at",
        "event_cancelled_by",
        "updated_at",
    ])
    return post


def increment_post_view(post: Post, *, viewer=None) -> None:
    Post.objects.filter(id=post.id).update(view_count=F("view_count") + 1)
    if viewer and getattr(viewer, "is_authenticated", False):
        PostView.objects.get_or_create(post=post, user=viewer)


def like_post(*, post: Post, user) -> PostLike:
    like, created = PostLike.objects.get_or_create(post=post, user=user)
    if created:
        create_notification(
            recipient=post.author,
            actor=user,
            kind=Notification.Kind.POST_LIKED,
            title="Новый лайк",
            body=f"{user.display_name} оценил вашу публикацию",
            post=post,
        )
    return like


def unlike_post(*, post: Post, user) -> None:
    PostLike.objects.filter(post=post, user=user).delete()


def favorite_post(*, post: Post, user) -> PostFavorite:
    favorite, _ = PostFavorite.objects.get_or_create(post=post, user=user)
    return favorite


def unfavorite_post(*, post: Post, user) -> None:
    PostFavorite.objects.filter(post=post, user=user).delete()


def add_comment(*, post: Post, author, body: str) -> PostComment:
    comment = PostComment.objects.create(post=post, author=author, body=body)
    create_notification(
        recipient=post.author,
        actor=author,
        kind=Notification.Kind.POST_COMMENTED,
        title="Новый комментарий",
        body=f"{author.display_name} прокомментировал вашу публикацию",
        post=post,
        comment=comment,
    )
    return comment
