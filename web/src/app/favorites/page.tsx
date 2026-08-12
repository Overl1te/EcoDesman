import type { Metadata } from "next";
import { Suspense } from "react";

import { FavoritesFeedPage } from "@/components/feed/favorites-feed-page";
import { LoadingBlock } from "@/components/ui/loading-block";
import { buildNoIndexMetadata } from "@/lib/seo";

export const metadata: Metadata = buildNoIndexMetadata(
  "Избранное",
  "Личный список избранных публикаций и мест в ЭкоВыхухоль.",
);

export default function FavoritesPageRoute() {
  return (
    <Suspense fallback={<LoadingBlock label="Загружаю избранное..." />}>
      <FavoritesFeedPage />
    </Suspense>
  );
}
