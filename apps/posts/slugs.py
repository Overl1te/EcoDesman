from collections.abc import Callable

from django.utils.text import slugify

_CYRILLIC_TO_LATIN = str.maketrans(
    {
        "а": "a",
        "б": "b",
        "в": "v",
        "г": "g",
        "д": "d",
        "е": "e",
        "ё": "e",
        "ж": "zh",
        "з": "z",
        "и": "i",
        "й": "i",
        "к": "k",
        "л": "l",
        "м": "m",
        "н": "n",
        "о": "o",
        "п": "p",
        "р": "r",
        "с": "s",
        "т": "t",
        "у": "u",
        "ф": "f",
        "х": "kh",
        "ц": "ts",
        "ч": "ch",
        "ш": "sh",
        "щ": "shch",
        "ъ": "",
        "ы": "y",
        "ь": "",
        "э": "e",
        "ю": "yu",
        "я": "ya",
    }
)


def build_post_slug_source(title: str, body: str) -> str:
    return (title or "").strip() or (body or "").strip() or "post"


def slugify_post_text(value: str) -> str:
    ascii_value = (value or "").strip().lower().translate(_CYRILLIC_TO_LATIN)
    normalized = slugify(ascii_value, allow_unicode=False)
    return normalized[:220] or "post"


def build_unique_post_slug(
    *,
    title: str,
    body: str,
    slug_exists: Callable[[str], bool],
) -> str:
    base_slug = slugify_post_text(build_post_slug_source(title, body))
    slug = base_slug
    suffix = 2

    while slug_exists(slug):
        suffix_text = f"-{suffix}"
        slug = f"{base_slug[: 220 - len(suffix_text)]}{suffix_text}"
        suffix += 1

    return slug
