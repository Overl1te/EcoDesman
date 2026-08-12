import type { Metadata } from "next";

import { AdminPage } from "@/components/admin/admin-page";
import { buildNoIndexMetadata } from "@/lib/seo";

export const metadata: Metadata = buildNoIndexMetadata(
  "Администрирование",
  "Служебный раздел модерации ЭкоВыхухоль.",
);

export default function AdminRoutePage() {
  return <AdminPage />;
}
