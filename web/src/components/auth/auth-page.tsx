"use client";

import { FormEvent, useEffect, useState } from "react";
import Link from "next/link";

import { useAuth } from "@/components/providers/auth-provider";
import { TurnstileWidget } from "@/components/auth/turnstile-widget";
import { Modal } from "@/components/ui/modal";
import {
  getAuthConfirmationChallenge,
  getAuthProtection,
  sendAuthChallenge,
  verifyAuthChallenge,
} from "@/lib/api";
import type { AuthChannel, AuthProtectionConfig, PhoneChallenge } from "@/lib/types";
import { formatLoginIdentifier, formatRuPhone, normalizeLoginIdentifier } from "@/lib/phone";
import { usePathname, useRouter } from "next/navigation";

const CHANNEL_LABELS: Record<AuthChannel, string> = {
  telegram: "Код в Telegram",
  call: "Код в номере",
  receive: "Обратный звонок",
  email: "Код на почту",
};

function channelNeedsPhone(channel: AuthChannel) {
  return channel === "telegram" || channel === "call" || channel === "receive";
}

function codeFieldLabel(channel: PhoneChallenge["channel"]) {
  if (channel === "call") {
    return "Последние 4 цифры входящего номера";
  }
  if (channel === "email") {
    return "Код из письма";
  }
  return "Код из Telegram";
}

