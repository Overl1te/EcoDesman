import type { Metadata } from "next";

import { ProfileSettingsPage } from "@/components/profile/profile-settings-page";
import { buildNoIndexMetadata } from "@/lib/seo";

export const metadata: Metadata = buildNoIndexMetadata(
  "Настройки профиля",
  "Личные настройки профиля пользователя ЭкоВыхухоль.",
);

export default function ProfileSettingsRoutePage() {
  return <ProfileSettingsPage />;
}
