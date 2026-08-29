import type { Metadata } from "next";

import { HelpDocumentPage } from "@/components/help/help-document-page";
import { StructuredDataScript } from "@/components/seo/structured-data-script";
import { buildPageMetadata, buildWebPageStructuredData } from "@/lib/seo";

const DOCUMENT_META: Record<string, { title: string; description: string }> = {
  "personal-data-consent": {
    title: "Согласие на обработку персональных данных",
    description:
      "Согласие на обработку персональных данных сервиса ЭкоВыхухоль: перечень сведений, цели, срок и порядок отзыва.",
  },
  "distribution-consent": {
    title: "Согласие на распространение персональных данных",
    description:
      "Отдельное согласие на распространение персональных данных в сервисе ЭкоВыхухоль: какие сведения могут быть публичными и как отозвать разрешение.",
  },
  "privacy-policy": {
    title: "Политика конфиденциальности",
    description:
      "Политика обработки персональных данных сервиса ЭкоВыхухоль: основания обработки, права пользователя и контакты оператора.",
  },
  cookies: {
    title: "Уведомление о cookie и локальном хранении",
    description:
      "Какие cookie и данные локального хранения использует ЭкоВыхухоль, зачем они нужны и как ими управлять.",
  },
  terms: {
    title: "Пользовательское соглашение",
    description:
      "Условия использования сервиса ЭкоВыхухоль: аккаунт, публикации, карта, модерация и ответственность сторон.",
  },
  "service-rules": {
    title: "Правила сервиса",
    description:
      "Правила сообщества ЭкоВыхухоль: допустимые публикации, запрещенные действия и меры модерации.",
  },
  "operator-contacts": {
    title: "Контакты и реквизиты оператора",
    description:
      "Реквизиты оператора сервиса ЭкоВыхухоль: Леонтьев Максим Павлович, ИНН 183701745709, контакты для обращений.",
  },
};

interface HelpDocumentRouteProps {
  params: Promise<{
    slug: string;
  }>;
}

export async function generateMetadata({ params }: HelpDocumentRouteProps): Promise<Metadata> {
  const { slug } = await params;
  const meta = DOCUMENT_META[slug];

  return buildPageMetadata({
    title: meta?.title ? `${meta.title} — ЭкоВыхухоль` : "Юридический документ ЭкоВыхухоль",
    description:
      meta?.description ?? "Справочный или правовой документ сервиса ЭкоВыхухоль.",
    path: `/help/${slug}`,
  });
}

export default async function HelpDocumentRoute({ params }: HelpDocumentRouteProps) {
  const { slug } = await params;
  const meta = DOCUMENT_META[slug];

  return (
    <>
      <StructuredDataScript
        data={[
          buildWebPageStructuredData({
            path: `/help/${slug}`,
            name: meta?.title ?? "Юридический документ ЭкоВыхухоль",
            description:
              meta?.description ?? "Справочный или правовой документ сервиса ЭкоВыхухоль.",
            about: ["правовые документы", "персональные данные", "условия сервиса"],
          }),
        ]}
      />
      <HelpDocumentPage slug={slug} />
    </>
  );
}
