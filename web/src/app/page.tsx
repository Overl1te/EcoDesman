import type { Metadata } from "next";
import { connection } from "next/server";

import { MainFeedPage } from "@/components/feed/main-feed-page";
import { StructuredDataScript } from "@/components/seo/structured-data-script";
import {
  buildCollectionPageStructuredData,
  buildPageMetadata,
} from "@/lib/seo";

export const metadata: Metadata = buildPageMetadata({
  title: "ЭкоВыхухоль — экологическая карта, события и экосообщество",
  description:
    "ЭкоВыхухоль объединяет экологическую карту, экоточки, события, городские инициативы и экосообщество Нижнего Новгорода. Находите пункты переработки, полезные места и актуальные экологические публикации в одном сервисе.",
  path: "/",
});

export default async function HomePage() {
  await connection();

  return (
    <>
      <StructuredDataScript
        data={[
          buildCollectionPageStructuredData({
            path: "/",
            name: "ЭкоВыхухоль — экологическая карта, события и экосообщество",
            description:
              "Экологическая карта, экоточки, события сообщества и городские инициативы Нижнего Новгорода в одном сервисе.",
            about: [
              "экологическая карта",
              "экоточки",
              "пункты переработки",
              "экологические события",
              "городские инициативы",
              "экосообщество",
            ],
          }),
        ]}
      />
      <MainFeedPage />
    </>
  );
}
