import type { Metadata } from "next";

import { PostEditorPage } from "@/components/post/post-editor-page";
import { buildNoIndexMetadata } from "@/lib/seo";

type EditPostRouteProps = {
  params: Promise<{ username: string }>;
};

export const metadata: Metadata = buildNoIndexMetadata(
  "Редактирование публикации",
  "Служебная страница редактирования публикации ЭкоВыхухоль.",
);

export default async function EditPostRoutePage({ params }: EditPostRouteProps) {
  const resolvedParams = await params;
  return <PostEditorPage postId={Number(resolvedParams.username)} />;
}
