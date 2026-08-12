from datetime import timedelta

from django.contrib.auth.hashers import make_password
from django.db import migrations
from django.utils import timezone


def seed_demo_data(apps, schema_editor):
    User = apps.get_model("users", "User")
    Post = apps.get_model("posts", "Post")
    PostImage = apps.get_model("posts", "PostImage")

    anna, _ = User.objects.update_or_create(
        email="anna@econizhny.local",
        defaults={
            "username": "anna",
            "display_name": "Анна Волкова",
            "phone": "+79990000001",
            "avatar_url": "https://picsum.photos/seed/econizhny-user-1/400/400",
            "password": make_password("demo12345"),
            "is_active": True,
        },
    )
    ivan, _ = User.objects.update_or_create(
        email="ivan@econizhny.local",
        defaults={
            "username": "ivan",
            "display_name": "Иван Соколов",
            "phone": "+79990000002",
            "avatar_url": "https://picsum.photos/seed/econizhny-user-2/400/400",
            "password": make_password("demo12345"),
            "is_active": True,
        },
    )

    seeded_posts = [
        {
            "title": "Новый пункт раздельного сбора на Покровке",
            "body": (
                "В центральной части города открылся новый пункт раздельного "
                "сбора. Теперь жители могут сдать пластик, стекло и бумагу в "
                "одном месте без длинных поездок по району."
            ),
            "kind": "news",
            "author": anna,
            "published_at": timezone.now() - timedelta(days=1),
            "images": [
                "https://picsum.photos/seed/econizhny-post-1/1200/800",
            ],
        },
        {
            "title": "Волонтёры собрали более 200 мешков мусора",
            "body": (
                "В выходные прошёл городской эко-субботник. Волонтёры "
                "очистили прогулочную зону у воды и вывезли крупногабаритный "
                "мусор, который копился там месяцами."
            ),
            "kind": "story",
            "author": ivan,
            "published_at": timezone.now() - timedelta(days=2),
            "images": [
                "https://picsum.photos/seed/econizhny-post-2/1200/800",
                "https://picsum.photos/seed/econizhny-post-3/1200/800",
            ],
        },
        {
            "title": "Апрельская эко-лекция для школьников",
            "body": (
                "В следующую субботу пройдёт открытая лекция о сортировке "
                "отходов и повседневных привычках, которые помогают уменьшить "
                "нагрузку на городскую инфраструктуру."
            ),
            "kind": "event",
            "author": anna,
            "published_at": timezone.now() - timedelta(hours=8),
            "images": [],
        },
    ]

    for entry in seeded_posts:
        post, _ = Post.objects.update_or_create(
            title=entry["title"],
            defaults={
                "body": entry["body"],
                "kind": entry["kind"],
                "author": entry["author"],
                "published_at": entry["published_at"],
                "is_published": True,
            },
        )
        PostImage.objects.filter(post=post).delete()
        for index, image_url in enumerate(entry["images"]):
            PostImage.objects.create(
                post=post,
                image_url=image_url,
                position=index,
            )


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    dependencies = [
        ("users", "0001_initial"),
        ("posts", "0002_initial"),
    ]

    operations = [
        migrations.RunPython(seed_demo_data, noop),
    ]
