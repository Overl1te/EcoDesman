"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

import { AppShell } from "@/components/layout/app-shell";
import { LoadingBlock } from "@/components/ui/loading-block";
import { useAuth } from "@/components/providers/auth-provider";

function parseAcceptanceState(state: string | null) {
  const value = state ?? "";
  return {
    accept_terms: value[0] === "1",
    accept_privacy_policy: value[1] === "1",
    accept_personal_data: value[2] === "1",
    accept_public_personal_data_distribution: value[3] === "1",
  };
}

export function SocialCallbackPage({ provider }: { provider: string }) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { loginWithSocial } = useAuth();

  const code = searchParams.get("code");
  const oauthError = searchParams.get("error");
  const state = searchParams.get("state");
  const initialError = oauthError
    ? "Провайдер отменил авторизацию или вернул ошибку."
    : !code
      ? "Не найден код авторизации. Попробуйте начать вход заново."
      : null;
  const [error, setError] = useState<string | null>(initialError);
  const acceptances = useMemo(() => parseAcceptanceState(state), [state]);

  useEffect(() => {
    if (initialError || !code) {
      return;
    }

    const redirectUri = `${window.location.origin}/auth/social/${provider}/callback`;

    void loginWithSocial({
      provider,
      code,
      redirect_uri: redirectUri,
      ...acceptances,
    })
      .then(() => {
        router.replace("/");
      })
      .catch((nextError) => {
        setError(
          nextError instanceof Error
            ? nextError.message
            : "Не удалось завершить вход через внешний сервис.",
        );
      });
  }, [acceptances, code, initialError, loginWithSocial, provider, router]);

  return (
    <AppShell title="Вход" titleTag="p">
      <main className="auth-callback-page">
        {error ? (
          <section className="auth-callback-panel">
            <h1>Не удалось войти</h1>
            <p>{error}</p>
            <Link href="/" className="button button-primary">
              На главную
            </Link>
          </section>
        ) : (
          <section className="auth-callback-panel">
            <h1>Завершаем вход</h1>
            <p>Проверяем ответ провайдера и создаем сессию.</p>
            <LoadingBlock />
          </section>
        )}
      </main>
    </AppShell>
  );
}
