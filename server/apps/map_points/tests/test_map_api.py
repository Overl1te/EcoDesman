from django.test import TestCase
from django.urls import reverse

from apps.map_points.models import (
    MapPoint,
    MapPointReview,
    MapPointReviewImage,
    UserMapMarker,
    UserMapMarkerComment,
)
from apps.users.models import User


class MapApiTests(TestCase):
    def login(self, identifier="anna@econizhny.local", password="demo12345") -> str:
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

    def test_map_overview_returns_categories_and_point_summaries(self):
        hidden_point = MapPoint.objects.create(
            slug="hidden-point",
            title="Скрытая точка",
            short_description="Не должна отображаться",
            latitude=56.300000,
            longitude=44.000000,
            is_active=False,
            sort_order=999,
        )

        response = self.client.get(reverse("map-overview"))

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["bounds"]["south"], 56.230306)
        self.assertEqual(payload["bounds"]["east"], 44.157004)
        self.assertGreaterEqual(len(payload["categories"]), 5)
        self.assertGreaterEqual(len(payload["points"]), 5)
        self.assertNotIn(hidden_point.slug, [item["slug"] for item in payload["points"]])

        self.assertIn("color", payload["categories"][0])

        first_point = payload["points"][0]
        self.assertIn("categories", first_point)
        self.assertIn("short_description", first_point)
        self.assertIn("cover_image_url", first_point)
        self.assertIn("primary_category", first_point)
        self.assertIn("marker_color", first_point)

        expected_new_slugs = {
            "park-shveitsariya",
            "meshcherskoe-ozero",
            "botanic-garden-nngu",
            "burnakovskaya-ecotrail",
            "artemovsky-meadows",
            "dubki-park",
            "kulibin-park",
            "maryina-roshcha",
        }
        self.assertTrue(expected_new_slugs.issubset({item["slug"] for item in payload["points"]}))

        ecotrail = next(item for item in payload["categories"] if item["slug"] == "ecotrail")
        self.assertEqual(ecotrail["title"], "Экотропа")
        self.assertEqual(ecotrail["color"], "#2F7D5B")

        paper_point = next(item for item in payload["points"] if item["slug"] == "paper")
        self.assertEqual(paper_point["primary_category"]["slug"], "paper")
        self.assertEqual(
            [item["slug"] for item in paper_point["categories"]],
            ["paper", "pickup"],
        )
        self.assertEqual(paper_point["primary_category"]["color"], "#2E6DB4")
        self.assertEqual(paper_point["marker_color"], "#2E6DB4")

    def test_map_point_detail_returns_gallery_reviews_and_metadata(self):
        point = MapPoint.objects.get(slug="ecopunkt")
        review = point.reviews.first()
        self.assertIsNotNone(review)
        MapPointReviewImage.objects.create(
            review=review,
            image_url="https://example.com/review-photo.jpg",
            position=0,
        )

        response = self.client.get(
            reverse("map-point-detail", kwargs={"point_id": point.id})
        )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["slug"], "ecopunkt")
        self.assertGreaterEqual(len(payload["images"]), 2)
        self.assertGreaterEqual(len(payload["reviews"]), 1)
        self.assertGreaterEqual(len(payload["categories"]), 1)
        self.assertTrue(payload["description"])
        self.assertTrue(payload["address"])
        self.assertEqual(
            payload["reviews"][0]["images"][0]["image_url"],
            "https://example.com/review-photo.jpg",
        )
        self.assertEqual(payload["primary_category"]["slug"], "eco-center")
        self.assertEqual(payload["primary_category"]["color"], "#0E7A53")
        self.assertEqual(payload["marker_color"], "#0E7A53")

    def test_authenticated_user_can_create_review_for_point(self):
        point = MapPoint.objects.get(slug="ecopunkt")
        access_token = self.login()
        author = User.objects.get(email="anna@econizhny.local")
        review_body = "Очень удобная точка, все чисто и понятно."

        response = self.client.post(
            reverse("map-point-review-create", kwargs={"point_id": point.id}),
            {
                "rating": 5,
                "body": review_body,
                "image_urls": [
                    "https://example.com/review-photo-1.jpg",
                    "https://example.com/review-photo-2.jpg",
                ],
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(response.status_code, 201)
        payload = response.json()
        self.assertEqual(payload["rating"], 5)
        self.assertEqual(payload["author_name"], author.display_name)
        self.assertEqual(len(payload["images"]), 2)
        self.assertEqual(
            payload["images"][0]["image_url"],
            "https://example.com/review-photo-1.jpg",
        )
        self.assertTrue(
            MapPointReview.objects.filter(
                point=point,
                body=review_body,
                author=author,
            ).exists()
        )
        created_review = MapPointReview.objects.get(
            point=point,
            body=review_body,
            author=author,
        )
        self.assertEqual(created_review.images.count(), 2)

    def test_review_create_requires_authentication(self):
        point = MapPoint.objects.get(slug="ecopunkt")

        response = self.client.post(
            reverse("map-point-review-create", kwargs={"point_id": point.id}),
            {
                "rating": 4,
                "body": "Без входа отзыв не должен создаться.",
            },
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 401)

    def test_authenticated_user_can_create_marker_with_media_and_comment(self):
        access_token = self.login()

        create_response = self.client.post(
            reverse("user-map-marker-list"),
            {
                "title": "Тихий вид на Оку",
                "description": "Небольшая точка с хорошим видом и лавочкой.",
                "latitude": 56.314,
                "longitude": 43.992,
                "is_public": True,
                "media": [
                    {
                        "media_url": "https://example.com/place.jpg",
                        "media_type": "image",
                    },
                    {
                        "media_url": "https://example.com/place.mp4",
                        "media_type": "video",
                    },
                ],
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(create_response.status_code, 201)
        marker_id = create_response.json()["id"]
        self.assertEqual(create_response.json()["media"][1]["media_type"], "video")

        overview_response = self.client.get(reverse("map-overview"))
        self.assertEqual(overview_response.status_code, 200)
        self.assertIn(
            marker_id,
            [item["id"] for item in overview_response.json()["user_markers"]],
        )

        comment_response = self.client.post(
            reverse(
                "user-map-marker-comment-create",
                kwargs={"marker_id": marker_id},
            ),
            {"body": "Подтверждаю, место спокойное."},
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(comment_response.status_code, 201)
        self.assertTrue(
            UserMapMarkerComment.objects.filter(marker_id=marker_id).exists()
        )

    def test_private_marker_is_visible_only_to_owner(self):
        owner = User.objects.get(email="anna@econizhny.local")
        marker = UserMapMarker.objects.create(
            author=owner,
            title="Личная заметка",
            description="Показывается только автору",
            latitude=56.301,
            longitude=44.001,
            is_public=False,
        )

        public_response = self.client.get(reverse("map-overview"))
        self.assertEqual(public_response.status_code, 200)
        self.assertNotIn(
            marker.id,
            [item["id"] for item in public_response.json()["user_markers"]],
        )

        access_token = self.login(owner.email)
        owner_response = self.client.get(
            reverse("map-overview"),
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )
        self.assertEqual(owner_response.status_code, 200)
        self.assertIn(
            marker.id,
            [item["id"] for item in owner_response.json()["user_markers"]],
        )
