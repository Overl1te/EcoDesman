# ЭкоВыхухоль Server

Django backend для `ЭкоВыхухоль`. Веб-клиент живет отдельно на Next.js, а этот репозиторий отвечает за API, админку, авторизацию, загрузки, бэкапы и production-стек.

## API

- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/register`
- `GET/PATCH /api/v1/auth/me`
- `GET /api/v1/profiles/{id}`
- `GET /api/v1/posts`
- `GET /api/v1/posts/{id}`
- `POST /api/v1/posts`
- `PATCH /api/v1/posts/{id}`
- `DELETE /api/v1/posts/{id}`
- `POST /api/v1/posts/{id}/like`
- `DELETE /api/v1/posts/{id}/like`
- `GET/POST /api/v1/posts/{id}/comments`
- `GET /api/v1/map/overview`
- `GET /api/v1/notifications`
- `GET /api/v1/health/`

## Production Stack

Production работает как runtime-only `docker compose` стек:

- `db`: PostgreSQL
- `web`: Django API из GHCR-образа
- `frontend`: Next.js из отдельного GHCR-образа
- `proxy`: Nginx reverse proxy
- `backup`: ежедневные backup-задачи

Схема роутинга:

- `http://SERVER_IP/` -> Next.js
- `http://SERVER_IP/api/v1/...` -> Django API
- `http://SERVER_IP/admin` -> кастомная Next.js админка
- `http://SERVER_IP/django-admin/` -> встроенная Django admin
- `http://example.com` -> Next.js
- `http://example.com/admin` -> кастомная Next.js админка
- `http://api.example.com` -> Django API
- `http://api.example.com/django-admin/` -> встроенная Django admin

Сервер намеренно работает только по `HTTP` на `80/tcp`.
Привязка домена сама по себе не включает SSL: в стеке нет certbot, ACME automation, Caddy, Traefik или listener на `443`.

## Local Docker Run

```bash
docker compose up --build -d
docker compose ps
```

Остановка:

```bash
docker compose down
```

С удалением БД:

```bash
docker compose down -v
```

Проверка:

```bash
curl http://127.0.0.1:8000/api/v1/health/
curl http://127.0.0.1:8000/
```

## Environment

Основной env-файл лежит здесь:

- `~/EcoDesman-server/.env`

Шаблон:

- [`.env.production.example`](C:/Users/maksi/Documents/GitHub/EcoDesman-server/.env.production.example)

Ключевые переменные для split `site + api`:

- `SITE_DOMAIN=example.com`
- `API_DOMAIN=api.example.com`
- `NEXT_PUBLIC_API_BASE_URL=http://api.example.com/api/v1`
- `DJANGO_ALLOWED_HOSTS=...,api.example.com`
- `DJANGO_CSRF_TRUSTED_ORIGINS=...,http://api.example.com`
- `DJANGO_CORS_ALLOWED_ORIGINS=...,http://example.com,http://www.example.com`

Для дебага compose также публикует внутренние сервисы только на localhost:

- `API_BIND_PORT=18000`
- `FRONTEND_BIND_PORT=13000`

Публичный reverse proxy наружу отдается через:

- `WEB_PORT=80`

## DNS

Минимум для поддоменов:

1. `A @ -> 130.49.150.192`
2. `A api -> 130.49.150.192`
3. `A www -> 130.49.150.192` или `CNAME www -> @`

Пока DNS не настроен, сайт все равно доступен по IP:

- `http://130.49.150.192/`
- `http://130.49.150.192/api/v1/health/`

## S3 Media Storage

Для S3:

- `DJANGO_USE_S3_MEDIA=true`
- `DJANGO_SERVE_MEDIA=false`
- `AWS_STORAGE_BUCKET_NAME=<bucket>`
- `AWS_S3_ENDPOINT_URL=<endpoint>`
- `AWS_S3_ACCESS_KEY_ID=<access-key>`
- `AWS_S3_SECRET_ACCESS_KEY=<secret-key>`

Для REG.RU S3:

- `AWS_S3_ADDRESSING_STYLE=path`
- `AWS_S3_VERIFY=/usr/lib/ssl/cert.pem`
- `AWS_QUERYSTRING_AUTH=false`
- `AWS_S3_OBJECT_ACL=public-read`

## Logs

Логи пишутся в:

- `./runtime_logs/django.log`
- `./runtime_logs/django.error.log`
- `./runtime_logs/gunicorn_access.log`
- `./runtime_logs/gunicorn_error.log`
- `./runtime_logs/nginx_access.log`
- `./runtime_logs/nginx_error.log`
- `./runtime_logs/backup.log`

## Daily Backups

`backup` service:

- делает ежедневный dump PostgreSQL
- архивирует `runtime_logs`
- грузит backup и архив логов в S3
- чистит старые локальные и удаленные архивы

Настройки:

- `BACKUP_TIMEZONE=Europe/Moscow`
- `BACKUP_SCHEDULE_HOUR=3`
- `BACKUP_SCHEDULE_MINUTE=0`
- `BACKUP_RETENTION_DAYS=7`
- `BACKUP_S3_PREFIX=ops`
- `BACKUP_S3_BUCKET_NAME=`
- `BACKUP_RUN_ON_START=false`

Локальные backup-файлы:

- `./backups/db/*.dump`
- `./backups/logs/*.tar.gz`

Восстановление:

```bash
./restore_db.sh ops/db/econizhny-20260402-030000.dump
```

Можно передать и локальный путь к `.dump`.

## VPS Deploy

Рабочая схема сервера:

- на VPS хранится только runtime-папка, например `~/eco-desman`
- в ней лежат `compose.yaml`, `.env`, `deploy/nginx/default.conf.template`, каталоги логов и backup
- сами приложения приезжают как pinned образы из GHCR

Backend CI/CD:

- проверяет код
- собирает и пушит backend image в GHCR
- по SSH обновляет runtime `compose.yaml` и `default.conf.template` на сервере
- записывает новый `BACKEND_IMAGE` в `.env`
- делает `docker compose pull` только для `web` и `backup` в рамках deploy
- перезапускает только `web`, `backup` и `proxy`
- не тянет и не перекатывает `frontend` образ: он должен обновляться своим отдельным pipeline

Из-за приватного GHCR сервер не должен зависеть от `pull_policy: always`: обычный локальный `docker compose up -d` использует уже скачанные pinned images и не требует нового login в registry.

## Verification

```bash
python manage.py check
python manage.py test
docker compose config
docker compose up --build -d
```
