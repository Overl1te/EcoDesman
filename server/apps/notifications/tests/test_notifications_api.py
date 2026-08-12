from django.test import TestCase
from django.urls import reverse

from apps.posts.models import Post
from apps.users.models import User


class NotificationApiTests(TestCase):
    def login(self, identifier: str, password: str = "demo12345") -> str:
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

    def test_like_and_comment_create_notifications(self):
        actor_token = self.login("ivan@econizhny.local")
        post = Post.objects.filter(author__email="anna@econizhny.local", is_published=True).first()

        like_response = self.client.post(
            reverse("post-like", kwargs={"post_id": post.id}),
            HTTP_AUTHORIZATION=f"Bearer {actor_token}",
        )
        self.assertEqual(like_response.status_code, 200)

        comment_response = self.client.post(
            reverse("post-comments", kwargs={"post_id": post.id}),
            {"body": "Буду на событии"},
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {actor_token}",
        )
        self.assertEqual(comment_response.status_code, 201)

        owner_token = self.login("anna@econizhny.local")
        list_response = self.client.get(
            reverse("notification-list"),
            HTTP_AUTHORIZATION=f"Bearer {owner_token}",
        )
        self.assertEqual(list_response.status_code, 200)
        self.assertEqual(list_response.json()["unread_count"], 2)
        self.assertEqual(len(list_response.json()["results"]), 2)

    def test_owner_can_mark_notifications_read(self):
        owner = User.objects.get(email="anna@econizhny.local")
        actor = User.objects.get(email="ivan@econizhny.local")
        post = Post.objects.filter(author=owner, is_published=True).first()

        actor_token = self.login(actor.email)
        self.client.post(
            reverse("post-like", kwargs={"post_id": post.id}),
            HTTP_AUTHORIZATION=f"Bearer {actor_token}",
        )
        owner_token = self.login(owner.email)
        list_response = self.client.get(
            reverse("notification-list"),
            HTTP_AUTHORIZATION=f"Bearer {owner_token}",
        )
        notification_id = list_response.json()["results"][0]["id"]

        read_response = self.client.post(
            reverse("notification-read", kwargs={"notification_id": notification_id}),
            HTTP_AUTHORIZATION=f"Bearer {owner_token}",
        )
        self.assertEqual(read_response.status_code, 200)
        self.assertTrue(read_response.json()["is_read"])

        read_all_response = self.client.post(
            reverse("notification-read-all"),
            HTTP_AUTHORIZATION=f"Bearer {owner_token}",
        )
        self.assertEqual(read_all_response.status_code, 200)
