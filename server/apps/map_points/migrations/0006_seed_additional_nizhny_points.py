from django.db import migrations


NEW_CATEGORIES = [
    {"slug": "park", "title": "Парк", "sort_order": 60},
    {"slug": "viewpoint", "title": "Видовая точка", "sort_order": 70},
    {"slug": "museum", "title": "Музей", "sort_order": 80},
    {"slug": "nature", "title": "Природа", "sort_order": 90},
    {"slug": "embankment", "title": "Набережная", "sort_order": 100},
    {"slug": "sports", "title": "Спорт и прогулки", "sort_order": 110},
]


NEW_POINTS = [
    {
        "slug": "alexandrovsky-garden",
        "title": "Александровский сад",
        "short_description": "Исторический парк на волжском склоне с прогулочными дорожками, лестницами и видами на реку.",
        "description": (
            "Один из самых узнаваемых городских парков в центре Нижнего Новгорода. "
            "Сюда приходят за прогулкой по террасам, спокойными видами на Волгу и "
            "маршрутом вдоль исторического склона."
        ),
        "address": "Верхне-Волжская набережная, Нижний Новгород",
        "working_hours": "Круглосуточно",
        "latitude": 56.33065,
        "longitude": 44.01391,
        "sort_order": 60,
        "categories": ["park", "viewpoint"],
        "images": [
            {
                "image_url": "https://picsum.photos/seed/econizhny-alex-garden-1/1280/960",
                "caption": "Прогулочные аллеи и вид на Волгу",
                "position": 0,
            },
            {
                "image_url": "https://picsum.photos/seed/econizhny-alex-garden-2/1280/960",
                "caption": "Террасы и лестницы парка",
                "position": 1,
            },
        ],
        "reviews": [
            {
                "author_name": "Марина",
                "rating": 5,
                "body": "Хорошее место для спокойной прогулки и видов на Волгу, особенно под вечер.",
            },
            {
                "author_name": "Роман",
                "rating": 4,
                "body": "Удобно зайти по пути из центра и просто пройтись по склону без лишней суеты.",
            },
        ],
    },
    {
        "slug": "strelka",
        "title": "Стрелка",
        "short_description": "Знаковое место на слиянии Оки и Волги с широкими панорамами и историческим окружением.",
        "description": (
            "Стрелка — одна из главных видовых точек города и важная часть истории Нижнего Новгорода. "
            "Здесь пересекаются речные маршруты, прогулочные пространства и район бывшего порта и ярмарки."
        ),
        "address": "Стрелка, Нижний Новгород",
        "working_hours": "Круглосуточно",
        "latitude": 56.33455,
        "longitude": 43.97595,
        "sort_order": 70,
        "categories": ["viewpoint", "embankment"],
        "images": [
            {
                "image_url": "https://picsum.photos/seed/econizhny-strelka-1/1280/960",
                "caption": "Панорама у слияния Оки и Волги",
                "position": 0,
            },
            {
                "image_url": "https://picsum.photos/seed/econizhny-strelka-2/1280/960",
                "caption": "Прогулочная зона у Стрелки",
                "position": 1,
            },
        ],
        "reviews": [
            {
                "author_name": "Ирина",
                "rating": 5,
                "body": "Одно из самых сильных мест по виду на город и воду, особенно в ясную погоду.",
            },
            {
                "author_name": "Максим",
                "rating": 4,
                "body": "Люблю заходить сюда на короткую прогулку, когда хочется просто посмотреть на реку.",
            },
        ],
    },
    {
        "slug": "wooden-architecture-museum",
        "title": "Музей деревянного зодчества",
        "short_description": "Музей под открытым небом на Щёлоковском хуторе с памятниками деревянной архитектуры XVII–XIX веков.",
        "description": (
            "Архитектурно-этнографический музей-заповедник на территории лесопарка Щёлоковский хутор. "
            "Здесь собраны деревянные постройки из разных районов Нижегородской области и маршрут хорошо "
            "подходит для вдумчивой прогулки на свежем воздухе."
        ),
        "address": "Щёлоковский хутор, Нижний Новгород",
        "working_hours": "По расписанию музея",
        "latitude": 56.27404,
        "longitude": 44.01068,
        "sort_order": 80,
        "categories": ["museum", "nature"],
        "images": [
            {
                "image_url": "https://picsum.photos/seed/econizhny-wood-museum-1/1280/960",
                "caption": "Деревянные постройки под открытым небом",
                "position": 0,
            },
            {
                "image_url": "https://picsum.photos/seed/econizhny-wood-museum-2/1280/960",
                "caption": "Маршрут по музейной территории",
                "position": 1,
            },
        ],
        "reviews": [
            {
                "author_name": "Татьяна",
                "rating": 5,
                "body": "Очень атмосферное место, где прогулка по лесу сочетается с историей деревянной архитектуры.",
            },
            {
                "author_name": "Сергей",
                "rating": 4,
                "body": "Хороший маршрут на полдня, особенно если хочется выбраться из шумного центра.",
            },
        ],
    },
    {
        "slug": "dendrarium",
        "title": "Дендрарий",
        "short_description": "Ботаническая зона в парке «Швейцария» с коллекцией деревьев и кустарников из разных регионов.",
        "description": (
            "Дендрарий парка «Швейцария» — спокойная зеленая часть маршрута с дендрологической коллекцией. "
            "Это удобная точка для прогулки, короткой паузы в тени и знакомства с редкими для города породами."
        ),
        "address": "Парк «Швейцария», Нижний Новгород",
        "working_hours": "Круглосуточно",
        "latitude": 56.28486,
        "longitude": 43.97693,
        "sort_order": 90,
        "categories": ["park", "nature"],
        "images": [
            {
                "image_url": "https://picsum.photos/seed/econizhny-dendrarium-1/1280/960",
                "caption": "Тихая часть парка с ботанической коллекцией",
                "position": 0,
            },
            {
                "image_url": "https://picsum.photos/seed/econizhny-dendrarium-2/1280/960",
                "caption": "Тропа среди деревьев и кустарников",
                "position": 1,
            },
        ],
        "reviews": [
            {
                "author_name": "Ольга",
                "rating": 5,
                "body": "Нравится именно эта часть парка: тише, зеленее и ощущается как отдельный маршрут.",
            },
            {
                "author_name": "Павел",
                "rating": 4,
                "body": "Подходит для неспешной прогулки, когда хочется уйти с более шумных дорожек.",
            },
        ],
    },
    {
        "slug": "urochische-sluda",
        "title": "Урочище Слуда",
        "short_description": "Природная территория на склоне Оки с широколиственным лесом и тихими маршрутами.",
        "description": (
            "Памятник природы на правом склоне Оки, где сохраняется массив широколиственного леса. "
            "Локация подойдет тем, кто ищет более спокойную природную прогулку внутри города."
        ),
        "address": "Склоны Оки у парка «Швейцария», Нижний Новгород",
        "working_hours": "Круглосуточно",
        "latitude": 56.27453,
        "longitude": 43.97266,
        "sort_order": 100,
        "categories": ["nature", "viewpoint"],
        "images": [
            {
                "image_url": "https://picsum.photos/seed/econizhny-sluda-1/1280/960",
                "caption": "Лесной склон у Оки",
                "position": 0,
            },
            {
                "image_url": "https://picsum.photos/seed/econizhny-sluda-2/1280/960",
                "caption": "Тропа через природную территорию",
                "position": 1,
            },
        ],
        "reviews": [
            {
                "author_name": "Денис",
                "rating": 5,
                "body": "Редкое ощущение настоящего леса почти внутри городской ткани, место очень спокойное.",
            },
            {
                "author_name": "Лена",
                "rating": 4,
                "body": "Хороший маршрут, если хочется меньше людей и больше природы.",
            },
        ],
    },
    {
        "slug": "grebnoy-canal",
        "title": "Гребной Канал",
        "short_description": "Набережная и спортивная локация у воды с длинным прогулочным маршрутом.",
        "description": (
            "Гребной канал сочетает спортивную функцию и городской променад. "
            "Сюда приходят на прогулку вдоль воды, за видом на Волгу и набережной, а также за более открытым пространством."
        ),
        "address": "Набережная Гребного канала, Нижний Новгород",
        "working_hours": "Круглосуточно",
        "latitude": 56.319439,
        "longitude": 44.073944,
        "sort_order": 110,
        "categories": ["embankment", "sports"],
        "images": [
            {
                "image_url": "https://picsum.photos/seed/econizhny-grebnoy-1/1280/960",
                "caption": "Прогулка вдоль воды",
                "position": 0,
            },
            {
                "image_url": "https://picsum.photos/seed/econizhny-grebnoy-2/1280/960",
                "caption": "Набережная и открытое пространство",
                "position": 1,
            },
        ],
        "reviews": [
            {
                "author_name": "Артем",
                "rating": 5,
                "body": "Отличное место для длинной прогулки у воды и для катания по ровной набережной.",
            },
            {
                "author_name": "Юлия",
                "rating": 4,
                "body": "Просторно, свежо и легко выбрать темп прогулки, когда хочется больше открытого пространства.",
            },
        ],
    },
    {
        "slug": "sormovsky-park",
        "title": "Сормовский парк",
        "short_description": "Большой городской парк для прогулок, отдыха и семейного маршрута на западе Нижнего Новгорода.",
        "description": (
            "Сормовский парк — одна из самых известных зеленых зон города для повседневного отдыха. "
            "Он подходит и для короткой прогулки по аллеям, и для более длинного маршрута с выходом к воде и аттракционам."
        ),
        "address": "Бульвар Юбилейный, 34, Нижний Новгород",
        "working_hours": "Круглосуточно",
        "latitude": 56.34219,
        "longitude": 43.86073,
        "sort_order": 120,
        "categories": ["park", "sports"],
        "images": [
            {
                "image_url": "https://picsum.photos/seed/econizhny-sormovo-1/1280/960",
                "caption": "Аллеи Сормовского парка",
                "position": 0,
            },
            {
                "image_url": "https://picsum.photos/seed/econizhny-sormovo-2/1280/960",
                "caption": "Пространство для прогулок и отдыха",
                "position": 1,
            },
        ],
        "reviews": [
            {
                "author_name": "Виктория",
                "rating": 5,
                "body": "Удобный большой парк на полдня: можно и пройтись, и просто посидеть в зелени.",
            },
            {
                "author_name": "Кирилл",
                "rating": 4,
                "body": "Нормальное место для семейной прогулки, особенно если хочется маршрут подлиннее.",
            },
        ],
    },
    {
        "slug": "avtozavodsky-park",
        "title": "Автозаводский парк",
        "short_description": "Исторический парк Автозаводского района с широкими аллеями и большой прогулочной территорией.",
        "description": (
            "Крупный парк в Автозаводском районе, сформированный как часть городской среды соцгорода. "
            "Сейчас это удобная точка для прогулок по аллеям, отдыха в тени и спокойного маршрута внутри района."
        ),
        "address": "Автозаводский район, Нижний Новгород",
        "working_hours": "Круглосуточно",
        "latitude": 56.23996,
        "longitude": 43.8594,
        "sort_order": 130,
        "categories": ["park", "nature"],
        "images": [
            {
                "image_url": "https://picsum.photos/seed/econizhny-avto-park-1/1280/960",
                "caption": "Аллеи Автозаводского парка",
                "position": 0,
            },
            {
                "image_url": "https://picsum.photos/seed/econizhny-avto-park-2/1280/960",
                "caption": "Зеленая часть маршрута",
                "position": 1,
            },
        ],
        "reviews": [
            {
                "author_name": "Надежда",
                "rating": 5,
                "body": "Люблю этот парк за простор и старые аллеи, там легко гулять без спешки.",
            },
            {
                "author_name": "Егор",
                "rating": 4,
                "body": "Подходит для обычной районной прогулки и не ощущается тесным даже в выходные.",
            },
        ],
    },
]


