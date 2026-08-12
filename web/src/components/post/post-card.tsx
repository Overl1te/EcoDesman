"use client";

import Link from "next/link";
import { ArrowUpRight, Bookmark, CalendarDays, Eye, Heart, MapPin, MessageCircle } from "lucide-react";
import { useState } from "react";

import { useAuth } from "@/components/providers/auth-provider";
import { ReportContentButton } from "@/components/support/report-content-button";
import { Avatar } from "@/components/ui/avatar";
import { createPostReport, toggleFavorite, toggleLike } from "@/lib/api";
import { compactCount, formatDate, formatDateTime } from "@/lib/format";
import { buildPostPath, buildProfilePath } from "@/lib/paths";
import type { PostListItem } from "@/lib/types";

function getKindLabel(kind: PostListItem["kind"]) {
  if (kind === "event") {
    return "Мероприятие";
  }

  if (kind === "story") {
    return "История";
  }

  return "Новость";
}

export function PostCard({
  post,
  onUpdated,
}: {
  post: PostListItem;
  onUpdated?: (nextPost: PostListItem) => void;
}) {
  const { isAuthenticated, openAuthModal } = useAuth();
  const [busy, setBusy] = useState<"like" | "favorite" | null>(null);
  const postPath = buildPostPath(post);
  const authorPath = buildProfilePath(post.author);

  const handleLike = async () => {
    if (!isAuthenticated) {
      openAuthModal();
      return;
    }

    setBusy("like");

    try {
      await toggleLike(post.id, post.is_liked);
      onUpdated?.({
        ...post,
        is_liked: !post.is_liked,
        likes_count: post.likes_count + (post.is_liked ? -1 : 1),
      });
    } finally {
      setBusy(null);
    }
  };

  const handleFavorite = async () => {
    if (!isAuthenticated) {
      openAuthModal();
      return;
    }

    setBusy("favorite");

    try {
      await toggleFavorite(post.id, post.is_favorited);
      onUpdated?.({
        ...post,
        is_favorited: !post.is_favorited,
        favorites_count: post.favorites_count + (post.is_favorited ? -1 : 1),
      });
    } finally {
      setBusy(null);
    }
  };

  return (
    <article className="post-card">
      <header className="post-card-header">
        <Link href={authorPath} className="author-link">
          <Avatar
            user={{
              avatar_url: post.author.avatar_url,
              name: post.author.name,
              username: post.author.username,
            }}
          />

          <span className="author-copy">
            <strong>{post.author.name}</strong>
            <span className="author-meta">
              <CalendarDays className="meta-icon" />
              <small>{formatDateTime(post.published_at)}</small>
            </span>
            {post.author.status_text ? (
              <small className="author-status">{post.author.status_text}</small>
            ) : null}
          </span>
        </Link>

        <div className="post-card-head-tags">
          <span className="tag">{getKindLabel(post.kind)}</span>
          {post.kind === "event" && post.is_event_cancelled ? (
            <span className="tag tag-danger">Отменено</span>
          ) : null}
        </div>
      </header>

      <Link href={postPath} className="post-content">
        {post.title ? <h3>{post.title}</h3> : null}
        <p>{post.preview_text || post.body}</p>
      </Link>

      {post.kind === "event" && (post.event_date || post.event_starts_at || post.event_location) ? (
        <div className="event-summary">
          {post.event_date ? (
            <span className="event-summary-item">
              <CalendarDays className="meta-icon" />
              <span>{formatDate(`${post.event_date}T00:00:00`)}</span>
            </span>
          ) : null}

          {post.event_starts_at ? (
            <span className="event-summary-item">
              <CalendarDays className="meta-icon" />
              <span>{formatDateTime(post.event_starts_at)}</span>
            </span>
          ) : null}

          {post.event_location ? (
            <span className="event-summary-item">
              <MapPin className="meta-icon" />
              <span>{post.event_location}</span>
            </span>
          ) : null}
        </div>
      ) : null}

      {post.preview_image_url ? (
        <Link href={postPath} className="post-image-link">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={post.preview_image_url}
            alt={post.title || "Изображение публикации"}
            className="post-image"
          />
        </Link>
      ) : null}

      <footer className="post-card-footer">
        <div className="metrics-row">
          <button
            type="button"
            className={`metric-item metric-button ${post.is_liked ? "is-active is-liked" : ""}`}
            onClick={() => void handleLike()}
            disabled={busy !== null}
            aria-label={post.is_liked ? "Убрать лайк" : "Поставить лайк"}
          >
            <Heart className="meta-icon" />
            <span>{compactCount(post.likes_count)}</span>
          </button>
          <button
            type="button"
            className={`metric-item metric-button ${post.is_favorited ? "is-active is-favorited" : ""}`}
            onClick={() => void handleFavorite()}
            disabled={busy !== null}
            aria-label={post.is_favorited ? "Убрать из избранного" : "Добавить в избранное"}
          >
            <Bookmark className="meta-icon" />
            <span>{compactCount(post.favorites_count)}</span>
          </button>
          <span className="metric-item">
            <MessageCircle className="meta-icon" />
            <span>{compactCount(post.comments_count)}</span>
          </span>
          <span className="metric-item">
            <Eye className="meta-icon" />
            <span>{compactCount(post.view_count)}</span>
          </span>
        </div>

        <div className="post-actions">
          {!post.is_owner ? (
            <ReportContentButton
              targetLabel={post.title || post.preview_text || "Пост"}
              onSubmit={(payload) => createPostReport(post.id, payload)}
            />
          ) : null}

          <Link href={postPath} className="button button-inline button-ghost">
            <ArrowUpRight className="button-icon" />
            <span>Открыть</span>
          </Link>
        </div>
      </footer>
    </article>
  );
}
