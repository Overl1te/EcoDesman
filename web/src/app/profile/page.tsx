import type { Metadata } from "next";

import { ProfilePage } from "@/components/profile/profile-page";
import { buildNoIndexMetadata } from "@/lib/seo";

export const metadata: Metadata = buildNoIndexMetadata(
  "Мой профиль",
  "Личный профиль пользователя ЭкоВыхухоль.",
);

export default function ProfileRoutePage() {
  return <ProfilePage />;
}
