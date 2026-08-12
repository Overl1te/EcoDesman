import type { Metadata } from "next";

import { AppDownloadLinks } from "@/components/layout/app-download-links";
import { AppShell } from "@/components/layout/app-shell";
import { StructuredDataScript } from "@/components/seo/structured-data-script";
import { MOBILE_APP_LINKS } from "@/lib/config";
import {
  buildMobileApplicationStructuredData,
  buildPageMetadata,
  buildWebPageStructuredData,
} from "@/lib/seo";

export const metadata: Metadata = buildPageMetadata({
  title: "Скачать приложение ЭкоВыхухоль для Android и iPhone",
  description:
    "Скачайте мобильное приложение ЭкоВыхухоль для Android и iPhone. Приложение дает быстрый доступ к карте экоточек, экологическим событиям, публикациям сообщества и уведомлениям.",
  path: "/download",
});

export default function DownloadPage() {
  return (
    <>
      <StructuredDataScript
        data={[
          buildWebPageStructuredData({
            path: "/download",
            name: "Скачать приложение ЭкоВыхухоль",
            description:
              "Страница загрузки мобильного приложения ЭкоВыхухоль для Android и iPhone.",
            about: [
              "мобильное приложение",
              "карта экоточек",
              "экологические события",
              "уведомления сообщества",
            ],
          }),
          buildMobileApplicationStructuredData({
            path: "/download",
            name: "ЭкоВыхухоль",
            description:
              "Мобильное приложение ЭкоВыхухоль для карты экоточек, экологических событий, публикаций сообщества и уведомлений.",
            downloadUrls: [
              MOBILE_APP_LINKS.android,
              MOBILE_APP_LINKS.ios,
              MOBILE_APP_LINKS.repository,
            ],
          }),
        ]}
      />
      <AppShell title="Приложение" titleTag="p">
        <section className="support-layout">
          <section className="panel info-panel">
            <p className="eyebrow">Мобильный опыт</p>
            <h2 className="info-title">Зачем устанавливать приложение на телефон</h2>
            <p className="info-description">
              Нативная сборка удобнее для повседневной работы с картой, уведомлениями и
              публикациями сообщества. Она быстрее открывается, лучше ведет себя на мобильных
              устройствах и проще интегрируется в привычный сценарий использования сервиса.
            </p>
          </section>

          <section className="panel info-panel">
            <AppDownloadLinks
              title="Доступные платформы"
              description="Выберите нужную платформу и откройте актуальную страницу загрузки мобильного приложения ЭкоВыхухоль."
            />
          </section>
        </section>
      </AppShell>
    </>
  );
}
