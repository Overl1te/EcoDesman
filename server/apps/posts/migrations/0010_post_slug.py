from django.db import migrations, models
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


def _build_slug_source(post) -> str:
    return (post.title or "").strip() or (post.body or "").strip() or "post"


def _slugify_ascii(value: str) -> str:
    ascii_value = value.strip().lower().translate(_CYRILLIC_TO_LATIN)
    normalized = slugify(ascii_value, allow_unicode=False)
    return normalized[:220] or "post"


def populate_post_slugs(apps, schema_editor):
    Post = apps.get_model("posts", "Post")

    for post in Post.objects.order_by("author_id", "id"):
        base_slug = _slugify_ascii(_build_slug_source(post))
        slug = base_slug
        suffix = 2

        while (
            Post.objects.filter(author_id=post.author_id, slug=slug)
            .exclude(id=post.id)
            .exists()
        ):
            suffix_text = f"-{suffix}"
            slug = f"{base_slug[: 220 - len(suffix_text)]}{suffix_text}"
            suffix += 1

        Post.objects.filter(id=post.id).update(slug=slug)


class Migration(migrations.Migration):

    dependencies = [
        ("posts", "0009_post_event_cancelled_at_post_event_cancelled_by_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="post",
            name="slug",
            field=models.SlugField(blank=True, default="", max_length=220),
        ),
        migrations.RunPython(populate_post_slugs, migrations.RunPython.noop),
        migrations.AddConstraint(
            model_name="post",
            constraint=models.UniqueConstraint(
                fields=("author", "slug"),
                name="unique_post_slug_per_author",
            ),
        ),
    ]