export function AuthDialog() {
  const pathname = usePathname();
  const router = useRouter();
  const { authModal, closeAuthModal, isAuthenticated, login } = useAuth();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [identifier, setIdentifier] = useState("");
  const [extraPhone, setExtraPhone] = useState("");
  const [extraEmail, setExtraEmail] = useState("");
  const [turnstileToken, setTurnstileToken] = useState("");
  const [turnstileResetNonce, setTurnstileResetNonce] = useState(0);
  const [protection, setProtection] = useState<AuthProtectionConfig | null>(null);
  const [challenge, setChallenge] = useState<PhoneChallenge | null>(null);
  const [code, setCode] = useState("");

  const resetTurnstile = () => {
    setTurnstileToken("");
    setTurnstileResetNonce((value) => value + 1);
  };

  useEffect(() => {
    if (!authModal.isOpen) {
      return;
    }

    setError(null);
    setInfo(null);
    setTurnstileToken("");
    setTurnstileResetNonce((value) => value + 1);
    setChallenge(null);
    setCode("");
    setExtraPhone("");
    setExtraEmail("");
    setProtection(null);

    void getAuthProtection()
      .then(setProtection)
      .catch(() => setProtection(null));
  }, [authModal.isOpen]);

  useEffect(() => {
    if (!authModal.isOpen || !isAuthenticated) {
      return;
    }

    closeAuthModal();
    if (authModal.returnTo && authModal.returnTo !== pathname) {
      router.replace(authModal.returnTo);
    }
  }, [authModal.isOpen, authModal.returnTo, closeAuthModal, isAuthenticated, pathname, router]);

  useEffect(() => {
    if (!authModal.isOpen || !challenge || challenge.channel !== "receive" || challenge.verified) {
      return;
    }

    const poll = async () => {
      try {
        await login({
          challenge_id: challenge.challenge_id,
        });
      } catch {
        try {
          const nextChallenge = await verifyAuthChallenge({
            challenge_id: challenge.challenge_id,
          });
          if (nextChallenge.verified) {
            setChallenge(nextChallenge);
            setInfo("Обратный звонок подтверждён. Можно войти.");
            setError(null);
          }
        } catch {
          // Звонок ещё не поступил.
        }
      }
    };

    const timer = window.setInterval(() => {
      void poll();
    }, 5000);
    void poll();

    return () => window.clearInterval(timer);
  }, [authModal.isOpen, challenge, login]);

  const availableChannels = protection?.auth?.channels ?? [];
  const showExtraPhone = Boolean(challenge && !challenge.phone);
  const showExtraEmail = Boolean(challenge && !challenge.email);

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setLoading(true);
    setError(null);
    setInfo(null);

    try {
      if (challenge) {
        if (challenge.needs_code !== false && !code.trim()) {
          setError(
            challenge.channel === "call"
              ? "Введите последние 4 цифры входящего номера"
              : "Введите код подтверждения",
          );
          return;
        }

        await login({
          identifier: normalizeLoginIdentifier(identifier),
          challenge_id: challenge.challenge_id,
          code: code.trim() || undefined,
          turnstile_token: turnstileToken || undefined,
        });
        return;
      }

      try {
        await login({
          identifier: normalizeLoginIdentifier(identifier),
          turnstile_token: turnstileToken || undefined,
        });
      } catch (loginError) {
        const nextChallenge = getAuthConfirmationChallenge(loginError);
        if (nextChallenge) {
          setChallenge(nextChallenge);
          setCode("");
          setInfo(nextChallenge.detail);
          return;
        }
        throw loginError;
      }
    } catch (submitError) {
      resetTurnstile();
      setError(submitError instanceof Error ? submitError.message : "Не удалось войти");
    } finally {
      setLoading(false);
    }
  };

  const switchChannel = async (channel: AuthChannel) => {
    if (!challenge || channel === challenge.channel) {
      return;
    }
    if (channelNeedsPhone(channel) && !challenge.phone && !extraPhone.trim()) {
      setError("Укажите номер телефона для этого способа");
      return;
    }
    if (channel === "email" && !challenge.email && !extraEmail.trim()) {
      setError("Укажите почту для этого способа");
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const nextChallenge = await sendAuthChallenge({
        challenge_id: challenge.challenge_id,
        channel,
        phone: extraPhone.trim() || undefined,
        email: extraEmail.trim() || undefined,
        turnstile_token: turnstileToken || undefined,
      });
      setChallenge(nextChallenge);
      setCode("");
      setInfo(nextChallenge.detail);
    } catch (switchError) {
      resetTurnstile();
      setError(switchError instanceof Error ? switchError.message : "Не удалось сменить способ");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal
      open={authModal.isOpen}
      title="Вход"
      description="Укажите почту, телефон или логин — отправим код. Если аккаунта ещё нет, он появится после подтверждения."
      onClose={closeAuthModal}
    >
        <form className="auth-form" onSubmit={handleSubmit}>
          <div className="auth-form-stack">
            <label className="field">
              <span>Почта, телефон или логин</span>
              <input
                value={identifier}
                autoComplete="username"
                placeholder="Почта, логин или +7"
                onChange={(event) => {
                  setIdentifier(formatLoginIdentifier(event.target.value));
                  if (challenge) {
                    setChallenge(null);
                    setCode("");
                    resetTurnstile();
                  }
                }}
              />
            </label>
          </div>

          {challenge ? (
            <div className="auth-phone-challenge">
              <p className="auth-phone-challenge-detail">{challenge.detail}</p>
              {challenge.channel === "receive" ? (
                <div className="auth-receive-number" aria-live="polite">
                  {challenge.receive_number}
                </div>
              ) : (
                <label className="field">
                  <span>{codeFieldLabel(challenge.channel)}</span>
                  <input
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    maxLength={challenge.code_length}
                    value={code}
                    onChange={(event) => setCode(event.target.value.replace(/\D/g, ""))}
                  />
                </label>
              )}

              {showExtraPhone ? (
                <label className="field">
                  <span>Номер телефона</span>
                  <input
                    type="tel"
                    inputMode="tel"
                    autoComplete="tel"
                    placeholder="+7 (999) 000-00-00"
                    value={extraPhone}
                    onChange={(event) => setExtraPhone(formatRuPhone(event.target.value))}
                    onFocus={() => {
                      if (!extraPhone) {
                        setExtraPhone("+7 ");
                      }
                    }}
                  />
                </label>
              ) : null}

              {showExtraEmail ? (
                <label className="field">
                  <span>Электронная почта</span>
                  <input
                    type="email"
                    autoComplete="email"
                    value={extraEmail}
                    onChange={(event) => setExtraEmail(event.target.value)}
                  />
                </label>
              ) : null}

              {availableChannels.length > 1 ? (
                <div className="auth-channel-list" role="group" aria-label="Другой способ">
                  {availableChannels
                    .filter((channel) => channel !== challenge.channel)
                    .map((channel) => (
                      <button
                        key={channel}
                        type="button"
                        className="link-button"
                        disabled={loading}
                        onClick={() => void switchChannel(channel)}
                      >
                        {CHANNEL_LABELS[channel]}
                      </button>
                    ))}
                </div>
              ) : null}
            </div>
          ) : null}

          {protection?.turnstile.enabled && protection.turnstile.site_key && !challenge ? (
            <TurnstileWidget
              siteKey={protection.turnstile.site_key}
              resetNonce={turnstileResetNonce}
              onToken={setTurnstileToken}
            />
          ) : null}

          {error ? <div className="form-banner is-error">{error}</div> : null}
          {info ? <div className="form-banner is-info">{info}</div> : null}

          <div className="auth-submit-bar">
            <button type="submit" className="button button-primary button-block" disabled={loading}>
              {loading ? "Подождите..." : challenge ? "Подтвердить и войти" : "Получить код"}
            </button>
            <p className="auth-legal-note">
              Вход и создание аккаунта означают принятие{" "}
              <Link href="/help/terms" className="auth-legal-link" target="_blank">
                пользовательского соглашения
              </Link>{" "}
              и{" "}
              <Link href="/help/privacy-policy" className="auth-legal-link" target="_blank">
                политики конфиденциальности
              </Link>
              , а также{" "}
              <Link href="/help/personal-data-consent" className="auth-legal-link" target="_blank">
                согласие на обработку персональных данных
              </Link>
              .
            </p>
          </div>
        </form>
    </Modal>
  );
}
