from datetime import timedelta
from unittest.mock import patch

from django.test import TestCase, override_settings
from django.urls import reverse
from django.utils import timezone

from apps.users.greensms import GreenSMSError, GreenSMSSendResult
from apps.users.models import PhoneVerificationChallenge, User
from apps.users.phone_verification import _hash_code
from apps.users.turnstile import TurnstileError


def _send_result(channel="telegram", code="1234") -> GreenSMSSendResult:
    return GreenSMSSendResult(channel=channel, request_id=f"req-{channel}", code=code)


class AuthProtectionTests(TestCase):
    def test_protection_is_disabled_by_default(self):
        response = self.client.get(reverse("auth-protection"))

        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.json()["turnstile"]["enabled"])
        self.assertEqual(response.json()["turnstile"]["site_key"], "")
        self.assertFalse(response.json()["phone_verification"]["enabled"])

    @override_settings(
        CLOUDFLARE_TURNSTILE_SITE_KEY="site-key",
        CLOUDFLARE_TURNSTILE_SECRET_KEY="secret-key",
        GREENSMS_TOKEN="token",
    )
    def test_protection_exposes_enabled_providers(self):
        response = self.client.get(reverse("auth-protection"))

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["turnstile"]["enabled"])
        self.assertEqual(response.json()["turnstile"]["site_key"], "site-key")
        self.assertTrue(response.json()["phone_verification"]["enabled"])
        self.assertEqual(response.json()["phone_verification"]["channels"], ["telegram", "call", "receive"])


