import type { Metadata } from "next";
import { Suspense } from "react";

import { SupportCenterPage } from "@/components/support/support-center-page";
import { LoadingBlock } from "@/components/ui/loading-block";
import { buildNoIndexMetadata } from "@/lib/seo";

export const metadata: Metadata = buildNoIndexMetadata(
  "Поддержка",
  "Центр поддержки ЭкоВыхухоль для обращений, жалоб и вопросов пользователей.",
);

export default function SupportPage() {
  return (
    <Suspense fallback={<LoadingBlock />}>
      <SupportCenterPage />
    </Suspense>
  );
}
