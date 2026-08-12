from django.contrib.auth.hashers import make_password
from django.db import migrations


def seed_social_features(apps, schema_editor):
    User = apps.get_model("users", "User")
    Post = apps.get_model("posts", "Post")
    PostLike = apps.get_model("posts", "PostLike")
    PostComment = apps.get_model("posts", "PostComment")

    anna, _ = User.objects.update_or_create(
        email="anna@econizhny.local",
        defaults={
            "username": "anna",
            "display_name": "Анна Волкова",
            "phone": "+79990000001",
            "avatar_url": "https://picsum.photos/seed/econizhny-user-1/400/400",
            "password": make_password("demo12345"),
            "role": "user",
            "status_text": "Люблю экологичные городские проекты",
            "bio": "Жительница Нижнего Новгорода, которая следит за экоинициативами и пишет о городских изменениях.",
            "city": "Нижний Новгород",
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
            "role": "moderator",
            "status_text": "Модерирую контент и слежу за качеством ленты",
            "bio": "Помогаю поддерживать порядок в ленте и валидировать пользовательские посты.",
            "city": "Нижний Новгород",
            "is_active": True,
        },
    )
    admin, _ = User.objects.update_or_create(
        email="admin@econizhny.local",
        defaults={
            "username": "eco_admin",
            "display_name": "ЭкоВыхухоль Admin",
            "phone": "+79990000003",
            "avatar_url": "https://picsum.photos/seed/econizhny-user-3/400/400",
            "password": make_password("demo12345"),
            "role": "admin",
            "status_text": "Управляю платформой",
            "bio": "Технический и продуктовый администратор проекта.",
            "city": "Нижний Новгород",
            "is_active": True,
            "is_staff": True,
            "is_superuser": True,
        },
    )

    first_post = Post.objects.filter(title="Новый пункт раздельного сбора на Покровке").first()
    second_post = Post.objects.filter(title="Волонтёры собрали более 200 мешков мусора").first()
    third_post = Post.objects.filter(title="Апрельская эко-лекция для школьников").first()

    if first_post:
        first_post.view_count = 42
        first_post.save(update_fields=["view_count"])
        PostLike.objects.get_or_create(post=first_post, user=ivan)
        PostLike.objects.get_or_create(post=first_post, user=admin)
        PostComment.objects.get_or_create(
            post=first_post,
            author=ivan,
            body="Отличная новость, такие точки сильно упрощают сортировку в центре города.",
        )
        PostComment.objects.get_or_create(
            post=first_post,
            author=admin,
            body="Пост проверен, данные по адресу подтверждены.",
        )

    if second_post:
        second_post.view_count = 67
        second_post.save(update_fields=["view_count"])
        PostLike.objects.get_or_create(post=second_post, user=anna)
        PostLike.objects.get_or_create(post=second_post, user=admin)
        PostComment.objects.get_or_create(
            post=second_post,
            author=anna,
            body="Супер, хотелось бы видеть такие отчёты после каждого городского субботника.",
        )

    if third_post:
        third_post.view_count = 19
        third_post.save(update_fields=["view_count"])
        PostLike.objects.get_or_create(post=third_post, user=anna)


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    dependencies = [
        ("users", "0002_user_bio_user_city_user_role_user_status_text"),
        ("posts", "0004_post_view_count_alter_post_kind_postcomment_postlike"),
    ]

    operations = [
        migrations.RunPython(seed_social_features, noop),
    ]
