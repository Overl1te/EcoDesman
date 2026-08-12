"use client";

import { useRouter } from "next/navigation";
import { type FormEvent, useEffect, useState } from "react";

import { AppShell } from "@/components/layout/app-shell";
import { useAuth } from "@/components/providers/auth-provider";
import { EmptyState } from "@/components/ui/empty-state";
import { ImageDropzone } from "@/components/ui/image-dropzone";
import { LoadingBlock } from "@/components/ui/loading-block";
import { createPost, getPost, updatePost, uploadImages } from "@/lib/api";
import { buildPostEditPath, buildPostPath } from "@/lib/paths";
import type { PostDetail, PostWritePayload } from "@/lib/types";

const MAX_POST_BODY_LENGTH = 5000;

const EMPTY_EVENT_FORM = {
  event_date: null,
  event_location: "",
  event_starts_at: null,
  event_ends_at: null,
} satisfies Pick<
  PostWritePayload,
  "event_date" | "event_location" | "event_starts_at" | "event_ends_at"
>;

export function PostEditorPage({ postId }: { postId?: number }) {
  const router = useRouter();
  const { isAuthenticated, openAuthModal } = useAuth();
  const [loading, setLoading] = useState(Boolean(postId));
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [existing, setExisting] = useState<PostDetail | null>(null);
  const [existingImageUrls, setExistingImageUrls] = useState<string[]>([]);
  const [files, setFiles] = useState<File[]>([]);
  const [form, setForm] = useState<PostWritePayload>({
    title: "",
    body: "",
    kind: "news",
    is_published: true,
    ...EMPTY_EVENT_FORM,
  });

  useEffect(() => {
    if (!postId) {
      return;
    }

    void getPost(postId, true)
      .then((post) => {
        setExisting(post);
        setExistingImageUrls(post.images.map((image) => image.image_url));
        setForm({
          title: post.title,
          body: post.body,
          kind: post.kind,
          is_published: post.is_published,
          event_date: post.event_date,
          event_location: post.event_location,
          event_starts_at: post.event_starts_at,
          event_ends_at: post.event_ends_at,
        });
      })
      .catch((nextError: Error) => setError(nextError.message))
      .finally(() => setLoading(false));
  }, [postId]);

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setSaving(true);
    setError(null);

    if (form.kind === "event" && !form.event_date) {
      setSaving(false);
      setError("Укажите дату мероприятия.");
      return;
    }

    try {
      const uploadedUrls = files.length ? await uploadImages(files) : [];
      const payload: PostWritePayload =
        form.kind === "event"
          ? {
              ...form,
              image_urls: [...existingImageUrls, ...uploadedUrls],
            }
          : {
              ...form,
              ...EMPTY_EVENT_FORM,
              image_urls: [...existingImageUrls, ...uploadedUrls],
            };
      const result = postId ? await updatePost(postId, payload) : await createPost(payload);
      router.push(buildPostPath(result));
    } catch (nextError) {
      setError(
        nextError instanceof Error
          ? nextError.message
          : "Не удалось сохранить публикацию.",
      );
    } finally {
      setSaving(false);
    }
  };

  return (
    <AppShell title={postId ? "Редактирование поста" : "Новый пост"}>
      {!isAuthenticated ? (
        <EmptyState
          title="Нужен вход"
          description="Создание и редактирование публикаций доступно только после авторизации."
          action={
            <button
              type="button"
              className="button button-primary"
              onClick={() =>
                openAuthModal({ returnTo: postId ? buildPostEditPath(postId) : "/posts/new" })
              }
            >
              Войти
            </button>
          }
        />
      ) : null}

      {isAuthenticated ? (
        <>
          {loading ? <LoadingBlock label="Загружаю редактор..." /> : null}
          {error && !loading ? <EmptyState title="Ошибка" description={error} /> : null}
          {!loading ? (
            <section className="panel">
              <form className="stack-list" onSubmit={submit}>
                <div className="two-columns">
                  <label className="field">
                    <span>Заголовок</span>
                    <input
                      value={form.title || ""}
                      onChange={(event) =>
                        setForm((current) => ({ ...current, title: event.target.value }))
                      }
                    />
                  </label>
                  <label className="field">
                    <span>Тип публикации</span>
                    <select
                      value={form.kind || "news"}
                      onChange={(event) => {
                        const nextKind = event.target.value as PostWritePayload["kind"];
                        setForm((current) =>
                          nextKind === "event"
                            ? { ...current, kind: nextKind }
                            : { ...current, kind: nextKind, ...EMPTY_EVENT_FORM },
                        );
                      }}
                    >
                      <option value="news">Новость</option>
                      <option value="story">История</option>
                      <option value="event">Мероприятие</option>
                    </select>
                  </label>
                </div>

                <label className="field">
                  <span>Текст публикации</span>
                  <textarea
                    value={form.body || ""}
                    maxLength={MAX_POST_BODY_LENGTH}
                    onChange={(event) =>
                      setForm((current) => ({ ...current, body: event.target.value }))
                    }
                  />
                  <small className="muted">
                    {(form.body || "").length} / {MAX_POST_BODY_LENGTH} символов
                  </small>
                </label>

                {form.kind === "event" ? (
                  <div className="two-columns">
                    <label className="field">
                      <span>Дата мероприятия</span>
                      <input
                        type="date"
                        required
                        value={toDateOnlyInput(form.event_date)}
                        onChange={(event) => {
                          const nextDate = event.target.value || null;
                          setForm((current) => ({
                            ...current,
                            event_date: nextDate,
                            event_starts_at: syncIsoDate(nextDate, current.event_starts_at),
                            event_ends_at: syncIsoDate(nextDate, current.event_ends_at),
                          }));
                        }}
                      />
                    </label>
                    <label className="field">
                      <span>Место проведения</span>
                      <input
                        value={form.event_location || ""}
                        placeholder="По желанию"
                        onChange={(event) =>
                          setForm((current) => ({
                            ...current,
                            event_location: event.target.value,
                          }))
                        }
                      />
                    </label>
                    <label className="field">
                      <span>Начало</span>
                      <input
                        type="datetime-local"
                        value={toDateTimeLocalInput(form.event_starts_at)}
                        onChange={(event) =>
                          setForm((current) => ({
                            ...current,
                            event_date:
                              event.target.value.slice(0, 10) || current.event_date || null,
                            event_starts_at: toIsoOrNull(event.target.value),
                          }))
                        }
                      />
                    </label>
                    <label className="field">
                      <span>Окончание</span>
                      <input
                        type="datetime-local"
                        value={toDateTimeLocalInput(form.event_ends_at)}
                        onChange={(event) =>
                          setForm((current) => ({
                            ...current,
                            event_ends_at: toIsoOrNull(event.target.value),
                          }))
                        }
                      />
                    </label>
                  </div>
                ) : null}

                <ImageDropzone
                  title="Фотографии публикации"
                  description="Можно перетащить изображения прямо в область загрузки."
                  files={files}
                  existingImages={existingImageUrls.map((url) => ({
                    id: url,
                    url,
                    alt: "Изображение публикации",
                  }))}
                  browseLabel={files.length ? "Добавить ещё" : "Выбрать фото"}
                  onAddFiles={(nextFiles) => {
                    setFiles((current) => [...current, ...nextFiles]);
                  }}
                  onRemoveFile={(index) => {
                    setFiles((current) => current.filter((_, currentIndex) => currentIndex !== index));
                  }}
                  onRemoveExistingImage={(imageId) => {
                    setExistingImageUrls((current) =>
                      current.filter((url) => url !== String(imageId)),
                    );
                  }}
                />

                {existing?.images.length || files.length ? (
                  <p className="muted">
                    Текущие изображения сохранятся, новые добавятся после загрузки.
                  </p>
                ) : null}

                <label className="toggle-checkbox">
                  <input
                    type="checkbox"
                    checked={Boolean(form.is_published)}
                    onChange={(event) =>
                      setForm((current) => ({ ...current, is_published: event.target.checked }))
                    }
                  />
                  <span>Опубликовать сразу</span>
                </label>

                <button type="submit" className="button button-primary" disabled={saving}>
                  {saving ? "Сохраняю..." : "Сохранить"}
                </button>
              </form>
            </section>
          ) : null}
        </>
      ) : null}
    </AppShell>
  );
}

function toDateOnlyInput(value: string | null | undefined): string {
  return value ? value.slice(0, 10) : "";
}

function toDateTimeLocalInput(value: string | null | undefined): string {
  if (!value) {
    return "";
  }

  const date = new Date(value);
  const offset = date.getTimezoneOffset() * 60_000;
  return new Date(date.getTime() - offset).toISOString().slice(0, 16);
}

function toIsoOrNull(value: string): string | null {
  return value ? new Date(value).toISOString() : null;
}

function syncIsoDate(nextDate: string | null, isoValue: string | null | undefined): string | null {
  if (!nextDate || !isoValue) {
    return isoValue ?? null;
  }

  const localValue = toDateTimeLocalInput(isoValue);
  if (!localValue) {
    return isoValue;
  }

  return toIsoOrNull(`${nextDate}T${localValue.slice(11, 16)}`);
}
