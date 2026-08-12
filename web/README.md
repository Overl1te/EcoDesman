# ЭкоВыхухоль Web

Next.js frontend для **ЭкоВыхухоль**: публичная лента, события, карта, профили, авторизация, пользовательские настройки, поддержка и административный интерфейс.

Production:

- сайт: [https://эковыхухоль.рф](https://эковыхухоль.рф)
- API: [https://api.эковыхухоль.рф/api/v1](https://api.эковыхухоль.рф/api/v1)

## Репозитории

- Web: [Overl1te/EcoDesman-web](https://github.com/Overl1te/EcoDesman-web)
- Backend: [Overl1te/EcoDesman-server](https://github.com/Overl1te/EcoDesman-server)
- Mobile: [Overl1te/EcoDesman-mobile](https://github.com/Overl1te/EcoDesman-mobile)

> [!IMPORTANT]
> Web не хранит production-инфраструктуру. TLS, nginx, PostgreSQL, backup и общий compose stack находятся в runtime-контуре backend-репозитория.

## Стек

- Next.js 16 App Router.
- React 19.
- TypeScript.
- `lucide-react` для иконок.
- MapLibre GL для карты.
- Docker image для production rollout через GHCR.

## Основные разделы

- `/` - лента публикаций.
- `/events` - события и календарный контент.
- `/map` - карта экоточек и пользовательских маркеров.
- `/favorites` - избранное.
- `/notifications` - уведомления.
- `/profile` и `/profiles/[id]` - свой и публичные профили.
- `/posts/new`, `/posts/[id]`, `/posts/[id]/edit` - публикации.
- `/support` - обращения в поддержку.
- `/help` - справка, документы и ссылки на репозитории.
- `/admin` - веб-интерфейс модерации.

## Локальный запуск

Сначала поднимите backend:

```bash
cd ../EcoDesman-server
docker compose up --build -d
```

Затем запустите web:

```bash
npm install
npm run dev
```

Откройте [http://localhost:3000](http://localhost:3000).

## Environment

Локально создайте `.env.local`:

```bash
NEXT_PUBLIC_API_BASE_URL=http://127.0.0.1:8000/api/v1
NEXT_PUBLIC_SITE_URL=http://localhost:3000
```

Production build обычно использует:

```bash
NEXT_PUBLIC_API_BASE_URL=/api/v1
NEXT_PUBLIC_SITE_URL=https://xn--b1apekb3anb5cpb.xn--p1ai
NEXT_PUBLIC_GOOGLE_SITE_VERIFICATION=
NEXT_PUBLIC_YANDEX_VERIFICATION=
```

> [!TIP]
> Относительный `NEXT_PUBLIC_API_BASE_URL=/api/v1` удобен для production: браузер ходит на тот же домен, а nginx проксирует запросы в Django.

## SEO

Сайт подготовлен для русскоязычной индексации:

- главная, карта, события, скачивание приложения и справка попадают в `sitemap.xml`;
- личные и служебные разделы закрыты от индексации через metadata и `robots.txt`;
- у публичных страниц есть русские `title`, `description`, canonical, Open Graph и карточки для соцсетей;
- в корень страницы добавлена JSON-LD разметка `Organization`, `WebSite` и `WebApplication`;
- `robots.txt` публикует ссылку на карту сайта и основной `Host`.

Проверочные адреса production:

- [https://эковыхухоль.рф/robots.txt](https://эковыхухоль.рф/robots.txt)
- [https://эковыхухоль.рф/sitemap.xml](https://эковыхухоль.рф/sitemap.xml)

> [!IMPORTANT]
> Для Google Search Console и Яндекс Вебмастера права можно подтвердить метатегом: положите значения в `NEXT_PUBLIC_GOOGLE_SITE_VERIFICATION` и `NEXT_PUBLIC_YANDEX_VERIFICATION`, затем пересоберите frontend.

## Production

Frontend pipeline:

1. устанавливает зависимости через `npm ci`;
2. запускает ESLint;
3. собирает Next.js;
4. собирает Docker image;
5. smoke-run проверяет порт `3000`;
6. пушит image в GHCR;
7. по SSH обновляет `FRONTEND_IMAGE` на VPS;
8. перезапускает только сервис `frontend`.

> [!CAUTION]
> Backend rollout не должен случайно перетирать frontend image, а frontend rollout не должен перезапускать базу данных или backend без необходимости.

## Проверка

```bash
npm run lint
npm run build
docker build .
```

## Архитектура

Подробнее: [`docs/frontend-architecture.md`](docs/frontend-architecture.md).
