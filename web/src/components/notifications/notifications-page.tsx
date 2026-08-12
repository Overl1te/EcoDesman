"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { AppShell } from "@/components/layout/app-shell";
import { useAuth } from "@/components/providers/auth-provider";
import { EmptyState } from "@/components/ui/empty-state";
import { LoadingBlock } from "@/components/ui/loading-block";
import { listNotifications, readAllNotifications, readNotification } from "@/lib/api";
import { formatDateTime } from "@/lib/format";
import { buildPostPathFromParts } from "@/lib/paths";
import type { NotificationItem, NotificationResponse } from "@/lib/types";

function getNotificationTargetHref(notification: NotificationItem): string | null {
  if (notification.support_thread_id) {
    return `/support?thread=${notification.support_thread_id}`;
  }
  if (notification.post_id) {
    return buildPostPathFromParts({
      postId: notification.post_id,
      postSlug: notification.post_slug,
      authorUsername: notification.post_author_username,
    });
  }
  return null;
}

export function NotificationsPage() {
  const router = useRouter();
  const { isAuthenticated, openAuthModal } = useAuth();
  const [data, setData] = useState<NotificationResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [markingAllRead, setMarkingAllRead] = useState(false);
  const [openingNotificationId, setOpeningNotificationId] = useState<number | null>(null);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      setData(await listNotifications());
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Не удалось загрузить уведомления");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isAuthenticated) {
      void load();
    } else {
      setLoading(false);
    }
  }, [isAuthenticated]);

  const handleOpenNotification = async (notification: NotificationItem) => {
    setOpeningNotificationId(notification.id);
    try {
      if (!notification.is_read) {
        await readNotification(notification.id);
        setData((current) => {
          if (!current) {
            return current;
          }
          return {
            unread_count: current.unread_count > 0 ? current.unread_count - 1 : 0,
            results: current.results.map((item) =>
              item.id === notification.id ? { ...item, is_read: true } : item,
            ),
          };
        });
      }

      const href = getNotificationTargetHref(notification);
      if (href) {
        router.push(href);
      }
    } finally {
      setOpeningNotificationId(null);
    }
  };

  return (
    <AppShell
      title="Уведомления"
      actions={
        isAuthenticated ? (
          <button
            type="button"
            className="button button-muted"
            disabled={markingAllRead || !data?.unread_count}
            onClick={async () => {
              setMarkingAllRead(true);
              try {
                await readAllNotifications();
                await load();
              } finally {
                setMarkingAllRead(false);
              }
            }}
          >
            Отметить все прочитанным
          </button>
        ) : null
      }
    >
      {!isAuthenticated ? (
        <EmptyState
          title="Нужен вход"
          description="Уведомления доступны только авторизованным пользователям."
          action={
            <button type="button" className="button button-primary" onClick={() => openAuthModal()}>
              Войти
            </button>
          }
        />
      ) : null}

      {isAuthenticated ? (
        <>
          {loading ? <LoadingBlock label="Загружаю уведомления..." /> : null}
          {error ? <EmptyState title="Ошибка" description={error} /> : null}
          {!loading && !error ? (
            <section className="stack-list">
              {data?.results.length ? (
                data.results.map((notification) => {
                  const href = getNotificationTargetHref(notification);
                  return (
                    <article
                      key={notification.id}
                      className={`panel notification-item ${notification.is_read ? "" : "is-unread"}`}
                    >
                      <div>
                        <p className="eyebrow">{formatDateTime(notification.created_at)}</p>
                        <h3>{notification.title}</h3>
                        <p className="muted">{notification.body}</p>
                      </div>
                      {href ? (
                        <button
                          type="button"
                          className="button button-muted"
                          disabled={openingNotificationId === notification.id}
                          onClick={() => void handleOpenNotification(notification)}
                        >
                          {notification.support_thread_id ? "Открыть чат" : "Открыть пост"}
                        </button>
                      ) : (
                        <button
                          type="button"
                          className="button button-muted"
                          disabled={openingNotificationId === notification.id || notification.is_read}
                          onClick={() => void handleOpenNotification(notification)}
                        >
                          Пометить прочитанным
                        </button>
                      )}
                    </article>
                  );
                })
              ) : (
                <EmptyState
                  title="Уведомлений пока нет"
                  description="Когда на ваши публикации начнут реагировать или поддержка отправит ответ, события появятся здесь."
                />
              )}
            </section>
          ) : null}
        </>
      ) : null}
    </AppShell>
  );
}
