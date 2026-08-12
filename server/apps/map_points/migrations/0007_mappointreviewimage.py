from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("map_points", "0006_seed_additional_nizhny_points"),
    ]

    operations = [
        migrations.CreateModel(
            name="MapPointReviewImage",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("image_url", models.URLField()),
                ("caption", models.CharField(blank=True, max_length=140)),
                ("position", models.PositiveIntegerField(default=0)),
                (
                    "review",
                    models.ForeignKey(
                        on_delete=models.deletion.CASCADE,
                        related_name="images",
                        to="map_points.mappointreview",
                    ),
                ),
            ],
            options={
                "ordering": ("position", "id"),
            },
        ),
    ]
