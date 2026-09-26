import hashlib

from django.db import migrations


MEDIA_BASE = "https://эковыхухоль.рф/generated/eco"
MAP_ASSETS = tuple(f"{MEDIA_BASE}/map-{index}.jpg" for index in range(1, 9))


def replace_remote_images(apps, schema_editor):
    image_model = apps.get_model("map_points", "MapPointImage")
    review_image_model = apps.get_model("map_points", "MapPointReviewImage")
    for model in (image_model, review_image_model):
        for image in model.objects.filter(image_url__startswith="https://picsum.photos/").iterator():
            digest = hashlib.sha256(image.image_url.encode("utf-8")).digest()[0]
            image.image_url = MAP_ASSETS[digest % len(MAP_ASSETS)]
            image.save(update_fields=("image_url",))


class Migration(migrations.Migration):
    dependencies = [("map_points", "0010_seed_more_nizhny_eco_points")]
    operations = [migrations.RunPython(replace_remote_images, migrations.RunPython.noop)]
