"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { FormEvent, useEffect, useMemo, useState } from "react";
import { CheckCircle2, Circle, X } from "lucide-react";

import { useAuth } from "@/components/providers/auth-provider";
import { TurnstileWidget } from "@/components/auth/turnstile-widget";
import {
  getAuthProtection,
  getPhoneConfirmationChallenge,
  requestPasswordReset,
  resendPhoneChallenge,
  sendPhoneChallenge,
  verifyPhoneChallenge,
} from "@/lib/api";
import { APP_NAME } from "@/lib/config";
import type { AuthProtectionConfig, PhoneChallenge } from "@/lib/types";
import {
  formatLoginIdentifier,
  formatRuPhone,
  normalizeLoginIdentifier,
  toE164RuPhone,
} from "@/lib/phone";

type Mode = "login" | "register";

function passwordChecks(password: string) {
  return [
    { label: "Минимум 8 символов", passed: password.length >= 8 },
    { label: "Есть буквы", passed: /[A-Za-zА-Яа-я]/.test(password) },
    { label: "Есть цифра", passed: /\d/.test(password) },
  ];
}

function LegalLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <Link href={href} className="auth-legal-link" target="_blank" rel="noreferrer">
      {children}
    </Link>
  );
}

export function AuthDialog() {
  const pathname = usePathname();
  const router = useRouter();
  const { authModal, closeAuthModal, isAuthenticated, login, register } = useAuth();
  const [mode, setMode] = useState<Mode>("login");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  const [loginIdentifier, setLoginIdentifier] = useState("");
  const [loginPassword, setLoginPassword] = useState("");

  const [displayName, setDisplayName] = useState("");
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [registerPassword, setRegisterPassword] = useState("");
  const [registerPasswordConfirmation, setRegisterPasswordConfirmation] = useState("");
  const [acceptTerms, setAcceptTerms] = useState(false);
  const [acceptPrivacyPolicy, setAcceptPrivacyPolicy] = useState(false);
  const [acceptPersonalData, setAcceptPersonalData] = useState(false);
  const [acceptPublicPersonalData, setAcceptPublicPersonalData] = useState(false);
  const [turnstileToken, setTurnstileToken] = useState("");
  const [turnstileResetNonce, setTurnstileResetNonce] = useState(0);
  const [protection, setProtection] = useState<AuthProtectionConfig | null>(null);
  const [phoneChallenge, setPhoneChallenge] = useState<PhoneChallenge | null>(null);
  const [phoneCode, setPhoneCode] = useState("");

  const resetTurnstile = () => {
    setTurnstileToken("");
    setTurnstileResetNonce((value) => value + 1);
  };

  const registerChecks = useMemo(() => passwordChecks(registerPassword), [registerPassword]);

  useEffect(() => {
    if (!authModal.isOpen) {
      return;
    }

    setMode(authModal.mode);
    setError(null);
    setInfo(null);
    setTurnstileToken("");
    setTurnstileResetNonce((value) => value + 1);
    setPhoneChallenge(null);
    setPhoneCode("");
    setProtection(null);

    void getAuthProtection()
      .then(setProtection)
      .catch(() => setProtection(null));
  }, [authModal.isOpen, authModal.mode]);

  useEffect(() => {
    if (!authModal.isOpen) {
      return;
    }

    const previousOverflow = document.body.style.overflow;
    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        closeAuthModal();
      }
    };

    document.body.style.overflow = "hidden";
    window.addEventListener("keydown", handleEscape);

    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", handleEscape);
    };
  }, [authModal.isOpen, closeAuthModal]);

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
    if (!authModal.isOpen || !phoneChallenge || phoneChallenge.channel !== "receive" || phoneChallenge.verified) {
      return;
    }

    const poll = async () => {
      try {
        const nextChallenge = await verifyPhoneChallenge({
          challenge_id: phoneChallenge.challenge_id,
        });
        if (nextChallenge.verified) {
          setPhoneChallenge(nextChallenge);
          setInfo(
            nextChallenge.verified
              ? mode === "login"
                ? "Обратный звонок подтверждён. Можно войти."
                : "Обратный звонок подтверждён. Можно создать аккаунт."
              : nextChallenge.detail,
          );
          setError(null);
        }
      } catch {
        // Звонок ещё не поступил — продолжаем ждать.
      }
    };

    const timer = window.setInterval(() => {
      void poll();
    }, 5000);
    void poll();

    return () => window.clearInterval(timer);
  }, [authModal.isOpen, mode, phoneChallenge]);

  if (!authModal.isOpen) {
    return null;
  }

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setLoading(true);
    setError(null);
    setInfo(null);

    try {
      if (mode === "login") {
        if (phoneChallenge?.needs_code !== false && phoneChallenge && !phoneCode.trim()) {
          setError(
            phoneChallenge.channel === "call"
              ? "Введите последние 4 цифры входящего номера"
              : "Введите код подтверждения телефона",
          );
          return;
        }

        try {
          await login({
            identifier: normalizeLoginIdentifier(loginIdentifier),
            password: loginPassword,
            turnstile_token: turnstileToken || undefined,
            phone_challenge_id: phoneChallenge?.challenge_id,
            phone_code: phoneCode.trim() || undefined,
          });
        } catch (loginError) {
          const challenge = getPhoneConfirmationChallenge(loginError);
          if (challenge) {
            setPhoneChallenge(challenge);
            setPhoneCode("");
            setInfo(challenge.detail);
            return;
          }
          throw loginError;
        }
      } else {
        const normalizedPhone = toE164RuPhone(phone);
        const phoneVerificationEnabled = Boolean(protection?.phone_verification.enabled);

        if (phoneVerificationEnabled) {
          if (!normalizedPhone) {
            setError("Укажите телефон, чтобы получить код подтверждения");
            return;
          }

          if (!phoneChallenge) {
            const challenge = await sendPhoneChallenge({
              phone: normalizedPhone,
              purpose: "register",
              turnstile_token: turnstileToken || undefined,
            });
            setPhoneChallenge(challenge);
            setInfo(challenge.detail);
            return;
          }

          if (phoneChallenge.needs_code !== false && !phoneCode.trim()) {
            setError(
              phoneChallenge.channel === "call"
                ? "Введите последние 4 цифры входящего номера"
                : "Введите код подтверждения телефона",
            );
            return;
          }
        }

        await register({
          username,
          email,
          display_name: displayName,
          phone: normalizedPhone,
          password: registerPassword,
          password_confirmation: registerPasswordConfirmation,
          accept_terms: acceptTerms,
          accept_privacy_policy: acceptPrivacyPolicy,
          accept_personal_data: acceptPersonalData,
          accept_public_personal_data_distribution: acceptPublicPersonalData,
          turnstile_token: turnstileToken || undefined,
          phone_challenge_id: phoneChallenge?.challenge_id,
          phone_code: phoneCode.trim() || undefined,
        });
      }
    } catch (nextError) {
      resetTurnstile();
      setError(nextError instanceof Error ? nextError.message : "Не удалось выполнить вход");
    } finally {
      setLoading(false);
    }
  };

  const handleForgotPassword = async () => {
    if (!loginIdentifier.trim()) {
      setError("Введите почту, телефон или логин, чтобы запросить восстановление");
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const response = await requestPasswordReset(
        normalizeLoginIdentifier(loginIdentifier),
        turnstileToken || undefined,
      );
      resetTurnstile();
      setInfo(response.detail);
    } catch (nextError) {
      resetTurnstile();
      setError(nextError instanceof Error ? nextError.message : "Не удалось отправить запрос");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-modal-root" role="presentation">
      <button
        type="button"
        className="auth-modal-backdrop"
        aria-label="Закрыть"
        onClick={closeAuthModal}
      />
      <section
        className="auth-panel auth-modal-panel"
        role="dialog"
        aria-modal="true"
        aria-labelledby="auth-title"
      >
        <div className="auth-panel-header">
          <div>
            <p className="eyebrow">{APP_NAME}</p>
            <h1 id="auth-title">{mode === "login" ? "Вход" : "Регистрация"}</h1>
            <p className="auth-description">
              {mode === "login"
                ? "Войдите по почте, телефону или логину. Если входите по номеру, подтвердите его кодом."
                : "Создайте аккаунт, чтобы писать посты, хранить избранное и обращаться в техподдержку."}
            </p>
          </div>
          <button
            type="button"
            className="icon-button icon-button-muted"
            aria-label="Закрыть"
            onClick={closeAuthModal}
          >
            <X className="nav-icon" />
          </button>
        </div>

        <div className="auth-tabs" role="tablist" aria-label="Переключение формы">
          <button
            type="button"
            className={`auth-tab ${mode === "login" ? "is-active" : ""}`}
            onClick={() => {
              setMode("login");
              setPhoneChallenge(null);
              setPhoneCode("");
              setError(null);
              setInfo(null);
              resetTurnstile();
            }}
          >
            Вход
          </button>
          <button
            type="button"
            className={`auth-tab ${mode === "register" ? "is-active" : ""}`}
            onClick={() => {
              setMode("register");
              setPhoneChallenge(null);
              setPhoneCode("");
              setError(null);
              setInfo(null);
              resetTurnstile();
            }}
          >
            Регистрация
          </button>
        </div>

        <form className={`auth-form auth-form-${mode}`} onSubmit={handleSubmit}>
          {mode === "login" ? (
            <div className="auth-form-stack">
              <label className="field">
                <span>Почта, телефон или логин</span>
                <input
                  value={loginIdentifier}
                  autoComplete="username"
                  placeholder="Почта, логин или +7"
                  onChange={(event) => {
                    setLoginIdentifier(formatLoginIdentifier(event.target.value));
                    if (phoneChallenge) {
                      setPhoneChallenge(null);
                      setPhoneCode("");
                      resetTurnstile();
                    }
                  }}
                />
              </label>
              <label className="field">
                <span>Пароль</span>
                <input
                  type="password"
                  value={loginPassword}
                  onChange={(event) => setLoginPassword(event.target.value)}
                />
              </label>
              <button
                type="button"
                className="link-button"
                onClick={() => void handleForgotPassword()}
              >
                Забыли пароль?
              </button>
            </div>
          ) : (
            <div className="auth-form-stack">
              <div className="two-columns">
                <label className="field">
                  <span>Имя</span>
                  <input
                    value={displayName}
                    onChange={(event) => setDisplayName(event.target.value)}
                  />
                </label>
                <label className="field">
                  <span>Логин</span>
                  <input value={username} onChange={(event) => setUsername(event.target.value)} />
                </label>
                <label className="field">
                  <span>Электронная почта</span>
                  <input value={email} onChange={(event) => setEmail(event.target.value)} />
                </label>
                <label className="field">
                  <span>Телефон</span>
                  <input
                    type="tel"
                    inputMode="tel"
                    autoComplete="tel"
                    placeholder="+7 (999) 000-00-00"
                    value={phone}
                    onChange={(event) => {
                      setPhone(formatRuPhone(event.target.value));
                      if (phoneChallenge) {
                        setPhoneChallenge(null);
                        setPhoneCode("");
                        resetTurnstile();
                      }
                    }}
                    onFocus={() => {
                      if (!phone) {
                        setPhone("+7 ");
                      }
                    }}
                  />
                </label>
              </div>

              <label className="field">
                <span>Пароль</span>
                <input
                  type="password"
                  value={registerPassword}
                  onChange={(event) => setRegisterPassword(event.target.value)}
                />
              </label>

              <div className="password-checks">
                {registerChecks.map((check) => (
                  <div
                    key={check.label}
                    className={`password-check ${check.passed ? "is-passed" : ""}`}
                  >
                    {check.passed ? (
                      <CheckCircle2 className="password-check-icon" />
                    ) : (
                      <Circle className="password-check-icon" />
                    )}
                    <span>{check.label}</span>
                  </div>
                ))}
              </div>

              <label className="field">
                <span>Повтор пароля</span>
                <input
                  type="password"
                  value={registerPasswordConfirmation}
                  onChange={(event) => setRegisterPasswordConfirmation(event.target.value)}
                />
              </label>

              <div className="auth-legal-block">
                <label className="auth-legal-check">
                  <input
                    type="checkbox"
                    checked={acceptTerms}
                    onChange={(event) => setAcceptTerms(event.target.checked)}
                  />
                  <span>
                    Принимаю <LegalLink href="/help/terms">пользовательское соглашение</LegalLink>.
                  </span>
                </label>

                <label className="auth-legal-check">
                  <input
                    type="checkbox"
                    checked={acceptPrivacyPolicy}
                    onChange={(event) => setAcceptPrivacyPolicy(event.target.checked)}
                  />
                  <span>
                    Подтверждаю ознакомление с{" "}
                    <LegalLink href="/help/privacy-policy">
                      политикой обработки персональных данных
                    </LegalLink>
                    .
                  </span>
                </label>

                <label className="auth-legal-check">
                  <input
                    type="checkbox"
                    checked={acceptPersonalData}
                    onChange={(event) => setAcceptPersonalData(event.target.checked)}
                  />
                  <span>
                    Даю <LegalLink href="/help/personal-data-consent">согласие на обработку персональных данных</LegalLink>.
                  </span>
                </label>

                <label className="auth-legal-check">
                  <input
                    type="checkbox"
                    checked={acceptPublicPersonalData}
                    onChange={(event) => setAcceptPublicPersonalData(event.target.checked)}
                  />
                  <span>
                    При необходимости разрешаю публичное размещение данных по{" "}
                    <LegalLink href="/help/distribution-consent">
                      согласию на распространение персональных данных
                    </LegalLink>
                    .
                  </span>
                </label>
              </div>
            </div>
          )}

          {phoneChallenge ? (
            <div className="auth-phone-challenge">
              <p className="auth-phone-challenge-detail">{phoneChallenge.detail}</p>
              {phoneChallenge.channel === "receive" ? (
                <div className="auth-receive-number" aria-live="polite">
                  {phoneChallenge.receive_number}
                </div>
              ) : (
                <label className="field">
                  <span>
                    {phoneChallenge.channel === "call"
                      ? "Последние 4 цифры входящего номера"
                      : "Код из Telegram"}
                  </span>
                  <input
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    maxLength={phoneChallenge.code_length}
                    value={phoneCode}
                    onChange={(event) => setPhoneCode(event.target.value.replace(/\D/g, ""))}
                  />
                </label>
              )}
              {phoneChallenge.can_try_next_channel ? (
                <button
                  type="button"
                  className="link-button"
                  disabled={loading}
                  onClick={() => {
                    void (async () => {
                      setLoading(true);
                      setError(null);
                      try {
                        const nextChallenge = await resendPhoneChallenge({
                          challenge_id: phoneChallenge.challenge_id,
                          turnstile_token: turnstileToken || undefined,
                        });
                        setPhoneChallenge(nextChallenge);
                        setPhoneCode("");
                        setInfo(nextChallenge.detail);
                      } catch (nextError) {
                        resetTurnstile();
                        setError(
                          nextError instanceof Error
                            ? nextError.message
                            : "Не удалось отправить код другим способом",
                        );
                      } finally {
                        setLoading(false);
                      }
                    })();
                  }}
                >
                  Не пришло — отправить другим способом
                </button>
              ) : null}
            </div>
          ) : null}

          {protection?.turnstile.enabled && protection.turnstile.site_key && !phoneChallenge ? (
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
            {loading
              ? "Подождите..."
              : mode === "login"
                ? phoneChallenge
                  ? "Подтвердить и войти"
                  : "Войти"
                : phoneChallenge
                  ? "Подтвердить и создать аккаунт"
                  : protection?.phone_verification.enabled
                    ? "Получить код и создать аккаунт"
                    : "Создать аккаунт"}
          </button>
          </div>
        </form>
      </section>
    </div>
  );
}
