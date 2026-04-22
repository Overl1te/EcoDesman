from django.db.models import Q
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from apps.notifications.models import Notification
from apps.notifications.services import create_notification
from apps.users.models import User

from .models import ContentReport, SupportMessage, SupportThread
from .selectors import SUPPORT_KNOWLEDGE_BASE, match_support_article


def can_access_support_center(user) -> bool:
    return bool(user and user.is_authenticated and user.can_access_support)


def list_support_staff():
    return (
        User.objects.filter(
            Q(role=User.Role.SUPPORT) | Q(role=User.Role.ADMIN) | Q(is_superuser=True),
            is_active=True,
        )
        .distinct()
    )


def build_thread_preview(body: str) -> str:
    return " ".join(body.strip().split())[:255]


def sync_thread_after_automated_message(
    *,
    thread: SupportThread,
    message: SupportMessage,
    unread_for_user_delta: int = 0,
    unread_for_support_delta: int = 0,
) -> None:
    thread.last_message_at = message.created_at or timezone.now()
    thread.last_message_preview = build_thread_preview(message.body)
    thread.unread_for_user_count = max(0, thread.unread_for_user_count + unread_for_user_delta)
    thread.unread_for_support_count = max(
        0,
        thread.unread_for_support_count + unread_for_support_delta,
    )
    thread.save(
        update_fields=[
            "last_message_at",
            "last_message_preview",
            "unread_for_user_count",
            "unread_for_support_count",
            "updated_at",
        ]
    )


def append_automated_message(
    *,
    thread: SupportThread,
    body: str,
    sender_type: str,
    unread_for_user_delta: int = 0,
    unread_for_support_delta: int = 0,
) -> SupportMessage:
    message = SupportMessage.objects.create(
        thread=thread,
        author=None,
        sender_type=sender_type,
        body=body.strip(),
    )
    sync_thread_after_automated_message(
        thread=thread,
        message=message,
        unread_for_user_delta=unread_for_user_delta,
        unread_for_support_delta=unread_for_support_delta,
    )
    return message


def maybe_append_bot_reply(*, thread: SupportThread, query: str) -> SupportMessage | None:
    if not thread.is_bot_enabled or thread.status == SupportThread.Status.CLOSED:
        return None

    reply = build_bot_reply(query)
    if not reply["matched_article"]:
        return None

    return append_automated_message(
        thread=thread,
        body=reply["reply"],
        sender_type=SupportMessage.SenderType.BOT,
    )


def close_support_thread(*, thread: SupportThread, actor=None, reason: str | None = None) -> SupportThread:
    if thread.status == SupportThread.Status.CLOSED:
        return thread

    thread.status = SupportThread.Status.CLOSED
    thread.save(update_fields=["status", "updated_at"])

    message = append_automated_message(
        thread=thread,
        body=reason or "Чат закрыт. Новые сообщения в этот тред больше отправить нельзя.",
        sender_type=SupportMessage.SenderType.SYSTEM,
        unread_for_user_delta=1,
    )

    if actor and thread.created_by_id != getattr(actor, "id", None):
        create_notification(
            recipient=thread.created_by,
            actor=actor,
            kind=Notification.Kind.SUPPORT_MESSAGE_RECEIVED,
            title="Чат поддержки закрыт",
            body=build_thread_preview(message.body),
            support_thread=thread,
        )

    return thread


def notify_support_team(*, actor, kind: str, title: str, body: str, support_thread=None, report=None):
    if not actor:
        return

    for staff_user in list_support_staff():
        create_notification(
            recipient=staff_user,
            actor=actor,
            kind=kind,
            title=title,
            body=body,
            support_thread=support_thread,
            report=report,
        )


