from __future__ import annotations

import re
from collections.abc import Iterable
from typing import Any

DEFAULT_CATEGORY_COLOR = "#56616F"
HEX_COLOR_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")

_CATEGORY_STYLE_BY_SLUG: dict[str, dict[str, Any]] = {
    "pickup": {"priority": 10, "color": "#2C6A51"},
    "marketplace": {"priority": 20, "color": "#C7791A"},
    "batteries": {"priority": 30, "color": "#6D57C7"},
    "paper": {"priority": 40, "color": "#2E6DB4"},
    "eco-center": {"priority": 50, "color": "#0E7A53"},
    "clothes": {"priority": 55, "color": "#C04F86"},
    "park": {"priority": 60, "color": "#5A9A53"},
    "glass": {"priority": 65, "color": "#2E9B7B"},
    "viewpoint": {"priority": 70, "color": "#B46B2F"},
    "plastic": {"priority": 70, "color": "#178CA4"},
    "museum": {"priority": 80, "color": "#8A5B3C"},
    "electronics": {"priority": 80, "color": "#8B4CC7"},
    "nature": {"priority": 90, "color": "#478A4E"},
    "metal": {"priority": 90, "color": "#5B6776"},
    "scrap": {"priority": 95, "color": "#5B6776"},
    "embankment": {"priority": 100, "color": "#2F82A9"},
    "sports": {"priority": 110, "color": "#D16638"},
    "trash": {"priority": 5, "color": "#6B7280"},
    "waste-bin": {"priority": 5, "color": "#6B7280"},
    "mixed-waste": {"priority": 5, "color": "#6B7280"},
}


def _extract_slug_and_sort_order(
    category_or_slug: Any,
    sort_order: int | None = None,
) -> tuple[str, int | None]:
    if isinstance(category_or_slug, str):
        return category_or_slug, sort_order

    return (
        getattr(category_or_slug, "slug", ""),
        getattr(category_or_slug, "sort_order", sort_order),
    )


def get_category_priority(category_or_slug: Any, sort_order: int | None = None) -> int:
    slug, resolved_sort_order = _extract_slug_and_sort_order(
        category_or_slug,
        sort_order,
    )
    if resolved_sort_order is not None and resolved_sort_order > 0:
        return resolved_sort_order
    return int(_CATEGORY_STYLE_BY_SLUG.get(slug, {}).get("priority", 0))


def get_category_color(category_or_slug: Any) -> str:
    if not isinstance(category_or_slug, str):
        explicit_color = str(getattr(category_or_slug, "color", "")).strip()
        if HEX_COLOR_RE.match(explicit_color):
            return explicit_color.upper()

    slug, _ = _extract_slug_and_sort_order(category_or_slug)
    return str(_CATEGORY_STYLE_BY_SLUG.get(slug, {}).get("color", DEFAULT_CATEGORY_COLOR))


def sort_categories(categories: Iterable[Any]) -> list[Any]:
    return sorted(
        categories,
        key=lambda item: (
            -get_category_priority(item),
            getattr(item, "title", ""),
            getattr(item, "id", 0),
        ),
    )
