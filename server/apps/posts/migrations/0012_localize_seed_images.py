import hashlib

from django.db import migrations


MEDIA_BASE = "https://эковыхухоль.рф/generated/eco"
POST_ASSETS = tuple(f"{MEDIA_BASE}/map-{index}.jpg" for index in range(1, 9))
AVATAR_ASSETS = tuple(f"{MEDIA_BASE}/avatar-{index}.jpg" for index in range(1, 4))


def replace_remote_images(apps, schema_editor):
    post_image_model = apps.get_model("posts", "PostImage")
    user_model = apps.get_model("users", "User")

    for image in post_image_model.objects.filter(image_url__startswith="https://picsum.photos/").iterator():
        digest = hashlib.sha256(image.image_url.encode("utf-8")).digest()[0]
        image.image_url = POST_ASSETS[digest % len(POST_ASSETS)]
        image.save(update_fields=("image_url",))

    for user in user_model.objects.filter(avatar_url__startswith="https://picsum.photos/").iterator():
        digest = hashlib.sha256(user.avatar_url.encode("utf-8")).digest()[0]
        user.avatar_url = AVATAR_ASSETS[digest % len(AVATAR_ASSETS)]
        user.save(update_fields=("avatar_url",))


class Migration(migrations.Migration):
    dependencies = [
        ("posts", "0011_alter_post_slug"),
        ("users", "0010_passwordless_auth_challenge"),
    ]
    operations = [migrations.RunPython(replace_remote_images, migrations.RunPython.noop)]
