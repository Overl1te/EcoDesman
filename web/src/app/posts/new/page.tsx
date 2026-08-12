import type { Metadata } from "next";

import { PostEditorPage } from "@/components/post/post-editor-page";
import { buildNoIndexMetadata } from "@/lib/seo";

export const metadata: Metadata = buildNoIndexMetadata(
  "Новая публикация",
  "Редактор новой публикации ЭкоВыхухоль.",
);

export default function NewPostRoutePage() {
  return <PostEditorPage />;
}
