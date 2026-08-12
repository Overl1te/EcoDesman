from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("users", "0004_user_instagram_url_user_telegram_url_user_vk_url_and_more"),
        ("map_points", "0004_seed_map_point_content"),
    ]

    operations = [
        migrations.AddField(
            model_name="mappointreview",
            name="author",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=models.SET_NULL,
                related_name="map_point_reviews",
                to=settings.AUTH_USER_MODEL,
            ),
        ),
    ]
