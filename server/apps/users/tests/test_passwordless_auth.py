from django.test import TestCase, override_settings
from django.urls import reverse

from apps.users.greensms import GreenSMSSendResult
from apps.users.models import User


def _send_result(channel="telegram", code="1234") -> GreenSMSSendResult:
    return GreenSMSSendResult(channel=channel, request_id=f"req-{channel}", code=code)


@override_settings(
    EMAIL_OTP_DEBUG=True,
    GREENSMS_DEBUG=True,
    GREENSMS_DEBUG_RETURN_CODE=True,
    PHONE_VERIFICATION_SEND_COOLDOWN_SECONDS=0,
    PHONE_VERIFICATION_MAX_SENDS_PER_HOUR=50,
    PHONE_VERIFICATION_MAX_SENDS_PER_IP_HOUR=50,
)
class PasswordlessAuthTests(TestCase):
    def test_unknown_email_creates_user_after_code(self):
        first = self.client.post(
            reverse("auth-login"),
            {"identifier": "fresh-user@example.com"},
            content_type="application/json",
        )
        self.assertEqual(first.status_code, 400)
        payload = first.json()
        self.assertEqual(payload["channel"], "email")
        self.assertFalse(User.objects.filter(email="fresh-user@example.com").exists())

        second = self.client.post(
            reverse("auth-login"),
            {
                "challenge_id": payload["challenge_id"],
                "code": payload["debug_code"],
            },
            content_type="application/json",
        )
        self.assertEqual(second.status_code, 200)
        user = User.objects.get(email="fresh-user@example.com")
        self.assertFalse(user.has_usable_password())
        self.assertTrue(user.username)

    def test_unknown_phone_creates_user_after_code(self):
        from unittest.mock import patch

        with patch(
            "apps.users.auth_challenge.send_verification_code",
            return_value=_send_result(),
        ):
            first = self.client.post(
                reverse("auth-login"),
                {"identifier": "+7 (999) 111-00-22"},
                content_type="application/json",
            )
        self.assertEqual(first.status_code, 400)
        payload = first.json()
        self.assertEqual(payload["channel"], "telegram")

        second = self.client.post(
            reverse("auth-login"),
            {
                "challenge_id": payload["challenge_id"],
                "code": "1234",
            },
            content_type="application/json",
        )
        self.assertEqual(second.status_code, 200)
        user = User.objects.get(phone="+79991110022")
        self.assertFalse(user.has_usable_password())
        self.assertIsNotNone(user.phone_verified_at)

    def test_username_sends_code_to_email(self):
        first = self.client.post(
            reverse("auth-login"),
            {"identifier": "anna"},
            content_type="application/json",
        )
        self.assertEqual(first.status_code, 400)
        payload = first.json()
        self.assertEqual(payload["channel"], "email")
        self.assertEqual(payload["email"], "anna@econizhny.local")

        second = self.client.post(
            reverse("auth-login"),
            {
                "challenge_id": payload["challenge_id"],
                "code": payload["debug_code"],
            },
            content_type="application/json",
        )
        self.assertEqual(second.status_code, 200)
        self.assertEqual(second.json()["user"]["username"], "anna")

    def test_can_switch_to_email_channel(self):
        from unittest.mock import patch

        with patch(
            "apps.users.auth_challenge.send_verification_code",
            return_value=_send_result(),
        ):
            first = self.client.post(
                reverse("auth-login"),
                {"identifier": "+79990000001"},
                content_type="application/json",
            )
        self.assertEqual(first.status_code, 400)
        challenge_id = first.json()["challenge_id"]

        switched = self.client.post(
            reverse("auth-challenge-send"),
            {
                "challenge_id": challenge_id,
                "channel": "email",
            },
            content_type="application/json",
        )
        self.assertEqual(switched.status_code, 201)
        self.assertEqual(switched.json()["channel"], "email")
        self.assertIn("email", switched.json()["available_channels"])

        second = self.client.post(
            reverse("auth-login"),
            {
                "challenge_id": switched.json()["challenge_id"],
                "code": switched.json()["debug_code"],
            },
            content_type="application/json",
        )
        self.assertEqual(second.status_code, 200)
        self.assertEqual(second.json()["user"]["username"], "anna")
