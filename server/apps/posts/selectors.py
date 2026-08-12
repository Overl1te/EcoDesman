from datetime import datetime, time, timedelta

from django.db.models import (
    BooleanField,
    Case,
    Count,
    Exists,
    F,
    IntegerField,
    OuterRef,
    Prefetch,
    Q,
    QuerySet,
    Value,
    When,
)
from django.db.models.expressions import ExpressionWrapper, Subquery
from django.db.models.functions import Coalesce
from django.utils import timezone

from .models import Post, PostComment, PostFavorite, PostImage, PostLike, PostView


def _with_post_annotations(queryset: QuerySet[Post], viewer) -> QuerySet[Post]:
    likes_count_subquery = (
        PostLike.objects.filter(post=OuterRef("pk"))
        .values("post")
        .annotate(total=Count("id"))
        .values("total")[:1]
    )
    comments_count_subquery = (
        PostComment.objects.filter(post=OuterRef("pk"))
        .values("post")
        .annotate(total=Count("id"))
        .values("total")[:1]
    )
    favorites_count_subquery = (
        PostFavorite.objects.filter(post=OuterRef("pk"))
        .values("post")
        .annotate(total=Count("id"))
        .values("total")[:1]
    )
    has_images_exists = PostImage.objects.filter(post=OuterRef("pk"))

    queryset = queryset.select_related("author").prefetch_related(
        "images",
        Prefetch(
            "comments",
            queryset=PostComment.objects.select_related("author").order_by("created_at", "id"),
        ),
    )
    queryset = queryset.annotate(
        likes_count=Coalesce(Subquery(likes_count_subquery, output_field=IntegerField()), 0),
        comments_count=Coalesce(Subquery(comments_count_subquery, output_field=IntegerField()), 0),
        favorites_count=Coalesce(Subquery(favorites_count_subquery, output_field=IntegerField()), 0),
        has_images=Exists(has_images_exists),
    )

    if viewer and getattr(viewer, "is_authenticated", False):
        return queryset.annotate(
            is_liked=Exists(PostLike.objects.filter(post=OuterRef("pk"), user=viewer)),
            is_favorited=Exists(PostFavorite.objects.filter(post=OuterRef("pk"), user=viewer)),
        )

    return queryset.annotate(
        is_liked=Value(False, output_field=BooleanField()),
        is_favorited=Value(False, output_field=BooleanField()),
    )


def _apply_search(queryset: QuerySet[Post], search: str | None) -> QuerySet[Post]:
    tokens = [item.strip() for item in (search or "").split() if item.strip()]
    for token in tokens:
        queryset = queryset.filter(
            Q(title__icontains=token)
            | Q(body__icontains=token)
            | Q(author__username__icontains=token)
            | Q(author__display_name__icontains=token)
            | Q(event_location__icontains=token)
        )
    return queryset


def _apply_event_scope(queryset: QuerySet[Post], event_scope: str | None) -> QuerySet[Post]:
    normalized_scope = (event_scope or "").strip().lower()
    if not normalized_scope or normalized_scope == "all":
        return queryset

    today = timezone.localdate()
    tomorrow = today + timedelta(days=1)
    week_end = today + timedelta(days=7)

    if normalized_scope == "today":
        return queryset.filter(event_date=today)
    if normalized_scope == "week":
        return queryset.filter(event_date__gte=today, event_date__lt=week_end)
    if normalized_scope == "upcoming":
        return queryset.filter(event_date__gte=today)
    return queryset


def _recommendation_subquery(model, *, viewer, group_field: str, outer_ref: str, exclude_self: bool = False):
    queryset = model.objects.filter(user=viewer)
    filter_kwargs = {group_field: OuterRef(outer_ref)}
    queryset = queryset.filter(**filter_kwargs)
    if exclude_self:
        queryset = queryset.exclude(post_id=OuterRef("pk"))
    return queryset.values(group_field).annotate(total=Count("id")).values("total")[:1]


def _recommendation_comment_subquery(*, viewer, group_field: str, outer_ref: str, exclude_self: bool = False):
    queryset = PostComment.objects.filter(author=viewer)
    filter_kwargs = {group_field: OuterRef(outer_ref)}
    queryset = queryset.filter(**filter_kwargs)
    if exclude_self:
        queryset = queryset.exclude(post_id=OuterRef("pk"))
    return queryset.values(group_field).annotate(total=Count("id")).values("total")[:1]


