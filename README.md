# ЭкоВыхухоль (EcoDesman)

Монорепозиторий цифровой платформы для экоактивистов: Django API, Next.js web и Flutter mobile.

- сайт: [https://эковыхухоль.рф](https://эковыхухоль.рф)
- API: [https://эковыхухоль.рф/api/v1](https://эковыхухоль.рф/api/v1)

## Структура

```
server/   # Django API + ops/backup
web/      # Next.js frontend
mobile/   # Flutter Android/iOS
deploy/   # nginx, certbot templates
compose.yaml
```

Образы GHCR (собираются отдельно в CI):

- `ghcr.io/overl1te/ecodesman-server`
- `ghcr.io/overl1te/ecodesman-web`

## CI

Server и web собираются на **self-hosted** runner. Мобилка — на **GitHub-hosted** `ubuntu-latest`.

- `server-ci.yml` — lint/check + build/push `ghcr.io/overl1te/ecodesman-server`
- `web-ci.yml` — lint/build + build/push `ghcr.io/overl1te/ecodesman-web`
- `mobile-ci.yml` — analyze/test/debug APK
- `mobile-release.yml` — signed APK/AAB и GitHub Release при пуше в `mobile/**` на `master`

Для Android release-подписи нужны secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Без них релиз собирается с debug-подписью и помечается prerelease.

## Локальный стек (Docker)

```bash
cp .env.production.example .env
# при необходимости поправьте секреты

docker compose up --build -d
docker compose ps
curl http://127.0.0.1/api/v1/health/
```

По умолчанию медиа хранятся локально (`DJANGO_USE_S3_MEDIA=false`, volume `media_data`). Код S3 оставлен — включите флагом и переменными `AWS_*`, когда понадобится.

Образы можно не собирать, а тянуть из GHCR:

```bash
docker compose pull
docker compose up -d
```

## Разработка по модулям

### Server

```bash
cd server
python -m venv .venv
# Windows: .\.venv\Scripts\Activate.ps1
source .venv/bin/activate
pip install -r requirements/base.txt
python manage.py migrate
python manage.py runserver
```

### Web

```bash
cd web
npm ci
npm run dev
```

### Mobile

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

## Environment

Шаблон: [`.env.production.example`](.env.production.example).

Ключевые переменные: `DJANGO_SECRET_KEY`, `POSTGRES_*`, `BACKEND_IMAGE`, `FRONTEND_IMAGE`, `DJANGO_SERVE_MEDIA`, `DJANGO_USE_S3_MEDIA`.

> Runtime-файлы VPS, сертификаты, `.env`, backup-архивы и локальные nginx overrides не коммитятся.
