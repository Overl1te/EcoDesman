from django.test import TestCase
from django.urls import reverse

from apps.map_points.models import (
    MapPoint,
    MapPointReview,
    UserMapMarker,
    UserMapMarkerComment,
)
from apps.notifications.models import Notification
from apps.posts.models import Post, PostComment
from apps.support.models import ContentReport, SupportThread
from apps.users.models import User


class SupportApiTests(TestCase):
    def login(self, identifier: str, password: str = "demo12345") -> str:
        from apps.users.tests.helpers import access_token_for

        return access_token_for(identifier)

    def create_support_user(self) -> User:
        return User.objects.create_user(
            username="support-agent",
            email="support@econizhny.local",
            password="demo12345",
            display_name="Support Agent",
            role=User.Role.SUPPORT,
        )

    def create_post_target(self) -> Post:
        author = User.objects.get(email="admin@econizhny.local")
        return Post.objects.create(
            author=author,
            title="Пост для проверки жалобы",
            body="Контент для жалобы техподдержке",
            kind=Post.Kind.NEWS,
            is_published=True,
        )

    def test_support_role_can_access_support_but_not_admin(self):
        support_user = self.create_support_user()
        access_token = self.login(support_user.email)

        me_response = self.client.get(
            reverse("auth-me"),
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )
        self.assertEqual(me_response.status_code, 200)
        self.assertTrue(me_response.json()["can_access_support"])
        self.assertFalse(me_response.json()["can_access_admin"])

        team_threads_response = self.client.get(
            reverse("support-team-thread-list"),
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )
        self.assertEqual(team_threads_response.status_code, 200)

        admin_response = self.client.get(
            reverse("admin-overview"),
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )
        self.assertEqual(admin_response.status_code, 403)

    def test_legal_document_download_is_public_and_returns_pdf(self):
        response = self.client.get(
            reverse(
                "support-legal-document-download",
                kwargs={"slug": "terms"},
            )
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Content-Type"], "application/pdf")
        self.assertIn(
            'attachment; filename="eco-desman-user-agreement.pdf"',
            response["Content-Disposition"],
        )
        body = b"".join(response.streaming_content) if response.streaming else response.content
        self.assertTrue(body.startswith(b"%PDF"))

    def test_help_center_endpoint_returns_documents_and_pdf_urls(self):
        response = self.client.get(reverse("support-help-center"))
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertIn("overview", payload)
        self.assertEqual(payload["overview"]["title"], "Справка")
        self.assertIn("document_groups", payload)
        self.assertIn("documents", payload)
        self.assertGreaterEqual(len(payload["documents"]), 5)
        first_document = payload["documents"][0]
        self.assertIn("approval", first_document)
        self.assertIn("sections", first_document)
        self.assertEqual(first_document["sections"], [])
        self.assertIn("detail_url", first_document)
        self.assertTrue(
            first_document["pdf_download_url"].endswith(
                "/support/legal-documents/personal-data-consent/download"
            )
        )

    def test_help_document_endpoint_returns_single_full_document(self):
        response = self.client.get(
            reverse("support-help-document", kwargs={"slug": "distribution-consent"})
        )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["slug"], "distribution-consent")
        self.assertEqual(payload["status"], "Актуальная редакция")
        self.assertGreaterEqual(len(payload["quick_facts"]), 5)
        self.assertGreaterEqual(len(payload["table_of_contents"]), 7)
        self.assertGreaterEqual(len(payload["sections"]), 7)
        self.assertIn("operator_details", payload)

    def test_user_can_create_thread_and_support_can_reply(self):
        support_user = self.create_support_user()
        user_token = self.login("anna@econizhny.local")
        support_token = self.login(support_user.email)

        create_response = self.client.post(
            reverse("support-thread-list"),
            {
                "subject": "Не могу открыть карту",
                "body": "На мобильном карта зависает после входа в профиль",
                "category": "map",
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {user_token}",
        )
        self.assertEqual(create_response.status_code, 201)
        thread_id = create_response.json()["id"]
        self.assertEqual(create_response.json()["status"], "waiting_support")
        self.assertGreaterEqual(len(create_response.json()["messages"]), 1)

        team_list_response = self.client.get(
            reverse("support-team-thread-list"),
            HTTP_AUTHORIZATION=f"Bearer {support_token}",
        )
        self.assertEqual(team_list_response.status_code, 200)
        self.assertEqual(team_list_response.json()[0]["id"], thread_id)
        self.assertEqual(team_list_response.json()[0]["unread_count"], 1)

        team_detail_response = self.client.get(
            reverse("support-thread-detail", kwargs={"thread_id": thread_id}),
            HTTP_AUTHORIZATION=f"Bearer {support_token}",
        )
        self.assertEqual(team_detail_response.status_code, 200)
        self.assertEqual(team_detail_response.json()["unread_count"], 0)

        reply_response = self.client.post(
            reverse("support-thread-message-list", kwargs={"thread_id": thread_id}),
            {"body": "Проблему передали в работу, пришлите скрин ошибки."},
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {support_token}",
        )
        self.assertEqual(reply_response.status_code, 201)
        self.assertEqual(reply_response.json()["sender_type"], "support")

        user_detail_response = self.client.get(
            reverse("support-thread-detail", kwargs={"thread_id": thread_id}),
            HTTP_AUTHORIZATION=f"Bearer {user_token}",
        )
        self.assertEqual(user_detail_response.status_code, 200)
        self.assertEqual(user_detail_response.json()["status"], "waiting_user")
        self.assertGreaterEqual(len(user_detail_response.json()["messages"]), 2)
        self.assertEqual(user_detail_response.json()["assigned_to"]["id"], support_user.id)

    def test_bot_replies_to_standard_question_in_user_thread(self):
        user_token = self.login("anna@econizhny.local")

        create_response = self.client.post(
            reverse("support-thread-list"),
            {
                "subject": "Не приходят уведомления",
                "body": "Не приходят уведомления о поддержке и жалобах",
                "category": "account",
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {user_token}",
        )

        self.assertEqual(create_response.status_code, 201)
        messages = create_response.json()["messages"]
        self.assertGreaterEqual(len(messages), 2)
        self.assertEqual(messages[-1]["sender_type"], "bot")
        self.assertEqual(messages[-1]["sender_name"], "FAQ-бот")

    def test_closed_thread_is_archived_and_rejects_new_messages(self):
        support_user = self.create_support_user()
        user_token = self.login("anna@econizhny.local")
        support_token = self.login(support_user.email)

        create_response = self.client.post(
            reverse("support-thread-list"),
            {
                "subject": "Нужна помощь с профилем",
                "body": "Не могу изменить описание профиля",
                "category": "account",
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {user_token}",
        )
        self.assertEqual(create_response.status_code, 201)
        thread_id = create_response.json()["id"]

        close_response = self.client.patch(
            reverse("support-team-thread-detail", kwargs={"thread_id": thread_id}),
            {"status": "closed"},
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {support_token}",
        )
        self.assertEqual(close_response.status_code, 200)
        self.assertEqual(close_response.json()["status"], "closed")
        self.assertEqual(close_response.json()["messages"][-1]["sender_type"], "system")

        reply_response = self.client.post(
            reverse("support-thread-message-list", kwargs={"thread_id": thread_id}),
            {"body": "Пишу после закрытия"},
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {user_token}",
        )
        self.assertEqual(reply_response.status_code, 400)

        thread = SupportThread.objects.get(id=thread_id)
        self.assertEqual(thread.status, SupportThread.Status.CLOSED)

    def test_post_report_creates_linked_thread_and_notification(self):
        self.create_support_user()
        reporter = User.objects.get(email="anna@econizhny.local")
        post = self.create_post_target()
        reporter_token = self.login(reporter.email)
        support_token = self.login("support@econizhny.local")

        response = self.client.post(
            reverse("post-report", kwargs={"post_id": post.id}),
            {
                "reason": "spam",
                "details": "Подозрительная публикация с рекламой",
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {reporter_token}",
        )

        self.assertEqual(response.status_code, 201)
        payload = response.json()
        self.assertEqual(payload["target_type"], "post")
        self.assertEqual(payload["post_id"], post.id)
        self.assertIsNotNone(payload["thread_id"])

        report = ContentReport.objects.get(id=payload["id"])
        self.assertEqual(report.support_thread.category, SupportThread.Category.REPORT)
        self.assertEqual(report.support_thread.created_by, reporter)

        notifications_response = self.client.get(
            reverse("notification-list"),
            HTTP_AUTHORIZATION=f"Bearer {support_token}",
        )
        self.assertEqual(notifications_response.status_code, 200)
        support_notification = notifications_response.json()["results"][0]
        self.assertEqual(support_notification["kind"], Notification.Kind.REPORT_CREATED)
        self.assertEqual(support_notification["support_thread_id"], payload["thread_id"])
        self.assertEqual(support_notification["report_id"], payload["id"])

    def test_comment_and_map_review_reports_create_records(self):
        self.create_support_user()
        reporter_token = self.login("anna@econizhny.local")
        post = self.create_post_target()
        comment = PostComment.objects.create(
            post=post,
            author=User.objects.get(email="admin@econizhny.local"),
            body="Сомнительный комментарий",
        )
        point = MapPoint.objects.get(slug="ecopunkt")
        review = MapPointReview.objects.create(
            point=point,
            author=User.objects.get(email="admin@econizhny.local"),
            author_name="Admin",
            rating=1,
            body="Очень странный отзыв",
        )

        comment_response = self.client.post(
            reverse(
                "post-comment-report",
                kwargs={"post_id": post.id, "comment_id": comment.id},
            ),
            {
                "reason": "abuse",
                "details": "Оскорбляет других пользователей",
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {reporter_token}",
        )
        self.assertEqual(comment_response.status_code, 201)
        self.assertEqual(comment_response.json()["comment_id"], comment.id)

        review_response = self.client.post(
            reverse(
                "map-point-review-report",
                kwargs={"point_id": point.id, "review_id": review.id},
            ),
            {
                "reason": "misinformation",
                "details": "В отзыве неверные данные о точке",
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {reporter_token}",
        )
        self.assertEqual(review_response.status_code, 201)
        self.assertEqual(review_response.json()["review_id"], review.id)

        self.assertTrue(
            ContentReport.objects.filter(
                target_type=ContentReport.TargetType.COMMENT,
                comment=comment,
            ).exists()
        )
        self.assertTrue(
            ContentReport.objects.filter(
                target_type=ContentReport.TargetType.MAP_REVIEW,
                review=review,
            ).exists()
        )

    def test_user_marker_reports_create_records(self):
        self.create_support_user()
        reporter_token = self.login("anna@econizhny.local")
        owner = User.objects.get(email="admin@econizhny.local")
        marker = UserMapMarker.objects.create(
            author=owner,
            title="Метка для жалобы",
            description="Пользовательская точка",
            latitude=56.322,
            longitude=44.022,
        )
        comment = UserMapMarkerComment.objects.create(
            marker=marker,
            author=owner,
            author_name="Admin",
            body="Комментарий к пользовательской метке",
        )

        marker_response = self.client.post(
            reverse("user-map-marker-report", kwargs={"marker_id": marker.id}),
            {
                "reason": "spam",
                "details": "Метка похожа на рекламу",
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {reporter_token}",
        )
        self.assertEqual(marker_response.status_code, 201)
        self.assertEqual(marker_response.json()["user_marker_id"], marker.id)

        comment_response = self.client.post(
            reverse(
                "user-map-marker-comment-report",
                kwargs={"marker_id": marker.id, "comment_id": comment.id},
            ),
            {
                "reason": "abuse",
                "details": "Некорректный комментарий",
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {reporter_token}",
        )
        self.assertEqual(comment_response.status_code, 201)
        self.assertEqual(
            comment_response.json()["user_marker_comment_id"],
            comment.id,
        )

    def test_support_team_can_resolve_report_and_remove_target(self):
        support_user = self.create_support_user()
        reporter = User.objects.get(email="anna@econizhny.local")
        post = self.create_post_target()
        reporter_token = self.login(reporter.email)
        support_token = self.login(support_user.email)

        create_response = self.client.post(
            reverse("post-report", kwargs={"post_id": post.id}),
            {
                "reason": "dangerous",
                "details": "Контент нарушает правила",
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {reporter_token}",
        )
        self.assertEqual(create_response.status_code, 201)
        report_id = create_response.json()["id"]

        update_response = self.client.patch(
            reverse("support-team-report-detail", kwargs={"report_id": report_id}),
            {
                "status": "resolved",
                "resolution_note": "Пост удалён по итогам проверки.",
                "remove_target": True,
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {support_token}",
        )
        self.assertEqual(update_response.status_code, 200)
        self.assertEqual(update_response.json()["status"], "resolved")
        self.assertEqual(update_response.json()["reviewed_by"]["id"], support_user.id)

        report = ContentReport.objects.select_related("support_thread").get(id=report_id)
        self.assertEqual(report.status, ContentReport.Status.RESOLVED)
        self.assertEqual(report.support_thread.status, SupportThread.Status.CLOSED)
        self.assertFalse(Post.objects.filter(id=post.id).exists())
