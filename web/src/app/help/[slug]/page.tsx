import type { Metadata } from "next";

import { HelpDocumentPage } from "@/components/help/help-document-page";
import { StructuredDataScript } from "@/components/seo/structured-data-script";
import { buildPageMetadata, buildWebPageStructuredData } from "@/lib/seo";

interface HelpDocumentRouteProps {
  params: Promise<{
    slug: string;
  }>;
}

export async function generateMetadata({ params }: HelpDocumentRouteProps): Promise<Metadata> {
  const { slug } = await params;

  return buildPageMetadata({
    title: "Юридический документ ЭкоВыхухоль",
    description: "Справочный или правовой документ сервиса ЭкоВыхухоль.",
    path: `/help/${slug}`,
  });
}

export default async function HelpDocumentRoute({ params }: HelpDocumentRouteProps) {
  const { slug } = await params;

  return (
    <>
      <StructuredDataScript
        data={[
          buildWebPageStructuredData({
            path: `/help/${slug}`,
            name: "Юридический документ ЭкоВыхухоль",
            description: "Справочный или правовой документ сервиса ЭкоВыхухоль.",
            about: ["правовые документы", "персональные данные", "условия сервиса"],
          }),
        ]}
      />
      <HelpDocumentPage slug={slug} />
    </>
  );
}