def _with_recommendation_annotations(queryset: QuerySet[Post], viewer) -> QuerySet[Post]:
    now = timezone.now()
    queryset = queryset.annotate(
        popularity_score=ExpressionWrapper(
            F("likes_count") * 6
            + F("comments_count") * 9
            + F("favorites_count") * 11
            + F("view_count"),
            output_field=IntegerField(),
        ),
        freshness_score=Case(
            When(published_at__gte=now - timedelta(days=2), then=Value(72)),
            When(published_at__gte=now - timedelta(days=7), then=Value(48)),
            When(published_at__gte=now - timedelta(days=30), then=Value(24)),
            default=Value(8),
            output_field=IntegerField(),
        ),
        event_score=Case(
            When(kind=Post.Kind.EVENT, is_event_cancelled=True, then=Value(-18)),
            When(kind=Post.Kind.EVENT, event_date__gte=timezone.localdate(), then=Value(24)),
            When(kind=Post.Kind.EVENT, event_date__lt=timezone.localdate(), then=Value(-12)),
            default=Value(0),
            output_field=IntegerField(),
        ),
        image_score=Case(
            When(has_images=True, then=Value(8)),
            default=Value(0),
            output_field=IntegerField(),
        ),
    )

    if viewer and getattr(viewer, "is_authenticated", False):
        city = (getattr(viewer, "city", "") or "").strip()
        queryset = queryset.annotate(
            author_like_affinity=Coalesce(
                Subquery(
                    _recommendation_subquery(
                        PostLike,
                        viewer=viewer,
                        group_field="post__author_id",
                        outer_ref="author_id",
                        exclude_self=True,
                    ),
                    output_field=IntegerField(),
                ),
                0,
            ),
            author_favorite_affinity=Coalesce(
                Subquery(
                    _recommendation_subquery(
                        PostFavorite,
                        viewer=viewer,
                        group_field="post__author_id",
                        outer_ref="author_id",
                        exclude_self=True,
                    ),
                    output_field=IntegerField(),
                ),
                0,
            ),
            author_comment_affinity=Coalesce(
                Subquery(
                    _recommendation_comment_subquery(
                        viewer=viewer,
                        group_field="post__author_id",
                        outer_ref="author_id",
                        exclude_self=True,
                    ),
                    output_field=IntegerField(),
                ),
                0,
            ),
            author_view_affinity=Coalesce(
                Subquery(
                    _recommendation_subquery(
                        PostView,
                        viewer=viewer,
                        group_field="post__author_id",
                        outer_ref="author_id",
                        exclude_self=True,
                    ),
                    output_field=IntegerField(),
                ),
                0,
            ),
            kind_like_affinity=Coalesce(
                Subquery(
                    _recommendation_subquery(
                        PostLike,
                        viewer=viewer,
                        group_field="post__kind",
                        outer_ref="kind",
                        exclude_self=True,
                    ),
                    output_field=IntegerField(),
                ),
                0,
            ),
            kind_favorite_affinity=Coalesce(
                Subquery(
                    _recommendation_subquery(
                        PostFavorite,
                        viewer=viewer,
                        group_field="post__kind",
                        outer_ref="kind",
                        exclude_self=True,
                    ),
                    output_field=IntegerField(),
                ),
                0,
            ),
            kind_comment_affinity=Coalesce(
                Subquery(
                    _recommendation_comment_subquery(
                        viewer=viewer,
                        group_field="post__kind",
                        outer_ref="kind",
                        exclude_self=True,
                    ),
                    output_field=IntegerField(),
                ),
                0,
            ),
            kind_view_affinity=Coalesce(
                Subquery(
                    _recommendation_subquery(
                        PostView,
                        viewer=viewer,
                        group_field="post__kind",
                        outer_ref="kind",
                        exclude_self=True,
                    ),
                    output_field=IntegerField(),
                ),
                0,
            ),
            has_viewed=Exists(PostView.objects.filter(post=OuterRef("pk"), user=viewer)),
        )
        queryset = queryset.annotate(
            city_match_score=(
                Case(
                    When(
                        kind=Post.Kind.EVENT,
                        event_location__icontains=city,
                        then=Value(12),
                    ),
                    default=Value(0),
                    output_field=IntegerField(),
                )
                if city
                else Value(0, output_field=IntegerField())
            ),
            seen_penalty=Case(
                When(has_viewed=True, then=Value(-10)),
                default=Value(0),
                output_field=IntegerField(),
            ),
            own_post_penalty=Case(
                When(author_id=viewer.id, then=Value(-18)),
                default=Value(0),
                output_field=IntegerField(),
            ),
        )
        queryset = queryset.annotate(
            personal_score=ExpressionWrapper(
                F("author_like_affinity") * 16
                + F("author_favorite_affinity") * 22
                + F("author_comment_affinity") * 12
                + F("author_view_affinity") * 7
                + F("kind_like_affinity") * 8
                + F("kind_favorite_affinity") * 10
                + F("kind_comment_affinity") * 6
                + F("kind_view_affinity") * 4,
                output_field=IntegerField(),
            ),
        )
    else:
        queryset = queryset.annotate(
            author_like_affinity=Value(0, output_field=IntegerField()),
            author_favorite_affinity=Value(0, output_field=IntegerField()),
            author_comment_affinity=Value(0, output_field=IntegerField()),
            author_view_affinity=Value(0, output_field=IntegerField()),
            kind_like_affinity=Value(0, output_field=IntegerField()),
            kind_favorite_affinity=Value(0, output_field=IntegerField()),
            kind_comment_affinity=Value(0, output_field=IntegerField()),
            kind_view_affinity=Value(0, output_field=IntegerField()),
            has_viewed=Value(False, output_field=BooleanField()),
            city_match_score=Value(0, output_field=IntegerField()),
            seen_penalty=Value(0, output_field=IntegerField()),
            own_post_penalty=Value(0, output_field=IntegerField()),
            personal_score=Value(0, output_field=IntegerField()),
        )

    return queryset.annotate(
        recommendation_score=ExpressionWrapper(
            F("popularity_score")
            + F("freshness_score")
            + F("event_score")
            + F("image_score")
            + F("personal_score")
            + F("city_match_score")
            + F("seen_penalty")
            + F("own_post_penalty"),
            output_field=IntegerField(),
        )
    )