def seed_additional_points(apps, schema_editor):
    MapPoint = apps.get_model("map_points", "MapPoint")
    MapPointCategory = apps.get_model("map_points", "MapPointCategory")
    MapPointImage = apps.get_model("map_points", "MapPointImage")
    MapPointReview = apps.get_model("map_points", "MapPointReview")

    categories_by_slug = {}
    for payload in NEW_CATEGORIES:
        category, _ = MapPointCategory.objects.update_or_create(
            slug=payload["slug"],
            defaults=payload,
        )
        categories_by_slug[payload["slug"]] = category

    for payload in NEW_POINTS:
        point_defaults = {
            "title": payload["title"],
            "short_description": payload["short_description"],
            "description": payload["description"],
            "address": payload["address"],
            "working_hours": payload["working_hours"],
            "latitude": payload["latitude"],
            "longitude": payload["longitude"],
            "sort_order": payload["sort_order"],
            "is_active": True,
        }
        point, _ = MapPoint.objects.update_or_create(
            slug=payload["slug"],
            defaults=point_defaults,
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


def unseed_additional_points(apps, schema_editor):
    MapPoint = apps.get_model("map_points", "MapPoint")
    MapPointCategory = apps.get_model("map_points", "MapPointCategory")

    MapPoint.objects.filter(slug__in=[item["slug"] for item in NEW_POINTS]).delete()
    MapPointCategory.objects.filter(
        slug__in=[item["slug"] for item in NEW_CATEGORIES]
    ).delete()


class Migration(migrations.Migration):
    dependencies = [
        ("map_points", "0005_mappointreview_author"),
    ]

    operations = [
        migrations.RunPython(seed_additional_points, unseed_additional_points),
    ]
