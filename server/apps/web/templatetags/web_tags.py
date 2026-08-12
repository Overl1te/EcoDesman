from urllib.parse import urlencode

from django import template

register = template.Library()


@register.simple_tag(takes_context=True)
def query_update(context, **kwargs):
    request = context["request"]
    params = request.GET.copy()
    for key, value in kwargs.items():
        if value in (None, "", False):
            params.pop(key, None)
        else:
            params[key] = value
    encoded = params.urlencode()
    return f"?{encoded}" if encoded else ""


@register.filter
def kind_label(value):
    mapping = {
        "news": "Новость",
        "event": "Событие",
        "story": "История",
    }
    return mapping.get(value, value)


@register.filter
def role_label(value):
    mapping = {
        "admin": "Админ",
        "moderator": "Модератор",
        "user": "Пользователь",
    }
    return mapping.get(value, value)