def list_event_calendar_posts(*, start_date, end_date, viewer=None) -> QuerySet[Post]:
    queryset = (
        Post.objects.filter(
            is_published=True,
            kind=Post.Kind.EVENT,
            event_date__gte=start_date,
            event_date__lte=end_date,
        )
        .select_related("author")
        .prefetch_related("images")
        .order_by("event_date", "event_starts_at", "id")
    )
    return _with_post_annotations(queryset, viewer)


def list_posts(
    *,
    viewer=None,
    author_id: int | None = None,
    search: str | None = None,
    kind: str | None = None,
    ordering: str | None = None,
    has_images: bool = False,
    favorites_only: bool = False,
    event_scope: str | None = None,
) -> QuerySet[Post]:
    queryset = Post.objects.all()

    if author_id is not None:
        queryset = queryset.filter(author_id=author_id)

    if kind:
        queryset = queryset.filter(kind=kind)

    queryset = _apply_search(queryset, search)

    if has_images:
        queryset = queryset.annotate(_has_images_filter=Exists(PostImage.objects.filter(post=OuterRef("pk")))).filter(
            _has_images_filter=True
        )

    if favorites_only:
        if not viewer or not getattr(viewer, "is_authenticated", False):
            return Post.objects.none()
        queryset = queryset.filter(favorites__user=viewer)

    can_view_unpublished = bool(
        viewer
        and getattr(viewer, "is_authenticated", False)
        and (
            getattr(viewer, "is_post_manager", False)
            or (author_id is not None and viewer.id == author_id)
        )
    )
    if not can_view_unpublished:
        queryset = queryset.filter(is_published=True)

    if kind == Post.Kind.EVENT or event_scope:
        queryset = queryset.filter(kind=Post.Kind.EVENT)
        queryset = _apply_event_scope(queryset, event_scope)

    queryset = _with_post_annotations(queryset.distinct(), viewer)

    normalized_ordering = (ordering or "recent").strip().lower()
    if normalized_ordering == "recommended":
        queryset = _with_recommendation_annotations(queryset, viewer)
        return queryset.order_by("-recommendation_score", "-popularity_score", "-published_at", "-id")

    if normalized_ordering == "popular":
        return queryset.order_by(
            "-likes_count",
            "-comments_count",
            "-favorites_count",
            "-view_count",
            "-published_at",
            "-id",
        )

    if kind == Post.Kind.EVENT and (event_scope or "").strip().lower() in {"today", "week", "upcoming"}:
        return queryset.order_by("event_starts_at", "-published_at", "-id")

    return queryset.order_by("-published_at", "-id")


def get_post(post_id: int, *, viewer=None) -> QuerySet[Post]:
    queryset = Post.objects.filter(id=post_id)
    can_view_unpublished = bool(
        viewer
        and getattr(viewer, "is_authenticated", False)
        and (
            getattr(viewer, "is_post_manager", False)
            or queryset.filter(author_id=viewer.id).exists()
        )
    )
    if not can_view_unpublished:
        queryset = queryset.filter(is_published=True)

    return _with_post_annotations(queryset, viewer).order_by("-published_at", "-id")


def get_post_by_author_username_and_slug(
    username: str,
    post_slug: str,
    *,
    viewer=None,
) -> QuerySet[Post]:
    queryset = Post.objects.filter(
        author__username__iexact=(username or "").strip(),
        slug=(post_slug or "").strip().lower(),
    )
    can_view_unpublished = bool(
        viewer
        and getattr(viewer, "is_authenticated", False)
        and (
            getattr(viewer, "is_post_manager", False)
            or queryset.filter(author_id=viewer.id).exists()
        )
    )
    if not can_view_unpublished:
        queryset = queryset.filter(is_published=True)

    return _with_post_annotations(queryset, viewer).order_by("-published_at", "-id")


def list_comments(post_id: int) -> QuerySet[PostComment]:
    return PostComment.objects.filter(post_id=post_id).select_related("author", "post")
