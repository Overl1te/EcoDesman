from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models

from apps.common.models import TimeStampedModel


class SupportThread(TimeStampedModel):
    class Category(models.TextChoices):
        GENERAL = "general", "General"
        ACCOUNT = "account", "Account"
        CONTENT = "content", "Content"
        MAP = "map", "Map"
        REPORT = "report", "Report"

    class Status(models.TextChoices):
        OPEN = "open", "Open"
        WAITING_SUPPORT = "waiting_support", "Waiting support"
        WAITING_USER = "waiting_user", "Waiting user"
        CLOSED = "closed", "Closed"

    subject = models.CharField(max_length=160)
    category = models.CharField(
        max_length=24,
        choices=Category.choices,
        default=Category.GENERAL,
    )
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="support_threads",
    )
    assigned_to = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        related_name="assigned_support_threads",
        null=True,
        blank=True,
    )
    status = models.CharField(
        max_length=24,
        choices=Status.choices,
        default=Status.WAITING_SUPPORT,
    )
    last_message_at = models.DateTimeField()
    last_message_preview = models.CharField(max_length=255, blank=True)
    unread_for_user_count = models.PositiveIntegerField(default=0)
    unread_for_support_count = models.PositiveIntegerField(default=0)
    is_bot_enabled = models.BooleanField(default=True)

    class Meta:
        ordering = ("-last_message_at", "-id")

    def __str__(self) -> str:
        return f"{self.subject} ({self.status})"


class SupportMessage(TimeStampedModel):
    class SenderType(models.TextChoices):
        USER = "user", "User"
        SUPPORT = "support", "Support"
        BOT = "bot", "Bot"
        SYSTEM = "system", "System"

    thread = models.ForeignKey(
        SupportThread,
        on_delete=models.CASCADE,
        related_name="messages",
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        related_name="support_messages",
        null=True,
        blank=True,
    )
    sender_type = models.CharField(max_length=16, choices=SenderType.choices)
    body = models.TextField()

    class Meta:
        ordering = ("created_at", "id")

    def __str__(self) -> str:
        return f"{self.sender_type} -> thread:{self.thread_id}"


class ContentReport(TimeStampedModel):
    class TargetType(models.TextChoices):
        POST = "post", "Post"
        COMMENT = "comment", "Comment"
        MAP_REVIEW = "map_review", "Map review"
        USER_MARKER = "user_marker", "User marker"
        USER_MARKER_COMMENT = "user_marker_comment", "User marker comment"

    class Reason(models.TextChoices):
        SPAM = "spam", "Spam"
        ABUSE = "abuse", "Abuse"
        MISINFORMATION = "misinformation", "Misinformation"
        DANGEROUS = "dangerous", "Dangerous content"
        COPYRIGHT = "copyright", "Copyright"
        OTHER = "other", "Other"

    class Status(models.TextChoices):
        NEW = "new", "New"
        IN_REVIEW = "in_review", "In review"
        RESOLVED = "resolved", "Resolved"
        REJECTED = "rejected", "Rejected"

    reporter = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="content_reports",
    )
    target_type = models.CharField(max_length=24, choices=TargetType.choices)
    post = models.ForeignKey(
        "posts.Post",
        on_delete=models.SET_NULL,
        related_name="reports",
        null=True,
        blank=True,
    )
    comment = models.ForeignKey(
        "posts.PostComment",
        on_delete=models.SET_NULL,
        related_name="reports",
        null=True,
        blank=True,
    )
    review = models.ForeignKey(
        "map_points.MapPointReview",
        on_delete=models.SET_NULL,
        related_name="reports",
        null=True,
        blank=True,
    )
    user_marker = models.ForeignKey(
        "map_points.UserMapMarker",
        on_delete=models.SET_NULL,
        related_name="reports",
        null=True,
        blank=True,
    )
    user_marker_comment = models.ForeignKey(
        "map_points.UserMapMarkerComment",
        on_delete=models.SET_NULL,
        related_name="reports",
        null=True,
        blank=True,
    )
    target_snapshot = models.CharField(max_length=255, blank=True)
    reason = models.CharField(max_length=32, choices=Reason.choices)
    details = models.TextField(blank=True)
    status = models.CharField(
        max_length=24,
        choices=Status.choices,
        default=Status.NEW,
    )
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        related_name="reviewed_content_reports",
        null=True,
        blank=True,
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    resolution_note = models.TextField(blank=True)
    support_thread = models.OneToOneField(
        SupportThread,
        on_delete=models.SET_NULL,
        related_name="linked_report",
        null=True,
        blank=True,
    )

    class Meta:
        ordering = ("-created_at", "-id")

    def clean(self) -> None:
        super().clean()
        mapping = {
            self.TargetType.POST: self.post_id,
            self.TargetType.COMMENT: self.comment_id,
            self.TargetType.MAP_REVIEW: self.review_id,
            self.TargetType.USER_MARKER: self.user_marker_id,
            self.TargetType.USER_MARKER_COMMENT: self.user_marker_comment_id,
        }
        provided_targets = [value for value in mapping.values() if value]
        if len(provided_targets) != 1:
            raise ValidationError("Report must reference exactly one target")
        if not mapping.get(self.target_type):
            raise ValidationError("Report target does not match target_type")

    def save(self, *args, **kwargs):
        self.full_clean()
        return super().save(*args, **kwargs)

    @property
    def target_id(self) -> int | None:
        if self.target_type == self.TargetType.POST:
            return self.post_id
        if self.target_type == self.TargetType.COMMENT:
            return self.comment_id
        if self.target_type == self.TargetType.MAP_REVIEW:
            return self.review_id
        if self.target_type == self.TargetType.USER_MARKER:
            return self.user_marker_id
        if self.target_type == self.TargetType.USER_MARKER_COMMENT:
            return self.user_marker_comment_id
        return None

    @property
    def target_label(self) -> str:
        if self.post:
            return self.post.title or f"Post #{self.post_id}"
        if self.comment:
            return self.comment.body[:80]
        if self.review:
            return self.review.body[:80]
        if self.user_marker:
            return self.user_marker.title
        if self.user_marker_comment:
            return self.user_marker_comment.body[:80]
        if self.target_snapshot:
            return self.target_snapshot
        return f"{self.get_target_type_display()} #{self.target_id or 'unknown'}"

    def __str__(self) -> str:
        return f"{self.target_type}:{self.target_id} ({self.status})"
