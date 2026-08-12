import re

from django.db.models import QuerySet

from .models import ContentReport, SupportThread

SUPPORT_KNOWLEDGE_BASE = [
    {
        "id": "login-trouble",
        "category": "Аккаунт",
        "title": "Не получается войти в аккаунт",
        "answer": (
            "Проверьте логин или почту без лишних пробелов. Если пароль не подходит, "
            "сбросьте его и попробуйте войти снова."
        ),
        "keywords": [
            "войти",
            "логин",
            "пароль",
            "аккаунт",
            "авторизация",
            "sign in",
        ],
        "is_featured": True,
    },
    {
        "id": "map-point-issue",
        "category": "Карта",
        "title": "Проблема с точкой на карте",
        "answer": (
            "Если точка не открывается или данные неверные, приложите ссылку, "
            "скриншот и коротко опишите, что нужно исправить."
        ),
        "keywords": [
            "карта",
            "точка",
            "адрес",
            "место",
            "геолокация",
            "map",
        ],
        "is_featured": True,
    },
    {
        "id": "review-not-published",
        "category": "Отзывы",
        "title": "Отзыв не публикуется",
        "answer": (
            "Проверьте текст, фото и подключение к интернету. Если ошибка повторяется, "
            "напишите нам и приложите скриншот."
        ),
        "keywords": [
            "отзыв",
            "review",
            "фото",
            "публикация",
            "ошибка",
            "карта",
        ],
        "is_featured": True,
    },
    {
        "id": "post-or-comment-missing",
        "category": "Прочее",
        "title": "Пост или комментарий пропал",
        "answer": (
            "Проверьте профиль и черновики. Если запись скрыта после жалобы, "
            "поддержка покажет причину и статус проверки."
        ),
        "keywords": [
            "пост",
            "комментарий",
            "пропал",
            "удален",
            "жалоба",
            "скрыт",
        ],
        "is_featured": True,
    },
    {
        "id": "notifications-delay",
        "category": "Прочее",
        "title": "Не приходят уведомления",
        "answer": (
            "Обновите экран уведомлений, проверьте интернет и разрешения устройства. "
            "Если уведомления всё равно не приходят, напишите в поддержку."
        ),
        "keywords": [
            "уведомления",
            "notification",
            "не приходят",
            "не вижу",
        ],
        "is_featured": False,
    },
    {
        "id": "mobile-profile-help",
        "category": "Аккаунт",
        "title": "Где найти помощь в приложении",
        "answer": (
            "Откройте профиль и раздел «Помощь». Там доступны статьи, поиск "
            "и кнопка для обращения в поддержку."
        ),
        "keywords": [
            "мобильное",
            "профиль",
            "помощь",
            "справка",
            "android",
            "ios",
        ],
        "is_featured": False,
    },
]


def list_support_knowledge() -> dict[str, list[dict]]:
    faq = sorted(
        SUPPORT_KNOWLEDGE_BASE,
        key=lambda item: (not item["is_featured"], item["category"], item["title"]),
    )
    featured = [item for item in faq if item["is_featured"]]
    return {
        "featured": featured,
        "faq": faq,
        "suggested_prompts": [item["title"] for item in featured[:4]],
    }


def tokenize_support_query(value: str) -> set[str]:
    return {
        token
        for token in re.findall(r"[\w-]+", value.lower(), flags=re.UNICODE)
        if len(token) > 2
    }


def match_support_article(query: str) -> dict | None:
    query_tokens = tokenize_support_query(query)
    if not query_tokens:
        return None

    best_match = None
    best_score = 0
    for article in SUPPORT_KNOWLEDGE_BASE:
        article_tokens = tokenize_support_query(article["title"])
        for keyword in article["keywords"]:
            article_tokens.update(tokenize_support_query(keyword))
        score = len(query_tokens.intersection(article_tokens))
        if score > best_score:
            best_score = score
            best_match = article

    return best_match if best_score > 0 else None


def list_user_threads(user) -> QuerySet[SupportThread]:
    return (
        SupportThread.objects.filter(created_by=user)
        .select_related("created_by", "assigned_to", "linked_report")
    )


def list_team_threads() -> QuerySet[SupportThread]:
    return (
        SupportThread.objects.all()
        .select_related("created_by", "assigned_to", "linked_report")
        .order_by("-unread_for_support_count", "-last_message_at", "-id")
    )


def list_team_reports() -> QuerySet[ContentReport]:
    return (
        ContentReport.objects.all()
        .select_related(
            "reporter",
            "reviewed_by",
            "support_thread",
            "post",
            "comment",
            "review",
        )
        .order_by("-created_at", "-id")
    )
