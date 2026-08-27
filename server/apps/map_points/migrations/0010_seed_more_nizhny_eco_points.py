from django.db import migrations


MEDIA_BASE = "https://эковыхухоль.рф/media/uploads/points"

NEW_CATEGORIES = [
    {
        "slug": "ecotrail",
        "title": "Экотропа",
        "sort_order": 95,
        "color": "#2F7D5B",
    },
]


NEW_POINTS = [
    {
        "slug": "park-shveitsariya",
        "title": "Парк «Швейцария»",
        "short_description": "Крупнейший парк города на высоком берегу Оки с экотропой, дендрарием и смотровыми террасами.",
        "description": (
            "Парк культуры и отдыха «Швейцария» тянется вдоль Оки более чем на три километра. "
            "Это одна из главных зеленых зон Нижнего Новгорода: широколиственный лес, "
            "обустроенная экотропа со стендами, виды с террас и спокойные маршруты вдали от шумных аллей."
        ),
        "address": "проспект Гагарина, Приокский район, Нижний Новгород",
        "working_hours": "Круглосуточно",
        "latitude": 56.28080,
        "longitude": 43.98250,
        "sort_order": 140,
        "categories": ["park", "nature"],
        "images": [
            {
                "image_url": f"{MEDIA_BASE}/f1a10c81b24d4f6aa7c8d91e02f3a401.png",
                "caption": "Террасы парка и склон Оки",
                "position": 0,
            },
        ],
        "reviews": [
            {
                "author_name": "Алина",
                "rating": 5,
                "body": "Самый большой зеленый маршрут в городе: можно гулять часами и не выходить на одну и ту же дорожку.",
            },
            {
                "author_name": "Глеб",
                "rating": 4,
                "body": "Экотропа и виды с обрывов — лучшее, что есть в парке, если хочется именно природу, а не аттракционы.",
            },
        ],
    },
    {
        "slug": "meshcherskoe-ozero",
        "title": "Мещерское озеро",
        "short_description": "Крупнейшее озеро в черте города с прогулочной зоной, камышами и маршрутом вокруг воды.",
        "description": (
            "Мещерское озеро в Канавинском районе — редкий для мегаполиса водоем такого масштаба. "
            "Вокруг него удобно пройтись, понаблюдать за птицами у камышей и сделать паузу у воды, "
            "не уезжая за город."
        ),
        "address": "микрорайон Мещерское озеро, Канавинский район, Нижний Новгород",
        "working_hours": "Круглосуточно",
        "latitude": 56.337398,
        "longitude": 43.941864,
        "sort_order": 150,
        "categories": ["nature", "park"],
        "images": [
            {
                "image_url": f"{MEDIA_BASE}/f2b21d92c35e507bb8d9ea2f13a4b512.png",
                "caption": "Озеро и прогулочная зона",
                "position": 0,
            },
        ],
        "reviews": [
            {
                "author_name": "Наталья",
                "rating": 5,
                "body": "Люблю круговой маршрут у воды: просторно, есть где сесть и посмотреть на озеро.",
            },
            {
                "author_name": "Игорь",
                "rating": 4,
                "body": "Хорошая городская точка у воды, особенно если хочется прогуляться без поездки на набережную.",
            },
        ],
    },
    {
        "slug": "botanic-garden-nngu",
        "title": "Ботанический сад ННГУ",
        "short_description": "Памятник природы с дендрарием, оранжереями и коллекцией из нескольких тысяч видов растений.",
        "description": (
            "Ботанический сад университета Лобачевского — научный и природоохранный центр в Приокском районе. "
            "Здесь собраны дендрологическая коллекция, тропические оранжереи и участки открытого грунта. "
            "Посещение обычно организованное, по расписанию сада."
        ),
        "address": "улица Ботанический сад, 1, Нижний Новгород",
        "working_hours": "По расписанию сада, обычно по записи",
        "latitude": 56.254722,
        "longitude": 44.007778,
        "sort_order": 160,
        "categories": ["nature", "park", "museum"],
        "images": [
            {
                "image_url": f"{MEDIA_BASE}/f3c32ea3d46f618cc9eafb3024b5c623.png",
                "caption": "Дендрарий ботанического сада",
                "position": 0,
            },
        ],
        "reviews": [
            {
                "author_name": "Елена",
                "rating": 5,
                "body": "Очень сильная коллекция и тихий маршрут. Лучше заранее уточнить, как попасть на экскурсию.",
            },
            {
                "author_name": "Андрей",
                "rating": 4,
                "body": "Не обычный парк, а именно сад: растения, оранжереи и ощущение заповедного участка.",
            },
        ],
    },
    {
        "slug": "burnakovskaya-ecotrail",
        "title": "Бурнаковская экотропа",
        "short_description": "Кольцевая экотропа в Бурнаковской низине с дубово-березовыми аллеями и тихим маршрутом у озера.",
        "description": (
            "Экологическая тропа в Московском районе проходит по Бурнаковской низине: "
            "от озера вдоль дубово-березовых аллей и старой железной дороги. "
            "Это короткий спокойный маршрут, который удобно пройти неспешным шагом."
        ),
        "address": "Бурнаковская улица, 99, Нижний Новгород",
        "working_hours": "Круглосуточно",
        "latitude": 56.344766,
        "longitude": 43.915887,
        "sort_order": 170,
        "categories": ["ecotrail", "nature"],
        "images": [
            {
                "image_url": f"{MEDIA_BASE}/f4d43fb4e570729dda0b0c4135c6d734.png",
                "caption": "Маршрут экотропы в низине",
                "position": 0,
            },
        ],
        "reviews": [
            {
                "author_name": "Дарья",
                "rating": 5,
                "body": "Неожиданно тихая тропа внутри города. Идеально на час, если хочется зелени без большой поездки.",
            },
            {
                "author_name": "Михаил",
                "rating": 4,
                "body": "Короткий кольцевой маршрут, без суеты. Вход лучше искать со стороны Бурнаковской улицы.",
            },
        ],
    },
    {
        "slug": "artemovsky-meadows",
        "title": "Артемовские луга",
        "short_description": "Сохранившийся участок волжской поймы с Тропой здоровья, озёрами и маршрутами для наблюдения за птицами.",
        "description": (
            "Проектируемый природный парк между слободой Подновье и Кстовом — один из последних "
            "участков естественной Волжской поймы у города. Здесь проходят Тропа здоровья, "
            "орнитологическая тропа и экомаршрут «ковчег биоразнообразия»."
        ),
        "address": "слобода Подновье, Нижний Новгород",
        "working_hours": "Круглосуточно",
        "latitude": 56.29350,
        "longitude": 44.08980,
        "sort_order": 180,
        "categories": ["ecotrail", "nature"],
        "images": [
            {
                "image_url": f"{MEDIA_BASE}/f5e540c5f68183aee1b1cd5246d7e845.png",
                "caption": "Пойма Волги и заливные луга",
                "position": 0,
            },
        ],
        "reviews": [
            {
                "author_name": "София",
                "rating": 5,
                "body": "Совсем другое ощущение, чем в городском парке: луга, вода и птицы. Берите воду и удобную обувь.",
            },
            {
                "author_name": "Родион",
                "rating": 5,
                "body": "Тропа здоровья — сильный маршрут на полдня. Особенно хорошо ранним утром, когда тихо.",
            },
        ],
    },
    {
        "slug": "dubki-park",
        "title": "Парк «Дубки»",
        "short_description": "Районный парк на месте исторической дубравы с зрелыми дубами, клёнами и спокойными аллеями.",
        "description": (
            "Парк «Дубки» в Ленинском районе сохранил характер старой дубравы среди городской застройки. "
            "Сюда приходят за тенью крупных деревьев, короткой прогулкой по аллеям и более тихим "
            "маршрутом, чем в больших парках культуры."
        ),
        "address": "улица Адмирала Нахимова, 1, Нижний Новгород",
        "working_hours": "Круглосуточно",
        "latitude": 56.268333,
        "longitude": 43.920000,
        "sort_order": 190,
        "categories": ["park", "nature"],
        "images": [
            {
                "image_url": f"{MEDIA_BASE}/f6f651d6079294bff2c2de6357e8f956.png",
                "caption": "Дубовая аллея парка",
                "position": 0,
            },
        ],
        "reviews": [
            {
                "author_name": "Вера",
                "rating": 5,
                "body": "Уютный парк именно из-за дубов: летом здесь прохладно и не слишком людно.",
            },
            {
                "author_name": "Станислав",
                "rating": 4,
                "body": "Хорошая районная точка для короткой прогулки, если не хочется ехать на Швейцарию.",
            },
        ],
    },
    {
        "slug": "kulibin-park",
        "title": "Парк Кулибина",
        "short_description": "Исторический зеленый массив в центре города со старыми деревьями и тихими дорожками.",
        "description": (
            "Парк имени Кулибина занимает бывшее Петропавловское кладбище и остается одним из "
            "самых спокойных зеленых мест в центре. Здесь удобно спрятаться от шума улиц "
            "Белинского и Горького и пройтись под кронами старых лип и дубов."
        ),
        "address": "улица Белинского, Нижегородский район, Нижний Новгород",
        "working_hours": "Круглосуточно",
        "latitude": 56.31556,
        "longitude": 44.00889,
        "sort_order": 200,
        "categories": ["park", "nature"],
        "images": [
            {
                "image_url": f"{MEDIA_BASE}/f70762e718a3a5c003d3ef7468f90a67.png",
                "caption": "Тенистые дорожки парка",
                "position": 0,
            },
        ],
        "reviews": [
            {
                "author_name": "Ксения",
                "rating": 5,
                "body": "Редкое для центра место, где можно погулять среди старых деревьев и почти не слышать улицу.",
            },
            {
                "author_name": "Борис",
                "rating": 4,
                "body": "Компактный парк, но очень зеленый. Удобно зайти по пути, если вы в районе Горьковской.",
            },
        ],
    },
    {
        "slug": "maryina-roshcha",
        "title": "Марьина роща",
        "short_description": "Экотропа по реликтовой дубраве Щёлоковского хутора с лесными прудами и охраняемыми видами.",
        "description": (
            "Марьина роща — участок древнего широколиственного леса на территории лесопарка "
            "Щёлоковский хутор. Экотропа знакомит с дубравой, редкими растениями и тихим "
            "маршрутом мимо каскада прудов внутри города."
        ),
        "address": "лесопарк Щёлоковский хутор, улица Горбатовская, Нижний Новгород",
        "working_hours": "Круглосуточно",
        "latitude": 56.27050,
        "longitude": 44.00380,
        "sort_order": 210,
        "categories": ["ecotrail", "nature"],
        "images": [
            {
                "image_url": f"{MEDIA_BASE}/f81873f829b4b6d114e4f085790a1b78.png",
                "caption": "Дубрава и лесная тропа",
                "position": 0,
            },
        ],
        "reviews": [
            {
                "author_name": "Лиза",
                "rating": 5,
                "body": "Ощущение настоящего леса, хотя вы все еще в городе. Тропа спокойная и очень зеленая.",
            },
            {
                "author_name": "Федор",
                "rating": 4,
                "body": "Хорошее дополнение к музею деревянного зодчества: сначала лес и пруды, потом избы.",
            },
        ],
    },
]


def seed_more_points(apps, schema_editor):
    MapPoint = apps.get_model("map_points", "MapPoint")
    MapPointCategory = apps.get_model("map_points", "MapPointCategory")
    MapPointImage = apps.get_model("map_points", "MapPointImage")
    MapPointReview = apps.get_model("map_points", "MapPointReview")

    categories_by_slug = {
        category.slug: category
        for category in MapPointCategory.objects.filter(
            slug__in={"park", "nature", "museum", "sports", "ecotrail"}
        )
    }
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


def unseed_more_points(apps, schema_editor):
    MapPoint = apps.get_model("map_points", "MapPoint")
    MapPointCategory = apps.get_model("map_points", "MapPointCategory")

    MapPoint.objects.filter(slug__in=[item["slug"] for item in NEW_POINTS]).delete()
    MapPointCategory.objects.filter(
        slug__in=[item["slug"] for item in NEW_CATEGORIES]
    ).delete()


class Migration(migrations.Migration):
    dependencies = [
        ("map_points", "0009_mappoint_marker_color_and_category_color"),
    ]

    operations = [
        migrations.RunPython(seed_more_points, unseed_more_points),
    ]
