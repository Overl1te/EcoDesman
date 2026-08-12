from django.db import migrations


POINTS = [
    {
        "slug": "istok",
        "title": "Исток",
        "description": "Точка на карте Нижнего Новгорода",
        "latitude": 56.261565,
        "longitude": 44.019099,
        "sort_order": 10,
    },
    {
        "slug": "yandex-market",
        "title": "Яндекс Маркет",
        "description": "Точка на карте Нижнего Новгорода",
        "latitude": 56.269946,
        "longitude": 44.041643,
        "sort_order": 20,
    },
    {
        "slug": "ecopunkt",
        "title": "Экопункт",
        "description": "Точка на карте Нижнего Новгорода",
        "latitude": 56.324107,
        "longitude": 43.943562,
        "sort_order": 30,
    },
    {
        "slug": "batteries",
        "title": "Батарейки",
        "description": "Точка на карте Нижнего Новгорода",
        "latitude": 56.333631,
        "longitude": 43.951484,
        "sort_order": 40,
    },
    {
        "slug": "paper",
        "title": "Бумага",
        "description": "Точка на карте Нижнего Новгорода",
        "latitude": 56.311318,
        "longitude": 44.052475,
        "sort_order": 50,
    },
]


def seed_points(apps, schema_editor):
    MapPoint = apps.get_model("map_points", "MapPoint")

    for payload in POINTS:
        MapPoint.objects.update_or_create(
            slug=payload["slug"],
            defaults=payload,
        )


def unseed_points(apps, schema_editor):
    MapPoint = apps.get_model("map_points", "MapPoint")
    MapPoint.objects.filter(slug__in=[item["slug"] for item in POINTS]).delete()


class Migration(migrations.Migration):
    dependencies = [
        ("map_points", "0001_initial"),
    ]

    operations = [
        migrations.RunPython(seed_points, unseed_points),
    ]