def create_support_thread(*, created_by, subject: str, body: str, category: str) -> SupportThread:
    cleaned_subject = subject.strip()
    cleaned_body = body.strip()
    thread = SupportThread.objects.create(
        subject=cleaned_subject,
        category=category or SupportThread.Category.GENERAL,
        created_by=created_by,
        status=SupportThread.Status.WAITING_SUPPORT,
        last_message_at=timezone.now(),
        last_message_preview=build_thread_preview(cleaned_body),
        unread_for_support_count=1,
    )
    message = SupportMessage.objects.create(
        thread=thread,
        author=created_by,
        sender_type=SupportMessage.SenderType.USER,
        body=cleaned_body,
    )
    thread.last_message_at = message.created_at or timezone.now()
    thread.save(update_fields=["last_message_at", "updated_at"])
    maybe_append_bot_reply(thread=thread, query=f"{cleaned_subject}\n{cleaned_body}")

    notify_support_team(
        actor=created_by,
        kind=Notification.Kind.SUPPORT_THREAD_CREATED,
        title="Новое обращение в поддержку",
        body=f"{created_by.display_name or created_by.username}: {cleaned_subject}",
        support_thread=thread,
    )
    return thread


def append_support_message(*, thread: SupportThread, author, body: str, as_support: bool) -> SupportMessage:
    if thread.status == SupportThread.Status.CLOSED:
        raise ValidationError("Чат закрыт. Отправка новых сообщений недоступна.")

    cleaned_body = body.strip()
    message = SupportMessage.objects.create(
        thread=thread,
        author=author,
        sender_type=(
            SupportMessage.SenderType.SUPPORT if as_support else SupportMessage.SenderType.USER
        ),
        body=cleaned_body,
    )

    thread.last_message_at = message.created_at or timezone.now()
    thread.last_message_preview = build_thread_preview(cleaned_body)
    update_fields = ["last_message_at", "last_message_preview", "updated_at"]

    if as_support:
        if thread.status != SupportThread.Status.CLOSED:
            thread.status = SupportThread.Status.WAITING_USER
            update_fields.append("status")
        if not thread.assigned_to_id:
            thread.assigned_to = author
            update_fields.append("assigned_to")
        thread.unread_for_user_count += 1
        thread.unread_for_support_count = 0
        update_fields.extend(["unread_for_user_count", "unread_for_support_count"])
        thread.save(update_fields=update_fields)

        create_notification(
            recipient=thread.created_by,
            actor=author,
            kind=Notification.Kind.SUPPORT_MESSAGE_RECEIVED,
            title="Ответ поддержки",
            body=f"{author.display_name or author.username} ответил в чате поддержки",
            support_thread=thread,
        )
        return message

    thread.status = SupportThread.Status.WAITING_SUPPORT
    thread.unread_for_support_count += 1
    thread.unread_for_user_count = 0
    update_fields.extend(["status", "unread_for_support_count", "unread_for_user_count"])
    thread.save(update_fields=update_fields)

    maybe_append_bot_reply(thread=thread, query=cleaned_body)

    notify_support_team(
        actor=author,
        kind=Notification.Kind.SUPPORT_MESSAGE_RECEIVED,
        title="Новое сообщение в поддержке",
        body=f"{author.display_name or author.username} написал в чате «{thread.subject}»",
        support_thread=thread,
    )
    return message


def mark_thread_read(*, thread: SupportThread, viewer) -> None:
    if viewer.id == thread.created_by_id and thread.unread_for_user_count:
        thread.unread_for_user_count = 0
        thread.save(update_fields=["unread_for_user_count", "updated_at"])
        return

    if can_access_support_center(viewer) and thread.unread_for_support_count:
        thread.unread_for_support_count = 0
        thread.save(update_fields=["unread_for_support_count", "updated_at"])


def get_report_reason_label(reason: str) -> str:
    return dict(ContentReport.Reason.choices).get(reason, reason)


def build_report_subject(*, target_label: str) -> str:
    return f"Жалоба: {target_label}"


def build_report_message(*, target_label: str, reason: str, details: str) -> str:
    message_lines = [
        f"Жалоба на: {target_label}",
        f"Причина: {get_report_reason_label(reason)}",
    ]
    if details.strip():
        message_lines.extend(["", details.strip()])
    return "\n".join(message_lines)