class TurnstileAuthTests(TestCase):
    @override_settings(
        CLOUDFLARE_TURNSTILE_SITE_KEY="site-key",
        CLOUDFLARE_TURNSTILE_SECRET_KEY="secret-key",
    )
    @patch("apps.users.api.views.verify_turnstile_token", side_effect=TurnstileError("Подтвердите, что вы не робот"))
    def test_login_requires_turnstile_when_configured(self, _verify_mock):
        response = self.client.post(
            reverse("auth-login"),
            {"identifier": "anna@econizhny.local", "password": "demo12345"},
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("робот", response.json()["detail"])

    @override_settings(
        CLOUDFLARE_TURNSTILE_SITE_KEY="site-key",
        CLOUDFLARE_TURNSTILE_SECRET_KEY="secret-key",
    )
    @patch("apps.users.api.views.verify_turnstile_token")
    def test_login_succeeds_with_valid_turnstile(self, verify_mock):
        response = self.client.post(
            reverse("auth-login"),
            {
                "identifier": "anna@econizhny.local",
                "password": "demo12345",
                "turnstile_token": "ok-token",
            },
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 200)
        verify_mock.assert_called_once()
        self.assertEqual(verify_mock.call_args.args[0], "ok-token")


class PhoneVerificationApiTests(TestCase):
    @override_settings(GREENSMS_TOKEN="token")
    @patch("apps.users.phone_verification.send_verification_code", return_value=_send_result())
    def test_send_uses_telegram_first(self, send_mock):
        response = self.client.post(
            reverse("auth-phone-send"),
            {"phone": "+7 (999) 111-22-33", "purpose": "register"},
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 201)
        payload = response.json()
        self.assertEqual(payload["channel"], "telegram")
        self.assertIn("Telegram", payload["detail"])
        self.assertTrue(payload["can_try_next_channel"])
        send_mock.assert_called_once()
        self.assertEqual(send_mock.call_args.kwargs["start_channel"], "telegram")

    @override_settings(GREENSMS_TOKEN="token")
    @patch(
        "apps.users.phone_verification.send_verification_code",
        side_effect=[
            _send_result("telegram", "1111"),
            _send_result("call", "2222"),
        ],
    )
    def test_resend_falls_back_to_flashcall_then_register_consumes_challenge(self, send_mock):
        send_response = self.client.post(
            reverse("auth-phone-send"),
            {"phone": "+79991112233", "purpose": "register"},
            content_type="application/json",
        )
        self.assertEqual(send_response.status_code, 201)
        first_id = send_response.json()["challenge_id"]

        resend_response = self.client.post(
            reverse("auth-phone-resend"),
            {"challenge_id": first_id},
            content_type="application/json",
        )
        self.assertEqual(resend_response.status_code, 200)
        self.assertEqual(resend_response.json()["channel"], "call")
        challenge_id = resend_response.json()["challenge_id"]

        verify_response = self.client.post(
            reverse("auth-phone-verify"),
            {"challenge_id": challenge_id, "code": "2222"},
            content_type="application/json",
        )
        self.assertEqual(verify_response.status_code, 200)
        self.assertTrue(verify_response.json()["verified"])

        register_response = self.client.post(
            reverse("auth-register"),
            {
                "username": "verifiedphone",
                "email": "verifiedphone@econizhny.local",
                "display_name": "Verified",
                "phone": "+79991112233",
                "password": "StrongPass123",
                "password_confirmation": "StrongPass123",
                "accept_terms": True,
                "accept_privacy_policy": True,
                "accept_personal_data": True,
                "phone_challenge_id": challenge_id,
            },
            content_type="application/json",
        )
        self.assertEqual(register_response.status_code, 201)
        user = User.objects.get(username="verifiedphone")
        self.assertEqual(user.phone, "+79991112233")
        self.assertIsNotNone(user.phone_verified_at)
        challenge = PhoneVerificationChallenge.objects.get(id=challenge_id)
        self.assertIsNotNone(challenge.consumed_at)
        self.assertEqual(send_mock.call_args_list[1].kwargs["start_channel"], "call")

    @override_settings(GREENSMS_TOKEN="token")
    def test_register_requires_phone_challenge_when_greensms_enabled(self):
        response = self.client.post(
            reverse("auth-register"),
            {
                "username": "nochallenge",
                "email": "nochallenge@econizhny.local",
                "password": "StrongPass123",
                "password_confirmation": "StrongPass123",
                "accept_terms": True,
                "accept_privacy_policy": True,
                "accept_personal_data": True,
            },
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("phone", response.json())

    @override_settings(GREENSMS_TOKEN="token")
    @patch(
        "apps.users.phone_verification.send_verification_code",
        return_value=_send_result("call", "9876"),
    )
    def test_call_channel_accepts_last_four_digits(self, _send_mock):
        send_response = self.client.post(
            reverse("auth-phone-send"),
            {"phone": "9991112233", "purpose": "register"},
            content_type="application/json",
        )
        challenge_id = send_response.json()["challenge_id"]

        response = self.client.post(
            reverse("auth-phone-verify"),
            {"challenge_id": challenge_id, "code": "9876"},
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["channel"], "call")

    @override_settings(GREENSMS_TOKEN="token")
    def test_wrong_code_is_rejected(self):
        challenge = PhoneVerificationChallenge.objects.create(
            phone="+79990001122",
            purpose="register",
            channel="call",
            code_hash=_hash_code("+79990001122", "1234"),
            expires_at=timezone.now() + timedelta(minutes=10),
        )
        response = self.client.post(
            reverse("auth-phone-verify"),
            {"challenge_id": str(challenge.id), "code": "0000"},
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("Неверный код", response.json()["detail"])

    @override_settings(GREENSMS_TOKEN="token")
    @patch(
        "apps.users.phone_verification.send_verification_code",
        side_effect=GreenSMSError("Не удалось отправить код в Telegram"),
    )
    def test_send_returns_provider_error(self, _send_mock):
        response = self.client.post(
            reverse("auth-phone-send"),
            {"phone": "+79990001122", "purpose": "register"},
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 503)


class GreenSMSCascadeTests(TestCase):
    @override_settings(GREENSMS_TOKEN="token")
    @patch("apps.users.greensms.request_json")
    def test_falls_back_from_telegram_to_flashcall(self, request_json_mock):
        from apps.users.greensms import send_verification_code
        from apps.users.http_client import ExternalHttpError

        request_json_mock.side_effect = [
            ExternalHttpError("not in telegram", status_code=400),
            {"request_id": "call-1", "code": "4321"},
        ]

        result = send_verification_code("+79991112233")
        self.assertEqual(result.channel, "call")
        self.assertEqual(result.request_id, "call-1")
        self.assertEqual(result.code, "4321")
        self.assertEqual(request_json_mock.call_count, 2)
        self.assertIn("/telegram/send", request_json_mock.call_args_list[0].args[0])
        self.assertIn("/call/send", request_json_mock.call_args_list[1].args[0])

    @override_settings(GREENSMS_TOKEN="token")
    @patch("apps.users.greensms.request_json")
    def test_falls_back_to_receive_call_when_flashcall_fails(self, request_json_mock):
        from apps.users.greensms import send_verification_code
        from apps.users.http_client import ExternalHttpError

        request_json_mock.side_effect = [
            ExternalHttpError("no telegram", status_code=400),
            ExternalHttpError("flashcall failed", status_code=400),
            {"request_id": "recv-1", "number": "78005553535"},
        ]

        result = send_verification_code("+79991112233")
        self.assertEqual(result.channel, "receive")
        self.assertEqual(result.dial_number, "78005553535")
        self.assertIn("/call/receive", request_json_mock.call_args_list[2].args[0])

    @override_settings(GREENSMS_TOKEN="token")
    @patch(
        "apps.users.phone_verification.send_verification_code",
        return_value=GreenSMSSendResult(
            channel="receive",
            request_id="recv-1",
            dial_number="78005553535",
        ),
    )
    @patch("apps.users.phone_verification.is_receive_call_confirmed", return_value=True)
    def test_receive_call_is_confirmed_without_code(self, _status_mock, _send_mock):
        send_response = self.client.post(
            reverse("auth-phone-send"),
            {"phone": "+79991112233", "purpose": "register"},
            content_type="application/json",
        )
        self.assertEqual(send_response.status_code, 201)
        payload = send_response.json()
        self.assertEqual(payload["channel"], "receive")
        self.assertFalse(payload["needs_code"])
        self.assertIn("800", payload["receive_number"])

        verify_response = self.client.post(
            reverse("auth-phone-verify"),
            {"challenge_id": payload["challenge_id"]},
            content_type="application/json",
        )
        self.assertEqual(verify_response.status_code, 200)
        self.assertTrue(verify_response.json()["verified"])

