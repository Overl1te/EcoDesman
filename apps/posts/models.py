from django.conf import settings
from django.db import models
from django.utils import timezone

from apps.common.models import TimeStampedModel

from .slugs import build_unique_post_slug


class Post(TimeStampedModel):
    class Kind(models.TextChoices):
        NEWS = "news", "News"
        EVENT = "event", "Event"
        STORY = "story", "Story"

    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="posts",
    )
    slug = models.SlugField(max_length=220, blank=True)
    title = models.CharField(max_length=160, blank=True)
    body = models.TextField()
    kind = models.CharField(
        max_length=24,
        choices=Kind.choices,
        default=Kind.NEWS,
    )
    published_at = models.DateTimeField(default=timezone.now)
    is_published = models.BooleanField(default=True)
    view_count = models.PositiveIntegerField(default=0)
    event_date = models.DateField(null=True, blank=True)
    event_starts_at = models.DateTimeField(null=True, blank=True)
    event_ends_at = models.DateTimeField(null=True, blank=True)
    event_location = models.CharField(max_length=200, blank=True)
    is_event_cancelled = models.BooleanField(default=False)
    event_cancelled_at = models.DateTimeField(null=True, blank=True)
    event_cancelled_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        related_name="cancelled_event_posts",
        null=True,
        blank=True,
    )

    class Meta:
        ordering = ("-published_at", "-id")
        constraints = [
            models.UniqueConstraint(
                fields=("author", "slug"),
                name="unique_post_slug_per_author",
            ),
        ]

    def __str__(self) -> str:
        return self.title or self.body[:40]

    def _generate_slug(self) -> str:
        queryset = type(self).objects.filter(author_id=self.author_id)
        if self.pk:
            queryset = queryset.exclude(pk=self.pk)

        return build_unique_post_slug(
            title=self.title,
            body=self.body,
            slug_exists=lambda value: queryset.filter(slug=value).exists(),
        )

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = self._generate_slug()
        if self.kind == self.Kind.EVENT:
            if self.event_date is None and self.event_starts_at is not None:
                self.event_date = timezone.localdate(self.event_starts_at)
            if self.event_starts_at is not None and self.event_ends_at is None:
                self.event_ends_at = self.event_starts_at
        else:
            self.event_date = None
            self.event_starts_at = None
            self.event_ends_at = None
            self.event_location = ""
            self.is_event_cancelled = False
            self.event_cancelled_at = None
            self.event_cancelled_by = None
        super().save(*args, **kwargs)


class PostImage(TimeStampedModel):
    post = models.ForeignKey(
        Post,
        on_delete=models.CASCADE,
        related_name="images",
    )
    image_url = models.URLField()
    position = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ("position", "id")

    def __str__(self) -> str:
        return f"Image #{self.position} for post {self.post_id}"


class PostLike(TimeStampedModel):
    post = models.ForeignKey(
        Post,
        on_delete=models.CASCADE,
        related_name="likes",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="post_likes",
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=("post", "user"), name="unique_post_like"),
        ]
        ordering = ("-created_at", "-id")


class PostFavorite(TimeStampedModel):
    post = models.ForeignKey(
        Post,
        on_delete=models.CASCADE,
        related_name="favorites",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="post_favorites",
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=("post", "user"), name="unique_post_favorite"),
        ]
        ordering = ("-created_at", "-id")


class PostView(TimeStampedModel):
    post = models.ForeignKey(
        Post,
        on_delete=models.CASCADE,
        related_name="view_records",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="post_views",
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=("post", "user"), name="unique_post_view"),
        ]
        ordering = ("-updated_at", "-id")


class PostComment(TimeStampedModel):
    post = models.ForeignKey(
        Post,
        on_delete=models.CASCADE,
        related_name="comments",
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="post_comments",
    )
    body = models.TextField()

    class Meta:
        ordering = ("created_at", "id")
