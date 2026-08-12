from django.test import TestCase, override_settings
from django.urls import reverse


TEST_STORAGES = {
    "default": {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
    },
    "staticfiles": {
        "BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage",
    },
}


@override_settings(STORAGES=TEST_STORAGES)
class HealthcheckViewTests(TestCase):
    def test_root_redirects_to_healthcheck(self):
        response = self.client.get("/", follow=False)

        self.assertEqual(response.status_code, 302)
        self.assertEqual(response["Location"], "/api/v1/health/")

    def test_healthcheck_returns_ok(self):
        response = self.client.get(reverse("healthcheck"))

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ok")

    def test_django_admin_is_mounted_on_dedicated_url(self):
        self.assertEqual(reverse("admin:index"), "/django-admin/")

    def test_legacy_admin_url_redirects_to_dedicated_url(self):
        response = self.client.get("/admin/", follow=False)

        self.assertEqual(response.status_code, 302)
        self.assertEqual(response["Location"], "/django-admin/")
