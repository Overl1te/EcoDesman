from django.db import migrations


CATEGORIES = [
    {"slug": "pickup", "title": "Прием вторсырья", "sort_order": 10},
    {"slug": "marketplace", "title": "Маркетплейс", "sort_order": 20},
    {"slug": "batteries", "title": "Батарейки", "sort_order": 30},
    {"slug": "paper", "title": "Бумага", "sort_order": 40},
    {"slug": "eco-center", "title": "Экоцентр", "sort_order": 50},
]

POINTS = [
    {
        "slug": "istok",
        "short_description": "Пункт, куда можно привезти вторсырье и уточнить правила сортировки.",
        "description": (
            "Исток — это точка, где удобно начать знакомство с раздельным сбором. "
            "Сюда можно привезти отсортированные фракции, уточнить, что принимается сейчас, "
            "и получить базовые рекомендации по подготовке сырья."
        ),
        "address": "Нижний Новгород, район Советский",
        "working_hours": "Ежедневно, 10:00–19:00",
        "categories": ["pickup", "eco-center"],
        "images": [
            {
                "image_url": "https://picsum.photos/seed/econizhny-istok-1/1280/960",
                "caption": "Вход и зона приема",
                "position": 0,
            },
            {
                "image_url": "https://picsum.photos/seed/econizhny-istok-2/1280/960",
                "caption": "Контейнеры для разных фракций",
                "position": 1,
            },
        ],
        "reviews": [
            {
                "author_name": "Анна",
                "rating": 5,
                "body": "Удобная точка, быстро подсказали, как лучше подготовить пластик и картон.",
            },
            {
                "author_name": "Илья",
                "rating": 4,
                "body": "Понравилось, что есть понятная навигация по фракциям и не страшно прийти впервые.",
            },
        ],
    },
    {
        "slug": "yandex-market",
        "short_description": "Точка сбора рядом с крупным городским хабом и высоким потоком людей.",
        "description": (
            "Удобная точка около Яндекс Маркета, куда можно заехать по пути. "
            "Хорошо подходит для небольших объемов упаковки, бумаги и других бытовых фракций."
        ),
        "address": "Нижний Новгород, рядом с логистическим узлом",
        "working_hours": "Пн–Вс, 09:00–21:00",
        "categories": ["pickup", "marketplace"],
        "images": [
            {
                "image_url": "https://picsum.photos/seed/econizhny-yandex-1/1280/960",
                "caption": "Точка рядом с входной группой",
                "position": 0,
            },
            {
                "image_url": "https://picsum.photos/seed/econizhny-yandex-2/1280/960",
                "caption": "Стенд с правилами приема",
                "position": 1,
            },
        ],
        "reviews": [
            {
                "author_name": "Мария",
                "rating": 5,
                "body": "Очень удобно заезжать после работы, точка читается с улицы.",
            },
        ],
    },
    {
        "slug": "ecopunkt",
        "short_description": "Городской экопункт с расширенным приемом и понятной инфраструктурой.",
        "description": (
            "Экопункт подходит для тех, кто хочет сдавать несколько типов вторсырья за один визит. "
            "Обычно здесь удобнее всего принимать пластик, стекло, бумагу и металл."
        ),
        "address": "Нижний Новгород, Сормовский район",
        "working_hours": "Вт–Вс, 11:00–20:00",
        "categories": ["pickup", "eco-center"],
        "images": [
            {
                "image_url": "https://picsum.photos/seed/econizhny-ecopunkt-1/1280/960",
                "caption": "Основная площадка",
                "position": 0,
            },
            {
                "image_url": "https://picsum.photos/seed/econizhny-ecopunkt-2/1280/960",
                "caption": "Информационный стенд",
                "position": 1,
            },
            {
                "image_url": "https://picsum.photos/seed/econizhny-ecopunkt-3/1280/960",
                "caption": "Место для разгрузки",
                "position": 2,
            },
        ],
        "reviews": [
            {
                "author_name": "Светлана",
                "rating": 5,
                "body": "Одна из самых понятных точек: есть место, где остановиться, и легко найти нужный контейнер.",
            },
            {
                "author_name": "Денис",
                "rating": 4,
                "body": "Хороший экопункт, но в выходные бывает плотнее по людям.",
            },
        ],
    },
    {
        "slug": "batteries",
        "short_description": "Специализированная точка под сбор батареек и небольших аккумуляторов.",
        "description": (
            "Если нужно безопасно сдать батарейки и мелкие элементы питания, это одна из самых понятных точек. "
            "Хорошо подходит для бытового объема и регулярного сбора дома."
        ),
        "address": "Нижний Новгород, Московский район",
        "working_hours": "Ежедневно, 10:00–22:00",
        "categories": ["batteries", "pickup"],
        "images": [
            {
                "image_url": "https://picsum.photos/seed/econizhny-batteries-1/1280/960",
                "caption": "Контейнер для батареек",
                "position": 0,
            },
            {
                "image_url": "https://picsum.photos/seed/econizhny-batteries-2/1280/960",
                "caption": "Навигация возле точки",
                "position": 1,
            },
        ],
        "reviews": [
            {
                "author_name": "Олег",
                "rating": 5,
                "body": "Отличная точка именно под батарейки, все быстро и понятно.",
            },
        ],
    },
    {
        "slug": "paper",
        "short_description": "Точка, удобная для сдачи бумаги, картона и упаковочных материалов.",
        "description": (
            "Эта точка удобна, если вы регулярно копите бумагу и картон дома или в небольшом офисе. "
            "Обычно сюда удобно привозить упакованный картон, крафт и чистую бумажную упаковку."
        ),
        "address": "Нижний Новгород, Канавинский район",
        "working_hours": "Пн–Сб, 09:00–18:00",
        "categories": ["paper", "pickup"],
        "images": [
            {
                "image_url": "https://picsum.photos/seed/econizhny-paper-1/1280/960",
                "caption": "Площадка для бумаги и картона",
                "position": 0,
            },
            {
                "image_url": "https://picsum.photos/seed/econizhny-paper-2/1280/960",
                "caption": "Зона приема коробок",
                "position": 1,
            },
        ],
        "reviews": [
            {
                "author_name": "Екатерина",
                "rating": 4,
                "body": "Удобно сдавать коробки после маркетплейсов, точка понятная и без лишней суеты.",
            },
            {
                "author_name": "Никита",
                "rating": 5,
                "body": "Лучше заранее сложить картон компактно — тогда прием проходит совсем быстро.",
            },
        ],
    },
]


