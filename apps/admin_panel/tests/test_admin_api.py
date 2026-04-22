from django.test import TestCase
from django.urls import reverse

from apps.map_points.models import MapPoint, MapPointCategory, UserMapMarker
from apps.posts.models import Post
from apps.users.models import User


class AdminApiTests(TestCase):
    def login(self, identifier="admin@econizhny.local", password="demo12345") -> str:
        response = self.client.post(
            reverse("auth-login"),
            {
                "identifier": identifier,
                "password": password,
            },
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 200)
        return response.json()["access"]

    def test_regular_user_cannot_access_admin_api(self):
        access_token = self.login(identifier="anna@econizhny.local")

        response = self.client.get(
            reverse("admin-overview"),
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(response.status_code, 403)

    def test_superuser_can_access_admin_api(self):
        User.objects.create_superuser(
            username="root",
            email="root@econizhny.local",
            password="demo12345",
        )
        access_token = self.login(identifier="root@econizhny.local")

        response = self.client.get(
            reverse("admin-user-list"),
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(response.status_code, 200)
        self.assertGreaterEqual(response.json()["count"], 1)

    def test_admin_post_list_includes_drafts(self):
        author = User.objects.get(email="anna@econizhny.local")
        draft = Post.objects.create(
            author=author,
            title="Admin draft",
            body="Visible only inside admin list",
            kind=Post.Kind.NEWS,
            is_published=False,
        )
        access_token = self.login()

        response = self.client.get(
            reverse("admin-post-list"),
            {"search": "Admin draft"},
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["results"][0]["id"], draft.id)
        self.assertFalse(response.json()["results"][0]["is_published"])

    def test_admin_users_list_includes_private_fields(self):
        access_token = self.login()

        response = self.client.get(
            reverse("admin-user-list"),
            {"search": "anna"},
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(response.status_code, 200)
        anna = next(item for item in response.json()["results"] if item["username"] == "anna")
        self.assertEqual(anna["email"], "anna@econizhny.local")
        self.assertIn("can_access_admin", anna)

    def test_admin_can_create_update_and_delete_map_point(self):
        access_token = self.login()
        category = MapPointCategory.objects.get(slug="paper")

        create_response = self.client.post(
            reverse("admin-map-point-list"),
            {
                "slug": "admin-managed-point",
                "title": "Admin managed point",
                "short_description": "Created from custom admin",
                "description": "Point managed from custom admin api",
                "address": "Bolshaya Pokrovskaya",
                "working_hours": "10:00-18:00",
                "latitude": 56.320123,
                "longitude": 44.012345,
                "is_active": True,
                "sort_order": 9,
                "category_ids": [category.id],
                "image_urls": ["https://example.com/admin-point.jpg"],
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(create_response.status_code, 201)
        point_id = create_response.json()["id"]
        self.assertEqual(create_response.json()["categories"][0]["slug"], "paper")
        self.assertEqual(create_response.json()["images"][0]["image_url"], "https://example.com/admin-point.jpg")

        update_response = self.client.patch(
            reverse("admin-map-point-detail", kwargs={"point_id": point_id}),
            {
                "title": "Admin managed point updated",
                "is_active": False,
                "image_urls": ["https://example.com/admin-point-updated.jpg"],
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(update_response.status_code, 200)
        self.assertEqual(update_response.json()["title"], "Admin managed point updated")
        self.assertFalse(update_response.json()["is_active"])
        self.assertEqual(
            update_response.json()["images"][0]["image_url"],
            "https://example.com/admin-point-updated.jpg",
        )

        delete_response = self.client.delete(
            reverse("admin-map-point-detail", kwargs={"point_id": point_id}),
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(delete_response.status_code, 204)
        self.assertFalse(MapPoint.objects.filter(id=point_id).exists())

    def test_admin_can_hide_user_map_marker(self):
        marker = UserMapMarker.objects.create(
            author=User.objects.get(email="anna@econizhny.local"),
            title="Пользовательская метка",
            description="Нужна модерация",
            latitude=56.321,
            longitude=44.021,
        )
        access_token = self.login()

        list_response = self.client.get(
            reverse("admin-user-map-marker-list"),
            {"search": "Пользовательская"},
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(list_response.status_code, 200)
        self.assertEqual(list_response.json()["results"][0]["id"], marker.id)

        update_response = self.client.patch(
            reverse("admin-user-map-marker-detail", kwargs={"marker_id": marker.id}),
            {
                "is_active": False,
                "moderation_note": "Скрыто до уточнения описания.",
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(update_response.status_code, 200)
        self.assertFalse(update_response.json()["is_active"])
        marker.refresh_from_db()
        self.assertFalse(marker.is_active)
