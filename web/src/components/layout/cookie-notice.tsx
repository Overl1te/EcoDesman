"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

const COOKIE_CONSENT_KEY = "eco-desman-cookie-notice-v2";
const COOKIE_CONSENT_STORAGE_KEY = "eco-desman-cookie-notice-state-v2";

function readCookieConsent(): boolean {
  if (typeof window === "undefined") {
    return false;
  }

  const storageAccepted =
    window.localStorage.getItem(COOKIE_CONSENT_STORAGE_KEY) === "accepted";
  const cookieAccepted = document.cookie
    .split(";")
    .map((item) => item.trim())
    .some((item) => item === `${COOKIE_CONSENT_KEY}=accepted`);

  return storageAccepted || cookieAccepted;
}

function persistCookieConsent(): void {
  const expires = new Date();
  expires.setFullYear(expires.getFullYear() + 1);
  window.localStorage.setItem(COOKIE_CONSENT_STORAGE_KEY, "accepted");
  document.cookie = `${COOKIE_CONSENT_KEY}=accepted; expires=${expires.toUTCString()}; path=/; SameSite=Lax`;
}

export function CookieNotice() {
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setIsVisible(!readCookieConsent());
    }, 0);

    return () => {
      window.clearTimeout(timer);
    };
  }, []);

  if (!isVisible) {
    return null;
  }

  return (
    <aside className="cookie-notice" aria-label="Уведомление о cookie-файлах">
      <div className="cookie-notice-copy">
        <strong>Мы используем cookie-файлы</strong>
        <p>
          Технические cookie нужны для авторизации, продления сессии и сохранения
          базовых настроек интерфейса. Подробности описаны в{" "}
          <Link href="/help#cookies">уведомлении о cookie-файлах</Link>.
        </p>
      </div>

      <div className="cookie-notice-actions">
        <Link href="/help#cookies" className="button button-muted button-inline">
          Подробнее
        </Link>
        <button
          type="button"
          className="button button-primary button-inline"
          onClick={() => {
            persistCookieConsent();
            setIsVisible(false);
          }}
        >
          Понятно
        </button>
      </div>
    </aside>
  );
}
