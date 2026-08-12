import { FeedPageContent } from "@/components/feed/feed-page-content";

export function FavoritesFeedPage() {
  return (
    <FeedPageContent
      title="Избранное"
      loadingLabel="Загружаю избранное..."
      emptyStateTitle="В избранном пока пусто"
      emptyStateDescription="Сохраняйте интересные публикации, чтобы они появились здесь."
      favoritesOnly
      requiresAuth
      authReturnTo="/favorites"
      authTitle="Нужен вход"
      authDescription="Избранное доступно только после авторизации."
    />
  );
}
