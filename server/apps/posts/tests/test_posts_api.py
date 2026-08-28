from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from apps.posts.models import Post, PostComment, PostFavorite, PostImage, PostLike, PostView
from apps.users.models import User


class PostApiTests(TestCase):
    def login(self, identifier="anna@econizhny.local", password="demo12345") -> str:
        from apps.users.tests.helpers import access_token_for

        return access_token_for(identifier)

    def test_post_list_returns_accurate_counts(self):
        author = User.objects.get(email="anna@econizhny.local")
        first_liker = User.objects.get(email="ivan@econizhny.local")
        second_liker = User.objects.get(email="admin@econizhny.local")
        post = Post.objects.create(
            author=author,
            title="Count verification post",
            body="Post with multiple relations for count verification",
            kind=Post.Kind.NEWS,
            is_published=True,
        )
        PostImage.objects.bulk_create(
            [
                PostImage(post=post, image_url="https://example.com/1.jpg", position=0),
                PostImage(post=post, image_url="https://example.com/2.jpg", position=1),
            ]
        )
        PostLike.objects.bulk_create(
            [
                PostLike(post=post, user=first_liker),
                PostLike(post=post, user=second_liker),
            ]
        )
        PostComment.objects.bulk_create(
            [
                PostComment(post=post, author=author, body="First"),
                PostComment(post=post, author=first_liker, body="Second"),
            ]
        )
        PostFavorite.objects.create(post=post, user=first_liker)

        response = self.client.get(reverse("post-list"), {"search": "Count verification"})

        self.assertEqual(response.status_code, 200)
        result = response.json()["results"][0]
        self.assertEqual(result["likes_count"], 2)
        self.assertEqual(result["comments_count"], 2)
        self.assertEqual(result["favorites_count"], 1)

    def test_post_detail_returns_images_comments_and_event_fields(self):
        post = Post.objects.create(
            author=User.objects.get(email="anna@econizhny.local"),
            title="Cleanup Day",
            body="Meet near the river",
            kind=Post.Kind.EVENT,
            is_published=True,
            event_starts_at=timezone.now() + timezone.timedelta(days=1),
            event_ends_at=timezone.now() + timezone.timedelta(days=1, hours=2),
            event_location="Alexandrovsky Garden",
        )
        PostImage.objects.create(post=post, image_url="https://example.com/event.jpg", position=0)

        response = self.client.get(reverse("post-detail", kwargs={"post_id": post.id}))

        self.assertEqual(response.status_code, 200)
        self.assertIn("images", response.json())
        self.assertIn("comments", response.json())
        self.assertIn("slug", response.json())
        self.assertIn("created_at", response.json())
        self.assertIn("updated_at", response.json())
        self.assertIn("view_count", response.json())
        self.assertEqual(response.json()["event_location"], "Alexandrovsky Garden")

    def test_post_detail_by_slug_returns_transliterated_public_path_payload(self):
        author = User.objects.get(email="anna@econizhny.local")
        post = Post.objects.create(
            author=author,
            title="Верблюд",
            body="Проверяем lookup по slug",
            kind=Post.Kind.NEWS,
            is_published=True,
        )

        response = self.client.get(
            reverse(
                "post-detail-by-slug",
                kwargs={"username": author.username, "post_slug": "verblyud"},
            )
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["id"], post.id)
        self.assertEqual(response.json()["slug"], "verblyud")
        self.assertEqual(response.json()["author"]["username"], author.username)

    def test_post_search_filters_results(self):
        author = User.objects.get(email="anna@econizhny.local")
        Post.objects.create(
            author=author,
            title="Unique cleanup action",
            body="River cleanup event this weekend",
            kind=Post.Kind.EVENT,
            is_published=True,
            event_starts_at=timezone.now() + timezone.timedelta(days=3),
            event_location="Volga embankment",
        )

        response = self.client.get(reverse("post-list"), {"search": "cleanup embankment"})

        self.assertEqual(response.status_code, 200)
        self.assertTrue(any("cleanup" in item["title"].lower() for item in response.json()["results"]))

    def test_post_list_preview_truncates_without_cutting_words(self):
        author = User.objects.get(email="anna@econizhny.local")
        long_body = " ".join([f"слово{index}" for index in range(80)])
        Post.objects.create(
            author=author,
            title="Long preview",
            body=long_body,
            kind=Post.Kind.NEWS,
            is_published=True,
        )

        response = self.client.get(reverse("post-list"), {"search": "Long preview"})

        self.assertEqual(response.status_code, 200)
        preview_text = response.json()["results"][0]["preview_text"]
        self.assertLessEqual(len(preview_text), 241)
        self.assertTrue(preview_text.endswith("…"))
        self.assertNotIn(" ", preview_text[-2:])

    def test_post_body_is_limited_to_5000_characters(self):
        access_token = self.login()

        response = self.client.post(
            reverse("post-list"),
            {
                "title": "Too long",
                "body": "x" * 5001,
                "kind": "news",
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("body", response.json())

    def test_authenticated_user_can_like_comment_and_favorite(self):
        access_token = self.login()
        post = Post.objects.filter(is_published=True).first()

        like_response = self.client.post(
            reverse("post-like", kwargs={"post_id": post.id}),
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )
        self.assertEqual(like_response.status_code, 200)
        self.assertTrue(like_response.json()["is_liked"])

        comment_response = self.client.post(
            reverse("post-comments", kwargs={"post_id": post.id}),
            {"body": "Новый тестовый комментарий"},
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )
        self.assertEqual(comment_response.status_code, 201)
        self.assertEqual(comment_response.json()["body"], "Новый тестовый комментарий")

        favorite_response = self.client.post(
            reverse("post-favorite", kwargs={"post_id": post.id}),
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )
        self.assertEqual(favorite_response.status_code, 200)
        self.assertTrue(favorite_response.json()["is_favorited"])

    def test_authenticated_user_can_create_and_edit_event_post(self):
        access_token = self.login()
        event_start = timezone.now() + timezone.timedelta(days=2)

        create_response = self.client.post(
            reverse("post-list"),
            {
                "title": "Тестовый пост",
                "body": "Создан из теста",
                "kind": "event",
                "image_urls": ["https://picsum.photos/seed/test-post/1200/800"],
                "event_starts_at": event_start.isoformat(),
                "event_ends_at": (event_start + timezone.timedelta(hours=2)).isoformat(),
                "event_location": "Нижне-Волжская набережная",
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )
        self.assertEqual(create_response.status_code, 201)
        post_id = create_response.json()["id"]
        self.assertEqual(create_response.json()["slug"], "testovyi-post")
        self.assertEqual(create_response.json()["event_date"], timezone.localdate(event_start).isoformat())
        self.assertEqual(create_response.json()["event_location"], "Нижне-Волжская набережная")

        patch_response = self.client.patch(
            reverse("post-detail", kwargs={"post_id": post_id}),
            {
                "title": "Обновленный тестовый пост",
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )
        self.assertEqual(patch_response.status_code, 200)
        self.assertEqual(patch_response.json()["title"], "Обновленный тестовый пост")
        self.assertEqual(patch_response.json()["slug"], "obnovlennyi-testovyi-post")

    def test_moderator_can_delete_foreign_comment(self):
        moderator_token = self.login(identifier="ivan@econizhny.local")
        author = User.objects.get(email="anna@econizhny.local")
        post = Post.objects.filter(author=author, is_published=True).first()
        comment = PostComment.objects.create(post=post, author=author, body="Needs moderation")

        response = self.client.delete(
            reverse(
                "post-comment-detail",
                kwargs={"post_id": post.id, "comment_id": comment.id},
            ),
            HTTP_AUTHORIZATION=f"Bearer {moderator_token}",
        )

        self.assertEqual(response.status_code, 204)
        self.assertFalse(PostComment.objects.filter(id=comment.id).exists())

    def test_public_cannot_read_comments_of_unpublished_post(self):
        author = User.objects.get(email="anna@econizhny.local")
        draft = Post.objects.create(
            author=author,
            title="Draft post",
            body="Not visible yet",
            kind=Post.Kind.NEWS,
            is_published=False,
        )
        PostComment.objects.create(post=draft, author=author, body="Hidden comment")

        response = self.client.get(reverse("post-comments", kwargs={"post_id": draft.id}))

        self.assertEqual(response.status_code, 404)

    def test_deleted_post_disappears_from_author_feed(self):
        admin_token = self.login(identifier="admin@econizhny.local")
        author = User.objects.get(email="anna@econizhny.local")
        post = Post.objects.create(
            author=author,
            title="Delete me",
            body="This post should disappear after deletion",
            kind=Post.Kind.NEWS,
            is_published=True,
        )

        delete_response = self.client.delete(
            reverse("post-detail", kwargs={"post_id": post.id}),
            HTTP_AUTHORIZATION=f"Bearer {admin_token}",
        )
        self.assertEqual(delete_response.status_code, 204)

        profile_feed_response = self.client.get(
            reverse("post-list"),
            {"author_id": author.id, "search": "Delete me"},
        )
        self.assertEqual(profile_feed_response.status_code, 200)
        self.assertEqual(profile_feed_response.json()["count"], 0)

    def test_post_filters_support_kind_images_popular_ordering_and_favorites(self):
        author = User.objects.get(email="anna@econizhny.local")
        viewer = User.objects.get(email="ivan@econizhny.local")
        other_user = User.objects.get(email="admin@econizhny.local")
        popular = Post.objects.create(
            author=author,
            title="Popular event",
            body="Top ranked event",
            kind=Post.Kind.EVENT,
            is_published=True,
            event_starts_at=timezone.now() + timezone.timedelta(days=1),
            event_location="Park",
        )
        plain = Post.objects.create(
            author=author,
            title="Plain event",
            body="No image here",
            kind=Post.Kind.EVENT,
            is_published=True,
            event_starts_at=timezone.now() + timezone.timedelta(days=2),
            event_location="Square",
        )
        PostImage.objects.create(post=popular, image_url="https://example.com/popular.jpg", position=0)
        PostLike.objects.create(post=popular, user=viewer)
        PostFavorite.objects.create(post=popular, user=viewer)
        PostFavorite.objects.create(post=popular, user=other_user)

        access_token = self.login(identifier="ivan@econizhny.local")
        response = self.client.get(
            reverse("post-list"),
            {
                "kind": "event",
                "has_images": "true",
                "ordering": "popular",
                "event_scope": "upcoming",
                "favorites_only": "true",
            },
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["results"][0]["id"], popular.id)
        self.assertNotIn(plain.id, [item["id"] for item in response.json()["results"]])

    def test_recommended_ordering_prioritizes_user_affinity(self):
        author = User.objects.get(email="anna@econizhny.local")
        viewer = User.objects.get(email="ivan@econizhny.local")
        other_author = User.objects.get(email="admin@econizhny.local")

        history_post = Post.objects.create(
            author=author,
            title="Affinity history",
            body="Viewer already engaged with this author and type",
            kind=Post.Kind.STORY,
            is_published=True,
            published_at=timezone.now() - timezone.timedelta(days=20),
        )
        tailored_post = Post.objects.create(
            author=author,
            title="recbattle tailored",
            body="Fresh recbattle post from the author the viewer already likes",
            kind=Post.Kind.STORY,
            is_published=True,
            published_at=timezone.now() - timezone.timedelta(hours=5),
        )
        generic_popular_post = Post.objects.create(
            author=other_author,
            title="recbattle generic",
            body="Globally strong recbattle post, but less relevant personally",
            kind=Post.Kind.NEWS,
            is_published=True,
            published_at=timezone.now() - timezone.timedelta(hours=6),
        )

        PostLike.objects.create(post=history_post, user=viewer)
        PostFavorite.objects.create(post=history_post, user=viewer)
        PostComment.objects.create(post=history_post, author=viewer, body="Following this topic")
        PostView.objects.create(post=history_post, user=viewer)

        PostLike.objects.create(post=generic_popular_post, user=author)
        PostLike.objects.create(post=generic_popular_post, user=viewer)
        PostFavorite.objects.create(post=generic_popular_post, user=author)
        PostComment.objects.create(post=generic_popular_post, author=other_author, body="Looks active")

        access_token = self.login(identifier="ivan@econizhny.local")
        response = self.client.get(
            reverse("post-list"),
            {"ordering": "recommended", "search": "recbattle"},
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(response.status_code, 200)
        result_ids = [item["id"] for item in response.json()["results"]]
        self.assertIn(tailored_post.id, result_ids)
        self.assertIn(generic_popular_post.id, result_ids)
        self.assertLess(result_ids.index(tailored_post.id), result_ids.index(generic_popular_post.id))

    def test_event_post_requires_date_when_no_start_time(self):
        access_token = self.login()

        response = self.client.post(
            reverse("post-list"),
            {
                "title": "Event without date",
                "body": "This should be rejected",
                "kind": "event",
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("event_date", response.json())

    def test_event_calendar_returns_events_for_requested_month(self):
        author = User.objects.get(email="anna@econizhny.local")
        month_date = timezone.localdate() + timezone.timedelta(days=15)
        outside_month_date = month_date + timezone.timedelta(days=35)
        month_event = Post.objects.create(
            author=author,
            title="River cleanup",
            body="Meet at the lower embankment",
            kind=Post.Kind.EVENT,
            is_published=True,
            event_date=month_date,
            event_starts_at=timezone.now() + timezone.timedelta(days=15, hours=2),
        )
        outside_month_event = Post.objects.create(
            author=author,
            title="May lecture",
            body="Another month",
            kind=Post.Kind.EVENT,
            is_published=True,
            event_date=outside_month_date,
            event_starts_at=timezone.now() + timezone.timedelta(days=50),
        )

        response = self.client.get(
            reverse("post-calendar"),
            {"year": month_date.year, "month": month_date.month},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["year"], month_date.year)
        self.assertEqual(response.json()["month"], month_date.month)
        result_ids = [item["id"] for item in response.json()["events"]]
        self.assertIn(month_event.id, result_ids)
        self.assertNotIn(outside_month_event.id, result_ids)

    def test_author_can_cancel_and_restore_event(self):
        access_token = self.login()
        author = User.objects.get(email="anna@econizhny.local")
        post = Post.objects.create(
            author=author,
            title="Cleanup day",
            body="Original plan",
            kind=Post.Kind.EVENT,
            is_published=True,
            event_date=timezone.localdate() + timezone.timedelta(days=5),
        )

        cancel_response = self.client.post(
            reverse("post-cancel", kwargs={"post_id": post.id}),
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )
        self.assertEqual(cancel_response.status_code, 200)
        self.assertTrue(cancel_response.json()["is_event_cancelled"])
        self.assertIsNotNone(cancel_response.json()["event_cancelled_at"])

        restore_response = self.client.delete(
            reverse("post-cancel", kwargs={"post_id": post.id}),
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )
        self.assertEqual(restore_response.status_code, 200)
        self.assertFalse(restore_response.json()["is_event_cancelled"])
        self.assertIsNone(restore_response.json()["event_cancelled_at"])

    def test_moderator_can_cancel_foreign_event(self):
        moderator_token = self.login(identifier="ivan@econizhny.local")
        author = User.objects.get(email="anna@econizhny.local")
        post = Post.objects.create(
            author=author,
            title="Shared event",
            body="Moderator can step in",
            kind=Post.Kind.EVENT,
            is_published=True,
            event_date=timezone.localdate() + timezone.timedelta(days=7),
        )

        response = self.client.post(
            reverse("post-cancel", kwargs={"post_id": post.id}),
            HTTP_AUTHORIZATION=f"Bearer {moderator_token}",
        )

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["is_event_cancelled"])

    def test_regular_user_cannot_cancel_foreign_event(self):
        outsider = User.objects.create_user(
            username="reader",
            email="reader@example.com",
            password="demo12345",
        )
        author = User.objects.get(email="anna@econizhny.local")
        post = Post.objects.create(
            author=author,
            title="Protected event",
            body="Only owner or staff can cancel this",
            kind=Post.Kind.EVENT,
            is_published=True,
            event_date=timezone.localdate() + timezone.timedelta(days=9),
        )
        access_token = self.login(identifier=outsider.email)

        response = self.client.post(
            reverse("post-cancel", kwargs={"post_id": post.id}),
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

        self.assertEqual(response.status_code, 403)

    def test_author_can_read_own_unpublished_post_and_public_cannot(self):
        author = User.objects.get(email="anna@econizhny.local")
        draft = Post.objects.create(
            author=author,
            title="Личный черновик",
            body="Виден только автору",
            kind=Post.Kind.NEWS,
            is_published=False,
        )

        public_response = self.client.get(reverse("post-detail", kwargs={"post_id": draft.id}))
        self.assertEqual(public_response.status_code, 404)

        public_slug_response = self.client.get(
            reverse(
                "post-detail-by-slug",
                kwargs={"username": author.username, "post_slug": draft.slug},
            )
        )
        self.assertEqual(public_slug_response.status_code, 404)

        public_feed_response = self.client.get(
            reverse("post-list"),
            {"author_id": author.id, "search": "Личный черновик"},
        )
        self.assertEqual(public_feed_response.status_code, 200)
        self.assertEqual(public_feed_response.json()["count"], 0)

        access_token = self.login()

        author_response = self.client.get(
            reverse("post-detail", kwargs={"post_id": draft.id}),
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )
        self.assertEqual(author_response.status_code, 200)
        self.assertEqual(author_response.json()["id"], draft.id)
        self.assertFalse(author_response.json()["is_published"])

        author_slug_response = self.client.get(
            reverse(
                "post-detail-by-slug",
                kwargs={"username": author.username, "post_slug": draft.slug},
            ),
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )
        self.assertEqual(author_slug_response.status_code, 200)
        self.assertEqual(author_slug_response.json()["id"], draft.id)

        feed_response = self.client.get(
            reverse("post-list"),
            {"author_id": author.id, "search": "Личный черновик"},
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )
        self.assertEqual(feed_response.status_code, 200)
        self.assertEqual(feed_response.json()["count"], 1)
        self.assertFalse(feed_response.json()["results"][0]["is_published"])
