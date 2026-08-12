from django.db.models import Count, QuerySet

from .models import Notification


def list_notifications(user) -> QuerySet[Notification]:
    return (
        Notification.objects.filter(recipient=user)
        .select_related("actor", "post", "post__author", "comment", "support_thread", "report")
        .annotate(unread_count=Count("recipient__notifications"))
    )
