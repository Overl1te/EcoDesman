# ЭкоВыхухоль Mobile

Flutter-клиент для **ЭкоВыхухоль**. Приложение работает с Django API, хранит локальную сессию, показывает ленту, карту, события, профили, уведомления и поддержку.

Production API:

- [https://api.эковыхухоль.рф/api/v1](https://api.эковыхухоль.рф/api/v1)

## Репозитории

- Mobile: [Overl1te/EcoDesman-mobile](https://github.com/Overl1te/EcoDesman-mobile)
- Backend: [Overl1te/EcoDesman-server](https://github.com/Overl1te/EcoDesman-server)
- Web: [Overl1te/EcoDesman-web](https://github.com/Overl1te/EcoDesman-web)

> [!IMPORTANT]
> Мобильное приложение не должно содержать секреты backend-инфраструктуры. Оно получает только публичный `API_BASE_URL` и работает через HTTPS.

## Стек

- Dart SDK `^3.10.7`.
- Riverpod для состояния.
- Dio для HTTP-клиента.
- GoRouter для навигации.
- MapLibre для карты.
- Shared Preferences для локального хранения.
- Local notifications для уведомлений.
- `url_launcher` для внешних ссылок и PDF.

## Реализовано

- splash screen и восстановление сессии;
- login и guest mode;
- лента с обновлением, пагинацией, лайками, избранным, комментариями и просмотрами;
- детальная страница публикации;
- создание и редактирование публикаций;
- свой профиль, настройки и публичные профили;
- карта экоточек и пользовательских маркеров;
- события;
- уведомления;
- справка, PDF-документы и поддержка.

## Запуск

Установите зависимости:

```bash
flutter pub get
```

Поднимите backend из соседнего репозитория:

```bash
cd ../EcoDesman-server
docker compose up --build -d
```

Production API:

```bash
flutter run --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.xn--b1apekb3anb5cpb.xn--p1ai/api/v1
```

Через основной домен тоже работает:

```bash
flutter run --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://xn--b1apekb3anb5cpb.xn--p1ai/api/v1
```

Локальный Android emulator, если backend поднят на этой же машине:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

iOS simulator или desktop с локальным backend:

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Physical Android over USB:

```bash
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Physical Android over Wi-Fi:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000/api/v1
```

> [!TIP]
> Для проверки production-сценариев используйте HTTPS API-домен. Так проще поймать проблемы CORS, CSRF, mixed content и сертификатов до релиза.

## Demo accounts

- `anna@econizhny.local` / `demo12345`
- `ivan@econizhny.local` / `demo12345`
- `admin@econizhny.local` / `demo12345`

> [!CAUTION]
> Demo accounts подходят только для dev/staging. Не используйте эти пароли в production.

## Автоматические релизы

GitHub Actions workflow `.github/workflows/mobile-release.yml` собирает Android release APK и AAB, берет версию из `pubspec.yaml` и публикует файлы в GitHub Releases.

Запуск:

- автоматически при push тега вида `v1.1.0+2`;
- вручную через `workflow_dispatch`.

Текущая версия берется из:

```yaml
version: 1.1.0+2
```

Для релиза workflow ожидает тег `v1.1.0+2`. Если tag и `pubspec.yaml` не совпадают, сборка остановится.

```bash
git tag v1.1.0+2
git push origin v1.1.0+2
```

Артефакты релиза:

- `EcoDesman-1.1.0+2.apk`
- `EcoDesman-1.1.0+2.aab`, если Android toolchain успешно собрал app bundle
- `EcoDesman-1.1.0+2-sha256.txt`

> [!IMPORTANT]
> Для нормальной Android release-подписи добавьте в GitHub Secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Без этих секретов проект соберется с debug signing fallback, что удобно для тестовой установки, но не подходит для магазина.

## Проверка

```bash
flutter analyze
flutter test
```

## Архитектура

Подробнее: [`docs/architecture.md`](docs/architecture.md).
