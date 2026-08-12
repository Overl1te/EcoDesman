import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { buildNoIndexMetadata } from "@/lib/seo";

export const metadata: Metadata = buildNoIndexMetadata(
  "Вход",
  "Служебная страница авторизации ЭкоВыхухоль.",
);

export default function AuthRoutePage() {
  redirect("/");
}
