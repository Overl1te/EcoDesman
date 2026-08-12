"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  ArrowUpRight,
  Bookmark,
  CalendarDays,
  Check,
  CircleOff,
  Eye,
  Heart,
  MapPin,
  MessageCircle,
  PencilLine,
  Trash2,
  X,
} from "lucide-react";
import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";

import { AppShell } from "@/components/layout/app-shell";
import { useAuth } from "@/components/providers/auth-provider";
import { ReportContentButton } from "@/components/support/report-content-button";
import { Avatar } from "@/components/ui/avatar";
import { EmptyState } from "@/components/ui/empty-state";
import { LoadingBlock } from "@/components/ui/loading-block";
import {
  createComment,
  createCommentReport,
  createPostReport,
  deleteComment,
  deletePost,
  getPost,
  setEventCancelled,
  toggleFavorite,
  toggleLike,
  updateComment,
} from "@/lib/api";
import { formatDate, formatDateTime } from "@/lib/format";
import {
  buildPostEditPath,
  buildPostPath,
  buildProfilePath,
} from "@/lib/paths";
import type { PostComment, PostDetail } from "@/lib/types";

function getKindLabel(kind: PostDetail["kind"]) {
  if (kind === "event") {
    return "Мероприятие";
  }

  if (kind === "story") {
    return "История";
  }

  return "Новость";
}

function wasEdited(comment: PostComment) {
  return comment.updated_at !== comment.created_at;
}