def create_content_report(
    *,
    reporter,
    target_type: str,
    target,
    target_snapshot: str,
    reason: str,
    details: str,
) -> ContentReport:
    thread = SupportThread.objects.create(
        subject=build_report_subject(target_label=target_snapshot),
        category=SupportThread.Category.REPORT,
        created_by=reporter,
        status=SupportThread.Status.WAITING_SUPPORT,
        last_message_at=timezone.now(),
        last_message_preview=build_thread_preview(
            build_report_message(
                target_label=target_snapshot,
                reason=reason,
                details=details,
            )
        ),
        unread_for_support_count=1,
        is_bot_enabled=False,
    )
    SupportMessage.objects.create(
        thread=thread,
        author=reporter,
        sender_type=SupportMessage.SenderType.USER,
        body=build_report_message(
            target_label=target_snapshot,
            reason=reason,
            details=details,
        ),
    )

    report = ContentReport.objects.create(
        reporter=reporter,
        target_type=target_type,
        post=target if target_type == ContentReport.TargetType.POST else None,
        comment=target if target_type == ContentReport.TargetType.COMMENT else None,
        review=target if target_type == ContentReport.TargetType.MAP_REVIEW else None,
        user_marker=target if target_type == ContentReport.TargetType.USER_MARKER else None,
        user_marker_comment=(
            target
            if target_type == ContentReport.TargetType.USER_MARKER_COMMENT
            else None
        ),
        target_snapshot=target_snapshot,
        reason=reason,
        details=details.strip(),
        support_thread=thread,
    )

    notify_support_team(
        actor=reporter,
        kind=Notification.Kind.REPORT_CREATED,
        title="Новая жалоба",
        body=f"{reporter.display_name or reporter.username} пожаловался на «{target_snapshot}»",
        support_thread=thread,
        report=report,
    )
    return report


def remove_report_target(report: ContentReport) -> None:
    target = (
        report.post
        or report.comment
        or report.review
        or report.user_marker
        or report.user_marker_comment
    )
    if target is None:
        return
    target.delete()


def update_report_status(
    *,
    report: ContentReport,
    reviewer,
    status: str,
    resolution_note: str,
    remove_target: bool = False,
) -> ContentReport:
    resolution_text = resolution_note.strip()
    report.status = status
    report.reviewed_by = reviewer
    report.reviewed_at = timezone.now()
    report.resolution_note = resolution_text
    report.save(
        update_fields=[
            "status",
            "reviewed_by",
            "reviewed_at",
            "resolution_note",
            "updated_at",
        ]
    )

    if remove_target:
        remove_report_target(report)

    thread = report.support_thread
    if thread:
        if resolution_text and status in {
            ContentReport.Status.RESOLVED,
            ContentReport.Status.REJECTED,
            ContentReport.Status.IN_REVIEW,
        }:
            append_support_message(
                thread=thread,
                author=reviewer,
                body=resolution_text,
                as_support=True,
            )

        if status in {ContentReport.Status.RESOLVED, ContentReport.Status.REJECTED}:
            close_support_thread(
                thread=thread,
                actor=reviewer,
                reason=(
                    "Чат закрыт после обработки жалобы. Новые сообщения в этот тред больше отправить нельзя."
                ),
            )
        elif status == ContentReport.Status.IN_REVIEW:
            thread.status = SupportThread.Status.WAITING_USER
            if thread.assigned_to_id is None:
                thread.assigned_to = reviewer
                thread.save(update_fields=["status", "assigned_to", "updated_at"])
            else:
                thread.save(update_fields=["status", "updated_at"])

        if resolution_text:
            return report

    create_notification(
        recipient=report.reporter,
        actor=reviewer,
        kind=Notification.Kind.REPORT_UPDATED,
        title="Статус жалобы изменен",
        body=f"Жалоба «{report.target_label}» переведена в статус «{report.get_status_display()}»",
        support_thread=thread,
        report=report,
    )
    return report


def build_bot_reply(query: str) -> dict:
    article = match_support_article(query)
    if article:
        return {
            "matched_article": article,
            "reply": f"Похоже, подойдет раздел «{article['title']}». {article['answer']}",
            "suggestions": [article],
        }

    fallback_articles = [item for item in SUPPORT_KNOWLEDGE_BASE if item["is_featured"]][:3]
    return {
        "matched_article": None,
        "reply": (
            "Не нашел точного совпадения. Откройте чат с поддержкой и приложите "
            "скриншот, страницу и шаги воспроизведения."
        ),
        "suggestions": fallback_articles,
    }
