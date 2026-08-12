import type { ReactNode } from "react";

import { FeedPageContent } from "@/components/feed/feed-page-content";

export function MainFeedPage({
  intro,
  afterContent,
}: {
  intro?: ReactNode;
  afterContent?: ReactNode;
}) {
  return (
    <FeedPageContent
      title="ЭкоВыхухоль"
      loadingLabel="Загружаю ленту..."
      emptyStateTitle="Публикаций пока нет"
      emptyStateDescription="Попробуйте изменить фильтры или зайдите позже."
      intro={intro}
      afterContent={afterContent}
    />
  );
}