export function PostDetailPage({
  postId,
  initialPost = null,
}: {
  postId: number;
  initialPost?: PostDetail | null;
}) {
  const router = useRouter();
  const { isAuthenticated, openAuthModal } = useAuth();
  const [post, setPost] = useState<PostDetail | null>(initialPost);
  const [commentBody, setCommentBody] = useState("");
  const [editingCommentId, setEditingCommentId] = useState<number | null>(null);
  const [editingCommentBody, setEditingCommentBody] = useState("");
  const [reactionBusy, setReactionBusy] = useState<"like" | "favorite" | "delete" | "cancel" | null>(null);
  const [commentSubmitting, setCommentSubmitting] = useState(false);
  const [commentBusyId, setCommentBusyId] = useState<number | null>(null);
  const [loading, setLoading] = useState(!initialPost);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      setPost(await getPost(postId, isAuthenticated));
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Не удалось загрузить пост.");
    } finally {
      setLoading(false);
    }
  }, [isAuthenticated, postId]);

  useEffect(() => {
    void load();
  }, [load]);

  const postPath = useMemo(() => (post ? buildPostPath(post) : `/posts/${postId}`), [post, postId]);
  const primaryImageUrl = useMemo(() => post?.images[0]?.image_url ?? null, [post]);

  const resetCommentEditor = () => {
    setEditingCommentId(null);
    setEditingCommentBody("");
  };

  const submitComment = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (!isAuthenticated) {
      openAuthModal({ returnTo: postPath });
      return;
    }

    if (!commentBody.trim()) {
      return;
    }

    setCommentSubmitting(true);

    try {
      await createComment(postId, commentBody.trim());
      setCommentBody("");
      await load();
    } finally {
      setCommentSubmitting(false);
    }
  };

  const handleToggleLike = async () => {
    if (!post) {
      return;
    }

    if (!isAuthenticated) {
      openAuthModal({ returnTo: postPath });
      return;
    }

    setReactionBusy("like");

    try {
      await toggleLike(post.id, post.is_liked);
      await load();
    } finally {
      setReactionBusy(null);
    }
  };

  const handleToggleFavorite = async () => {
    if (!post) {
      return;
    }

    if (!isAuthenticated) {
      openAuthModal({ returnTo: postPath });
      return;
    }

    setReactionBusy("favorite");

    try {
      await toggleFavorite(post.id, post.is_favorited);
      await load();
    } finally {
      setReactionBusy(null);
    }
  };

  const handleDeletePost = async () => {
    if (!post) {
      return;
    }

    setReactionBusy("delete");

    try {
      await deletePost(post.id);
      router.push("/profile");
    } finally {
      setReactionBusy(null);
    }
  };

  const handleToggleCancellation = async () => {
    if (!post) {
      return;
    }

    if (!isAuthenticated) {
      openAuthModal({ returnTo: postPath });
      return;
    }

    setReactionBusy("cancel");

    try {
      await setEventCancelled(post.id, !post.is_event_cancelled);
      await load();
    } finally {
      setReactionBusy(null);
    }
  };

  const beginCommentEdit = (comment: PostComment) => {
    setEditingCommentId(comment.id);
    setEditingCommentBody(comment.body);
  };

  const handleCommentSave = async (commentId: number) => {
    if (!editingCommentBody.trim()) {
      return;
    }

    setCommentBusyId(commentId);

    try {
      await updateComment(postId, commentId, editingCommentBody.trim());
      resetCommentEditor();
      await load();
    } finally {
      setCommentBusyId(null);
    }
  };

  const handleCommentDelete = async (commentId: number) => {
    setCommentBusyId(commentId);

    try {
      await deleteComment(postId, commentId);
      if (editingCommentId === commentId) {
        resetCommentEditor();
      }
      await load();
    } finally {
      setCommentBusyId(null);
    }
  };

  return (
    <AppShell
      title={post?.title || "Публикация"}
      actions={
        post?.can_edit ? (
          <Link href={buildPostEditPath(post.id)} className="button button-muted">
            <PencilLine className="button-icon" />
            <span>Редактировать</span>
          </Link>
        ) : null
      }
    >
      {loading ? <LoadingBlock label="Загружаю публикацию..." /> : null}
      {error ? <EmptyState title="Ошибка загрузки" description={error} /> : null}

      {post ? (
        <>
          <article className="panel stack-list">
            <header className="post-header">
              <Link href={buildProfilePath(post.author)} className="author-link">
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
                </span>
              </Link>

              <div className="post-card-head-tags">
                <span className="tag">{getKindLabel(post.kind)}</span>
                {post.kind === "event" && post.is_event_cancelled ? (
                  <span className="tag tag-danger">Отменено</span>
                ) : null}
              </div>
            </header>

            {post.title ? <h2>{post.title}</h2> : null}
            <div className="post-body">{post.body}</div>

            {post.kind === "event" ? (
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
                {post.is_event_cancelled && post.event_cancelled_at ? (
                  <span className="event-summary-item">
                    <CircleOff className="meta-icon" />
                    <span>Отменено {formatDateTime(post.event_cancelled_at)}</span>
                  </span>
                ) : null}
              </div>
            ) : null}

            {post.images.length ? (
              <div className="post-gallery">
                {post.images.map((image) => (
                  <a
                    key={image.id}
                    href={image.image_url}
                    target="_blank"
                    rel="noreferrer"
                    className="post-gallery-link"
                  >
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={image.image_url}
                      alt={post.title || "Изображение публикации"}
                      className="post-gallery-image"
                    />
                  </a>
                ))}
              </div>
            ) : null}

            <div className="meta-row">
              <button
                type="button"
                className={`metric-item metric-button ${post.is_liked ? "is-active is-liked" : ""}`}
                onClick={() => void handleToggleLike()}
                disabled={reactionBusy !== null}
                aria-label={post.is_liked ? "Убрать лайк" : "Поставить лайк"}
              >
                <Heart className="meta-icon" />
                <span>{post.likes_count} лайков</span>
              </button>
              <span className="metric-item">
                <MessageCircle className="meta-icon" />
                <span>{post.comments_count} комментариев</span>
              </span>
              <button
                type="button"
                className={`metric-item metric-button ${post.is_favorited ? "is-active is-favorited" : ""}`}
                onClick={() => void handleToggleFavorite()}
                disabled={reactionBusy !== null}
                aria-label={post.is_favorited ? "Убрать из избранного" : "Добавить в избранное"}
              >
                <Bookmark className="meta-icon" />
                <span>{post.favorites_count} в избранном</span>
              </button>
              <span className="metric-item">
                <Eye className="meta-icon" />
                <span>{post.view_count} просмотров</span>
              </span>
            </div>

            <div className="post-actions">
              {primaryImageUrl ? (
                <Link href={primaryImageUrl} className="button button-inline button-ghost">
                  <ArrowUpRight className="button-icon" />
                  <span>Открыть фото</span>
                </Link>
              ) : null}

              {!post.is_owner ? (
                <ReportContentButton
                  targetLabel={post.title || "Пост"}
                  onSubmit={(payload) => createPostReport(post.id, payload)}
                />
              ) : null}

              {post.kind === "event" && post.can_edit ? (
                <button
                  type="button"
                  className={`button button-inline ${post.is_event_cancelled ? "button-muted" : "button-ghost"}`}
                  onClick={() => void handleToggleCancellation()}
                  disabled={reactionBusy !== null}
                >
                  <CircleOff className="button-icon" />
                  <span>
                    {reactionBusy === "cancel"
                      ? "Сохраняю..."
                      : post.is_event_cancelled
                        ? "Вернуть мероприятие"
                        : "Отменить мероприятие"}
                  </span>
                </button>
              ) : null}

              {post.can_edit ? (
                <button
                  type="button"
                  className="button button-inline button-danger"
                  onClick={() => void handleDeletePost()}
                  disabled={reactionBusy !== null}
                >
                  <Trash2 className="button-icon" />
                  <span>Удалить</span>
                </button>
              ) : null}
            </div>
          </article>

          <section className="panel stack-list">
            <div className="section-row">
              <h3>Комментарии</h3>
            </div>

            {isAuthenticated ? (
              <form className="stack-list" onSubmit={submitComment}>
                <label className="field">
                  <span>Комментарий</span>
                  <textarea
                    value={commentBody}
                    onChange={(event) => setCommentBody(event.target.value)}
                    placeholder="Напишите, что думаете об этой публикации"
                  />
                </label>

                <button
                  type="submit"
                  className="button button-primary"
                  disabled={commentSubmitting}
                >
                  <MessageCircle className="button-icon" />
                  <span>{commentSubmitting ? "Отправляю..." : "Добавить комментарий"}</span>
                </button>
              </form>
            ) : (
              <EmptyState
                title="Войдите, чтобы комментировать"
                description="После авторизации откроется доступ к комментариям и реакциям."
                action={
                  <button
                    type="button"
                    className="button button-primary"
                    onClick={() => openAuthModal({ returnTo: postPath })}
                  >
                    Войти
                  </button>
                }
              />
            )}

            {post.comments.length ? (
              <div className="stack-list">
                {post.comments.map((comment) => {
                  const editing = editingCommentId === comment.id;
                  const busy = commentBusyId === comment.id;

                  return (
                    <article key={comment.id} className="comment-card">
                      <div className="comment-header">
                        <Link href={buildProfilePath(comment.author)} className="author-link">
                          <Avatar
                            user={{
                              avatar_url: comment.author.avatar_url,
                              name: comment.author.name,
                              username: comment.author.username,
                            }}
                            size="sm"
                          />

                          <span className="author-copy">
                            <strong>{comment.author.name}</strong>
                            <span className="comment-meta">
                              <span>{formatDateTime(comment.created_at)}</span>
                              {wasEdited(comment) ? <span className="chip">Изменён</span> : null}
                            </span>
                          </span>
                        </Link>

                        {!editing && (comment.can_edit || !comment.is_owner) ? (
                          <div className="comment-actions">
                            {!comment.is_owner ? (
                              <ReportContentButton
                                label="Пожаловаться"
                                targetLabel={comment.body.slice(0, 80) || "Комментарий"}
                                onSubmit={(payload) =>
                                  createCommentReport(post.id, comment.id, payload)
                                }
                              />
                            ) : null}
                            {comment.can_edit ? (
                              <>
                                <button
                                  type="button"
                                  className="button button-inline button-muted"
                                  onClick={() => beginCommentEdit(comment)}
                                  disabled={busy}
                                >
                                  <PencilLine className="button-icon" />
                                  <span>Редактировать</span>
                                </button>
                                <button
                                  type="button"
                                  className="button button-inline button-ghost"
                                  onClick={() => void handleCommentDelete(comment.id)}
                                  disabled={busy}
                                >
                                  <Trash2 className="button-icon" />
                                  <span>Удалить</span>
                                </button>
                              </>
                            ) : null}
                          </div>
                        ) : null}
                      </div>

                      {editing ? (
                        <div className="comment-editor">
                          <label className="field">
                            <span>Редактирование комментария</span>
                            <textarea
                              value={editingCommentBody}
                              onChange={(event) => setEditingCommentBody(event.target.value)}
                            />
                          </label>

                          <div className="comment-actions">
                            <button
                              type="button"
                              className="button button-inline button-primary"
                              onClick={() => void handleCommentSave(comment.id)}
                              disabled={busy}
                            >
                              <Check className="button-icon" />
                              <span>Сохранить</span>
                            </button>
                            <button
                              type="button"
                              className="button button-inline button-muted"
                              onClick={resetCommentEditor}
                              disabled={busy}
                            >
                              <X className="button-icon" />
                              <span>Отмена</span>
                            </button>
                            <button
                              type="button"
                              className="button button-inline button-ghost"
                              onClick={() => void handleCommentDelete(comment.id)}
                              disabled={busy}
                            >
                              <Trash2 className="button-icon" />
                              <span>Удалить</span>
                            </button>
                          </div>
                        </div>
                      ) : (
                        <p className="comment-body">{comment.body}</p>
                      )}
                    </article>
                  );
                })}
              </div>
            ) : (
              <EmptyState
                title="Комментариев пока нет"
                description="Станьте первым, кто оставит мнение об этой публикации."
              />
            )}
          </section>
        </>
      ) : null}
    </AppShell>
  );
}
