from django.conf import settings
from django.db import models

from apps.common.models import TimeStampedModel


class MapPointCategory(TimeStampedModel):
    slug = models.SlugField(max_length=64, unique=True)
    title = models.CharField(max_length=80)
    sort_order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ("sort_order", "title", "id")
        verbose_name = "Map point category"
        verbose_name_plural = "Map point categories"

    def __str__(self) -> str:
        return self.title

    @property
    def priority(self) -> int:
        from .category_style import get_category_priority

        return get_category_priority(self)

    @property
    def marker_color(self) -> str:
        from .category_style import get_category_color

        return get_category_color(self)


class MapPoint(TimeStampedModel):
    slug = models.SlugField(max_length=64, unique=True)
    title = models.CharField(max_length=120)
    short_description = models.CharField(max_length=180, blank=True)
    description = models.TextField(blank=True)
    address = models.CharField(max_length=220, blank=True)
    working_hours = models.CharField(max_length=120, blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    is_active = models.BooleanField(default=True)
    sort_order = models.PositiveIntegerField(default=0)
    categories = models.ManyToManyField(
        MapPointCategory,
        related_name="points",
        blank=True,
    )

    class Meta:
        ordering = ("sort_order", "title", "id")

    def __str__(self) -> str:
        return self.title

    @property
    def ordered_categories(self):
        from .category_style import sort_categories

        return sort_categories(self.categories.all())

    @property
    def primary_category_display(self):
        categories = self.ordered_categories
        return categories[0] if categories else None


class MapPointImage(TimeStampedModel):
    point = models.ForeignKey(
        MapPoint,
        on_delete=models.CASCADE,
        related_name="images",
    )
    image_url = models.URLField()
    caption = models.CharField(max_length=140, blank=True)
    position = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ("position", "id")

    def __str__(self) -> str:
        return f"Image #{self.position} for point {self.point_id}"


class MapPointReview(TimeStampedModel):
    point = models.ForeignKey(
        MapPoint,
        on_delete=models.CASCADE,
        related_name="reviews",
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        related_name="map_point_reviews",
        blank=True,
        null=True,
    )
    author_name = models.CharField(max_length=120)
    rating = models.PositiveSmallIntegerField(default=5)
    body = models.TextField()

    class Meta:
        ordering = ("-created_at", "-id")

    def __str__(self) -> str:
        return f"Review by {self.author_name} for {self.point_id}"


class MapPointReviewImage(TimeStampedModel):
    review = models.ForeignKey(
        MapPointReview,
        on_delete=models.CASCADE,
        related_name="images",
    )
    image_url = models.URLField()
    caption = models.CharField(max_length=140, blank=True)
    position = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ("position", "id")

    def __str__(self) -> str:
        return f"Review image #{self.position} for review {self.review_id}"


class UserMapMarker(TimeStampedModel):
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        related_name="user_map_markers",
        blank=True,
        null=True,
    )
    title = models.CharField(max_length=140)
    description = models.TextField(blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    is_public = models.BooleanField(default=True)
    is_active = models.BooleanField(default=True)
    moderation_note = models.TextField(blank=True)

    class Meta:
        ordering = ("-created_at", "-id")
        verbose_name = "User map marker"
        verbose_name_plural = "User map markers"

    def __str__(self) -> str:
        return self.title


class UserMapMarkerMedia(TimeStampedModel):
    class MediaType(models.TextChoices):
        IMAGE = "image", "Image"
        VIDEO = "video", "Video"

    marker = models.ForeignKey(
        UserMapMarker,
        on_delete=models.CASCADE,
        related_name="media",
    )
    media_url = models.URLField()
    media_type = models.CharField(
        max_length=12,
        choices=MediaType.choices,
        default=MediaType.IMAGE,
    )
    caption = models.CharField(max_length=140, blank=True)
    position = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ("position", "id")

    def __str__(self) -> str:
        return f"{self.media_type} #{self.position} for marker {self.marker_id}"


class UserMapMarkerComment(TimeStampedModel):
    marker = models.ForeignKey(
        UserMapMarker,
        on_delete=models.CASCADE,
        related_name="comments",
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        related_name="user_map_marker_comments",
        blank=True,
        null=True,
    )
    author_name = models.CharField(max_length=120)
    body = models.TextField()

    class Meta:
        ordering = ("created_at", "id")

    def __str__(self) -> str:
        return f"Comment by {self.author_name} for marker {self.marker_id}"
