"use client";

import Link from "next/link";
import {
  Bookmark,
  Mail,
  MapPin,
  Phone,
  Settings2,
} from "lucide-react";
import { useEffect, useState } from "react";

import { AppShell } from "@/components/layout/app-shell";
import { PostCard } from "@/components/post/post-card";
import { useAuth } from "@/components/providers/auth-provider";
import { Avatar } from "@/components/ui/avatar";
import { EmptyState } from "@/components/ui/empty-state";
import { LoadingBlock } from "@/components/ui/loading-block";
import { getPublicProfile, listPosts } from "@/lib/api";
import { compactCount } from "@/lib/format";
import type { CurrentUser, PaginatedResponse, PostListItem } from "@/lib/types";

function getRoleLabel(role: CurrentUser["role"]) {
  if (role === "admin") {
    return "Админ";
  }

  if (role === "moderator") {
    return "Модератор";
  }

  return "Пользователь";
}

export function ProfilePage({ userId }: { userId?: number }) {
  const { user, isAuthenticated, refreshUser, openAuthModal } = useAuth();
  const [profile, setProfile] = useState<CurrentUser | null>(null);
  const [posts, setPosts] = useState<PaginatedResponse<PostListItem> | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;

    const load = async () => {
      setLoading(true);
      setError(null);

      try {
        const targetUser =
          typeof userId === "number" ? await getPublicProfile(userId, isAuthenticated) : user;

        if (!targetUser) {
          throw new Error("Требуется авторизация");
        }

        const targetPosts = await listPosts(
          { author_id: targetUser.id, ordering: "recent" },
          isAuthenticated,
        );

        if (active) {
          setProfile(targetUser);
          setPosts(targetPosts);
        }
      } catch (nextError) {
        if (active) {
          setError(
            nextError instanceof Error ? nextError.message : "Не удалось загрузить профиль",
          );
        }
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    };

    void load();

    return () => {
      active = false;
    };
  }, [isAuthenticated, user, userId]);

  const ownProfile = !userId || user?.id === userId;

  return (
    <AppShell title={ownProfile ? "Профиль" : profile?.name || "Профиль"}>
      {ownProfile && !isAuthenticated ? (
        <EmptyState
          title="Нужен вход"
          description="Профиль, избранное и настройки доступны только после авторизации."
          action={
            <button
              type="button"
              className="button button-primary"
              onClick={() => openAuthModal({ returnTo: "/profile" })}
            >
              Войти
            </button>
          }
        />
      ) : null}

      {!(ownProfile && !isAuthenticated) ? (
        <>
          {loading ? <LoadingBlock label="Загружаю профиль..." /> : null}

          {error ? (
            <EmptyState
              title="Не удалось открыть профиль"
              description={error}
              action={
                ownProfile && isAuthenticated ? (
                  <button
                    type="button"
                    className="button button-primary"
                    onClick={() => void refreshUser()}
                  >
                    Обновить
                  </button>
                ) : undefined
              }
            />
          ) : null}

          {profile ? (
            <>
              <section className="panel profile-panel">
                <div className="profile-top">
                  <Avatar user={profile} size="lg" />

                  <div className="profile-copy">
                    <div className="profile-heading">
                      <h2>{profile.name || profile.username}</h2>
                      <span className="tag">{getRoleLabel(profile.role)}</span>
                    </div>

                    <p className="muted">@{profile.username}</p>
                    {profile.status_text ? (
                      <p className="profile-status">{profile.status_text}</p>
                    ) : null}
                    {profile.bio ? <p className="profile-bio">{profile.bio}</p> : null}

                    <div className="meta-row">
                      {profile.city ? (
                        <span className="meta-item">
                          <MapPin className="meta-icon" />
                          <span>{profile.city}</span>
                        </span>
                      ) : null}
                      {ownProfile && profile.email ? (
                        <span className="meta-item">
                          <Mail className="meta-icon" />
                          <span>{profile.email}</span>
                        </span>
                      ) : null}
                      {ownProfile && profile.phone ? (
                        <span className="meta-item">
                          <Phone className="meta-icon" />
                          <span>{profile.phone}</span>
                        </span>
                      ) : null}
                    </div>

                    <div className="meta-row">
                      {profile.website_url ? <a href={profile.website_url}>Сайт</a> : null}
                      {profile.telegram_url ? <a href={profile.telegram_url}>Telegram</a> : null}
                      {profile.vk_url ? <a href={profile.vk_url}>VK</a> : null}
                      {profile.instagram_url ? <a href={profile.instagram_url}>Instagram</a> : null}
                    </div>
                  </div>
                </div>

                <div className="stats-grid">
                  <div className="stat-card">
                    <strong>{compactCount(profile.stats.posts_count)} </strong>
                    <span>Посты</span>
                  </div>
                  <div className="stat-card">
                    <strong>{compactCount(profile.stats.likes_received_count)} </strong>
                    <span>Лайки</span>
                  </div>
                  <div className="stat-card">
                    <strong>{compactCount(profile.stats.comments_count)} </strong>
                    <span>Комментарии</span>
                  </div>
                  <div className="stat-card">
                    <strong>{compactCount(profile.stats.views_received_count)} </strong>
                    <span>Просмотры</span>
                  </div>
                </div>

                {ownProfile && isAuthenticated ? (
                  <div className="profile-shortcuts">
                    <Link href="/favorites" className="profile-shortcut">
                      <span className="profile-shortcut-icon">
                        <Bookmark className="button-icon" />
                      </span>
                      <span className="profile-shortcut-copy">
                        <strong>Избранное</strong>
                        <small>Сохранённые публикации и точки</small>
                      </span>
                    </Link>

                    <Link href="/settings/profile" className="profile-shortcut">
                      <span className="profile-shortcut-icon">
                        <Settings2 className="button-icon" />
                      </span>
                      <span className="profile-shortcut-copy">
                        <strong>Настройки</strong>
                        <small>Профиль, пароль и персональные данные</small>
                      </span>
                    </Link>
                  </div>
                ) : null}
              </section>

              <section className="feed-main">
                <div className="feed-column">
                  {posts?.results.length ? (
                    posts.results.map((post) => <PostCard key={post.id} post={post} />)
                  ) : (
                    <EmptyState
                      title="Пока нет публикаций"
                      description="Когда пользователь что-то опубликует, посты появятся здесь."
                    />
                  )}
                </div>
              </section>
            </>
          ) : null}
        </>
      ) : null}
    </AppShell>
  );
}

