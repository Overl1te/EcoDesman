import type { Metadata } from "next";

import { HelpCenterPage } from "@/components/help/help-center-page";
import { StructuredDataScript } from "@/components/seo/structured-data-script";
import { buildPageMetadata, buildWebPageStructuredData } from "@/lib/seo";

export const metadata: Metadata = buildPageMetadata({
  title: "Справка ЭкоВыхухоль — правовые документы сервиса",
  description:
    "Справочные и правовые документы сервиса ЭкоВыхухоль: персональные данные, условия использования, правила сервиса, контакты и реквизиты оператора.",
  path: "/help",
});

export default function HelpPage() {
  return (
    <>
      <StructuredDataScript
        data={[
          buildWebPageStructuredData({
            path: "/help",
            name: "Справка ЭкоВыхухоль",
            description:
              "Библиотека справочных и правовых документов сервиса ЭкоВыхухоль.",
            about: [
              "персональные данные",
              "условия сервиса",
              "правовые документы",
              "контакты оператора",
            ],
          }),
        ]}
      />
      <HelpCenterPage />
    </>
  );
}
