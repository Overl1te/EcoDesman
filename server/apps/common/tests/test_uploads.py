import importlib
from urllib.parse import urlsplit

from django.core.files.base import ContentFile
from django.core.files.storage import Storage
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.urls import clear_url_caches, reverse

from apps.users.models import User


class FakeRemoteStorage(Storage):
    _files: dict[str, bytes] = {}

    def _open(self, name, mode="rb"):
        return ContentFile(self._files[name], name=name)

    def _save(self, name, content):
        self._files[name] = content.read()
        return name

    def exists(self, name):
        return False

    def url(self, name):
        return f"https://eco-desman.website.regru.cloud/{name}"


class FakeFailingStorage(Storage):
    def _open(self, name, mode="rb"):
        raise RuntimeError("storage read failure")

    def _save(self, name, content):
        raise RuntimeError("storage save failure")

    def exists(self, name):
        return False

    def url(self, name):
        return name


class ImageUploadViewTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="uploader",
            email="uploader@econizhny.local",
            password="demo12345",
        )

    def login(self) -> str:
        response = self.client.post(
            reverse("auth-login"),
            {
                "identifier": "uploader@econizhny.local",
                "password": "demo12345",
            },
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 200)
        return response.json()["access"]

    def test_authenticated_user_can_upload_image(self):
        access_token = self.login()
        upload = SimpleUploadedFile(
            "avatar.png",
            b"\x89PNG\r\n\x1a\nmock-image-content",
            content_type="image/png",
        )

        response = self.client.post(
            reverse("image-upload"),
            {"file": upload},
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(response.status_code, 201)
        self.assertIn("/media/uploads/", response.json()["url"])

    @override_settings(
        STORAGES={
            "default": {
                "BACKEND": "apps.common.tests.test_uploads.FakeRemoteStorage",
            },
            "staticfiles": {
                "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
            },
        }
    )
    def test_remote_storage_url_is_returned_without_local_media_prefix(self):
        FakeRemoteStorage._files = {}

        access_token = self.login()
        upload = SimpleUploadedFile(
            "remote-avatar.png",
            b"\x89PNG\r\n\x1a\nremote-image-content",
            content_type="image/png",
        )

        response = self.client.post(
            reverse("image-upload"),
            {"file": upload},
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(response.status_code, 201)
        self.assertTrue(
            response.json()["url"].startswith("https://eco-desman.website.regru.cloud/uploads/"),
        )

    @override_settings(DEBUG=False, SERVE_MEDIA_FILES=True)
    def test_uploaded_image_is_publicly_accessible_when_media_serving_enabled(self):
        import config.urls as root_urls

        clear_url_caches()
        importlib.reload(root_urls)

        access_token = self.login()
        upload = SimpleUploadedFile(
            "public-avatar.png",
            b"\x89PNG\r\n\x1a\npublic-image-content",
            content_type="image/png",
        )

        response = self.client.post(
            reverse("image-upload"),
            {"file": upload},
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(response.status_code, 201)
        media_path = urlsplit(response.json()["url"]).path

        media_response = self.client.get(media_path)

        self.assertEqual(media_response.status_code, 200)
        self.assertEqual(
            b"".join(media_response.streaming_content),
            b"\x89PNG\r\n\x1a\npublic-image-content",
        )

    @override_settings(
        STORAGES={
            "default": {
                "BACKEND": "apps.common.tests.test_uploads.FakeFailingStorage",
            },
            "staticfiles": {
                "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
            },
        }
    )
    def test_storage_errors_are_returned_as_service_unavailable(self):
        access_token = self.login()
        upload = SimpleUploadedFile(
            "broken-avatar.png",
            b"\x89PNG\r\n\x1a\nbroken-image-content",
            content_type="image/png",
        )

        response = self.client.post(
            reverse("image-upload"),
            {"file": upload},
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.json()["detail"],
            "Сервис загрузки фото временно недоступен",
        )
