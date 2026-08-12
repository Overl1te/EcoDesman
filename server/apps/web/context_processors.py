from apps.notifications.models import Notification


def web_shell(request):
    unread_count = 0
    if getattr(request, "user", None) and request.user.is_authenticated:
        unread_count = Notification.objects.filter(
            recipient=request.user,
            is_read=False,
        ).count()

    return {
        "web_app_name": "ЭкоВыхухоль",
        "web_unread_count": unread_count,
    }