def seed_content(apps, schema_editor):
    MapPoint = apps.get_model("map_points", "MapPoint")
    MapPointCategory = apps.get_model("map_points", "MapPointCategory")
    MapPointImage = apps.get_model("map_points", "MapPointImage")
    MapPointReview = apps.get_model("map_points", "MapPointReview")

    categories_by_slug = {}
    for payload in CATEGORIES:
        category, _ = MapPointCategory.objects.update_or_create(
            slug=payload["slug"],
            defaults=payload,
        )
        categories_by_slug[payload["slug"]] = category

    for payload in POINTS:
        point = MapPoint.objects.get(slug=payload["slug"])
        point.short_description = payload["short_description"]
        point.description = payload["description"]
        point.address = payload["address"]
        point.working_hours = payload["working_hours"]
        point.save(
            update_fields=[
                "short_description",
                "description",
                "address",
                "working_hours",
                "updated_at",
            ]
        )
        point.categories.set(
            [categories_by_slug[slug] for slug in payload["categories"]]
        )

        MapPointImage.objects.filter(point=point).delete()
        MapPointReview.objects.filter(point=point).delete()

        for image in payload["images"]:
            MapPointImage.objects.create(point=point, **image)

        for review in payload["reviews"]:
            MapPointReview.objects.create(point=point, **review)


def unseed_content(apps, schema_editor):
    MapPointCategory = apps.get_model("map_points", "MapPointCategory")
    MapPointImage = apps.get_model("map_points", "MapPointImage")
    MapPointReview = apps.get_model("map_points", "MapPointReview")

    MapPointImage.objects.all().delete()
    MapPointReview.objects.all().delete()
    MapPointCategory.objects.filter(slug__in=[item["slug"] for item in CATEGORIES]).delete()


class Migration(migrations.Migration):
    dependencies = [
        ("map_points", "0003_mappointcategory_mappoint_address_and_more"),
    ]

    operations = [
        migrations.RunPython(seed_content, unseed_content),
    ]
