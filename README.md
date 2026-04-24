# ЭкоВыхухоль Server

Django backend для проекта **ЭкоВыхухоль**. Репозиторий отвечает за API, авторизацию, профили, публикации, карту, поддержку, юридические документы, загрузки медиа, backup-задачи и production runtime stack.

Рабочий production:

- сайт: [https://эковыхухоль.рф](https://эковыхухоль.рф)
- API: [https://api.эковыхухоль.рф/api/v1](https://api.эковыхухоль.рф/api/v1)
- healthcheck: [https://api.эковыхухоль.рф/api/v1/health/](https://api.эковыхухоль.рф/api/v1/health/)
- Django admin: `https://api.эковыхухоль.рф/django-admin/`

## Репозитории

- Backend: [Overl1te/EcoDesman-server](https://github.com/Overl1te/EcoDesman-server)
- Web: [Overl1te/EcoDesman-web](https://github.com/Overl1te/EcoDesman-web)
- Mobile: [Overl1te/EcoDesman-mobile](https://github.com/Overl1te/EcoDesman-mobile)

> [!IMPORTANT]
> Runtime-файлы VPS, сертификаты, `.env`, backup-архивы и локальные nginx overrides не должны попадать в git. В репозитории хранится воспроизводимый код и шаблоны, а не секреты окружения.

## Что внутри

- Django 6 + Django REST Framework.
- JWT-аутентификация через `djangorestframework-simplejwt`.
- PostgreSQL в production compose.
- Nginx reverse proxy перед web и API.
- Next.js frontend как отдельный GHCR image из `EcoDesman-web`.
- Ежедневные backup-задачи PostgreSQL и логов.
- S3-compatible media storage через `django-storages`.
- Help center API с PDF-документами.

## API

Базовый путь: `/api/v1`.

Основные группы:

- `POST /auth/login`, `POST /auth/refresh`, `POST /auth/register`
- `GET /auth/social/providers`, `POST /auth/social/{provider}`
- `GET/PATCH /auth/me`
- `GET /profiles/{id}`
- `GET/POST /posts`
- `GET/PATCH/DELETE /posts/{id}`
- `POST /posts/{id}/like`
- `POST /posts/{id}/favorite`
- `GET/POST /posts/{id}/comments`
- `GET /posts/calendar`
- `POST /posts/{id}/report`
- `GET /map/overview`
- `GET /map/points/{id}`
- `POST /map/points/{id}/reviews`
- `GET /notifications`
- `GET /support/help-center`
- `GET /support/help-center/{slug}`
- `GET /support/legal-documents/{slug}/download`
- `POST /support/threads`
- `GET /health/`

## Локальный запуск

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements/base.txt
python manage.py migrate
python manage.py runserver
```

Windows PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements\base.txt
python manage.py migrate
python manage.py runserver
```

Проверка:

```bash
curl http://127.0.0.1:8000/api/v1/health/
```

## Docker Compose

Локальный стек:

```bash
docker compose up --build -d
docker compose ps
```

Остановка:

```bash
docker compose down
```

Остановка с удалением volumes:

```bash
docker compose down -v
```

> [!TIP]
> Для frontend-разработки можно поднять backend через compose, а web запускать отдельно из `EcoDesman-web` на `http://localhost:3000`.

## Environment

Шаблон production-переменных: [`.env.production.example`](.env.production.example).

Ключевые переменные:

- `DJANGO_SECRET_KEY`
- `DJANGO_DEBUG=false`
- `DJANGO_ALLOWED_HOSTS`
- `DJANGO_CSRF_TRUSTED_ORIGINS`
- `DJANGO_CORS_ALLOWED_ORIGINS`
- `SITE_DOMAIN=xn--b1apekb3anb5cpb.xn--p1ai`
- `API_DOMAIN=api.xn--b1apekb3anb5cpb.xn--p1ai`
- `NEXT_PUBLIC_SITE_URL=https://xn--b1apekb3anb5cpb.xn--p1ai`
- `NEXT_PUBLIC_API_BASE_URL=/api/v1`
- `WEB_PORT=80`
- `WEB_SSL_PORT=443`

> [!CAUTION]
> `DJANGO_ALLOWED_HOSTS`, CSRF origins и CORS origins должны совпадать с реальными доменами. Если добавить новый публичный поддомен, его нужно добавить и в nginx/TLS, и в Django env.

## Production stack

Production на VPS работает как runtime-only Docker Compose stack:

- `db`: PostgreSQL 16.
- `web`: Django API из GHCR.
- `frontend`: Next.js image из GHCR.
- `proxy`: Nginx reverse proxy.
- `backup`: планировщик backup-задач.

Схема маршрутов:

- `https://эковыхухоль.рф/` -> Next.js.
- `https://эковыхухоль.рф/api/v1/...` -> Django API через общий домен.
- `https://api.эковыхухоль.рф/api/v1/...` -> Django API через API-домен.
- `https://api.эковыхухоль.рф/django-admin/` -> Django admin.

## TLS

На VPS используется Let's Encrypt сертификат для:

- `xn--b1apekb3anb5cpb.xn--p1ai`
- `www.xn--b1apekb3anb5cpb.xn--p1ai`
- `api.xn--b1apekb3anb5cpb.xn--p1ai`

Автопродление настроено на сервере через cron и Docker certbot. Сертификаты лежат в runtime-каталоге VPS, а не в git.

> [!IMPORTANT]
> Wildcard-сертификат `*.эковыхухоль.рф` требует DNS-валидации. Обычная HTTP-валидация Let's Encrypt покрывает только явно указанные имена.

## DNS

Минимальные A-записи:

- `@ -> 194.67.66.200`
- `www -> 194.67.66.200`
- `api -> 194.67.66.200`

## Media storage

Локально медиа может обслуживать Django. Для S3-compatible storage:

```bash
DJANGO_USE_S3_MEDIA=true
DJANGO_SERVE_MEDIA=false
AWS_STORAGE_BUCKET_NAME=<bucket>
AWS_S3_ENDPOINT_URL=<endpoint>
AWS_S3_ACCESS_KEY_ID=<access-key>
AWS_S3_SECRET_ACCESS_KEY=<secret-key>
```

Для path-style S3:

```bash
AWS_S3_ADDRESSING_STYLE=path
AWS_QUERYSTRING_AUTH=false
AWS_S3_OBJECT_ACL=public-read
```

## Backups

`backup` service:

- делает ежедневный dump PostgreSQL;
- архивирует runtime logs;
- может выгружать backup и логи в S3;
- чистит старые локальные и удаленные архивы.

Настройки:

- `BACKUP_TIMEZONE=Europe/Moscow`
- `BACKUP_SCHEDULE_HOUR=3`
- `BACKUP_SCHEDULE_MINUTE=0`
- `BACKUP_RETENTION_DAYS=7`
- `BACKUP_S3_PREFIX=ops`
- `BACKUP_S3_BUCKET_NAME=`
- `BACKUP_RUN_ON_START=false`

Восстановление:

```bash
./restore_db.sh ops/db/econizhny-20260402-030000.dump
```

## CI/CD

Backend pipeline:

1. запускает Ruff, compileall, Django checks и migration drift check;
2. собирает Docker image;
3. smoke-run проверяет `/api/v1/health/`;
4. пушит image в GHCR;
5. по SSH обновляет backend image на VPS;
6. перезапускает только `web`, `backup` и `proxy`.

Frontend image обновляется отдельным pipeline из `EcoDesman-web`.

## Проверка перед релизом

```bash
python manage.py check
python manage.py test
docker compose config
docker compose up --build -d
```
