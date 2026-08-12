import type { Metadata } from "next";

import { NotificationsPage } from "@/components/notifications/notifications-page";
import { buildNoIndexMetadata } from "@/lib/seo";

export const metadata: Metadata = buildNoIndexMetadata(
  "Уведомления",
  "Личные уведомления пользователя ЭкоВыхухоль.",
);

export default function NotificationsRoutePage() {
  return <NotificationsPage />;
}
