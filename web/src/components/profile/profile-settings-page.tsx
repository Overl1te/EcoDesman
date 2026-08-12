"use client";

import { Camera, ImagePlus, Trash2 } from "lucide-react";
import { FormEvent, useEffect, useRef, useState } from "react";

import { AppShell } from "@/components/layout/app-shell";
import { useAuth } from "@/components/providers/auth-provider";
import { Avatar } from "@/components/ui/avatar";
import { uploadImages } from "@/lib/api";

export function ProfileSettingsPage() {
  const { user, updateProfile, changePassword } = useAuth();
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const [status, setStatus] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [passwords, setPasswords] = useState({
    current_password: "",
    new_password: "",
    new_password_confirmation: "",
  });
  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [avatarPreviewUrl, setAvatarPreviewUrl] = useState<string | null>(null);
  const [removeAvatar, setRemoveAvatar] = useState(false);

  useEffect(() => {
    return () => {
      if (avatarPreviewUrl) {
        URL.revokeObjectURL(avatarPreviewUrl);
      }
    };
  }, [avatarPreviewUrl]);

  if (!user) {
    return (
      <AppShell title="Настройки профиля">
        <section className="panel">Требуется авторизация.</section>
      </AppShell>
    );
  }

  const previewUser = {
    ...user,
    avatar_url: removeAvatar ? "" : (avatarPreviewUrl ?? user.avatar_url),
  };

  const avatarHint = avatarFile
    ? `Выбрано: ${avatarFile.name}`
    : removeAvatar
      ? "Аватар будет удалён после сохранения."
      : "PNG, JPG или WebP. После сохранения фото сразу обновится в профиле.";

  const saveProfile = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setStatus(null);
    setError(null);

    try {
      const formData = new FormData(event.currentTarget);
      let avatarUrl = removeAvatar ? "" : user.avatar_url;

      if (avatarFile) {
        const [uploaded] = await uploadImages([avatarFile]);
        avatarUrl = uploaded;
      }

      await updateProfile({
        display_name: String(formData.get("display_name") || ""),
        username: String(formData.get("username") || ""),
        email: String(formData.get("email") || ""),
        status_text: String(formData.get("status_text") || ""),
        bio: String(formData.get("bio") || ""),
        city: String(formData.get("city") || ""),
        telegram_url: String(formData.get("telegram_url") || ""),
        vk_url: String(formData.get("vk_url") || ""),
        instagram_url: String(formData.get("instagram_url") || ""),
        avatar_url: avatarUrl,
      });

      if (avatarPreviewUrl) {
        URL.revokeObjectURL(avatarPreviewUrl);
      }
      setAvatarFile(null);
      setAvatarPreviewUrl(null);
      setRemoveAvatar(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = "";
      }
      setStatus("Профиль обновлён");
    } catch (nextError) {
      setError(
        nextError instanceof Error ? nextError.message : "Не удалось сохранить профиль",
      );
    }
  };

  const savePassword = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setStatus(null);
    setError(null);

    try {
      await changePassword(passwords);
      setPasswords({
        current_password: "",
        new_password: "",
        new_password_confirmation: "",
      });
      setStatus("Пароль обновлён");
    } catch (nextError) {
      setError(
        nextError instanceof Error ? nextError.message : "Не удалось сменить пароль",
      );
    }
  };

  return (
    <AppShell title="Настройки профиля">
      <section className="panel stack-list">
        <div className="profile-top">
          <Avatar user={previewUser} size="lg" />
          <div>
            <h2>Основные данные</h2>
            <p className="muted">
              Обновите имя, статус, описание, аватар и ссылки на соцсети.
            </p>
          </div>
        </div>

        <form className="stack-list" onSubmit={saveProfile}>
          <section className="avatar-settings-card">
            <div className="avatar-settings-preview">
              <Avatar user={previewUser} size="lg" />
              <div className="avatar-settings-copy">
                <strong>Фото профиля</strong>
                <p>{avatarHint}</p>
              </div>
            </div>

            <div className="avatar-settings-actions">
              <input
                ref={fileInputRef}
                type="file"
                name="avatar"
                accept="image/*"
                className="visually-hidden"
                onChange={(event) => {
                  const file = event.target.files?.[0] ?? null;
                  if (avatarPreviewUrl) {
                    URL.revokeObjectURL(avatarPreviewUrl);
                  }
                  setAvatarFile(file);
                  setAvatarPreviewUrl(file ? URL.createObjectURL(file) : null);
                  setRemoveAvatar(false);
                }}
              />

              <button
                type="button"
                className="button button-primary"
                onClick={() => fileInputRef.current?.click()}
              >
                <ImagePlus className="button-icon" />
                <span>{user.avatar_url || avatarFile ? "Сменить фото" : "Добавить фото"}</span>
              </button>

              {(Boolean(user.avatar_url) || avatarFile != null) ? (
                <button
                  type="button"
                  className="button button-muted"
                  onClick={() => {
                    if (avatarPreviewUrl) {
                      URL.revokeObjectURL(avatarPreviewUrl);
                    }
                    setAvatarFile(null);
                    setAvatarPreviewUrl(null);
                    setRemoveAvatar(true);
                    if (fileInputRef.current) {
                      fileInputRef.current.value = "";
                    }
                  }}
                >
                  <Trash2 className="button-icon" />
                  <span>Убрать фото</span>
                </button>
              ) : null}
            </div>
          </section>

          <div className="two-columns">
            <label className="field">
              <span>Имя</span>
              <input name="display_name" defaultValue={user.name} />
            </label>
            <label className="field">
              <span>Логин</span>
              <input name="username" defaultValue={user.username} />
            </label>
            <label className="field">
              <span>Email</span>
              <input name="email" defaultValue={user.email} />
            </label>
            <label className="field">
              <span>Город</span>
              <input name="city" defaultValue={user.city} />
            </label>
            <label className="field">
              <span>Статус</span>
              <input name="status_text" defaultValue={user.status_text} />
            </label>
          </div>

          <label className="field">
            <span>Описание</span>
            <textarea name="bio" defaultValue={user.bio} />
          </label>

          <div className="two-columns">
            <label className="field">
              <span>Telegram</span>
              <input name="telegram_url" defaultValue={user.telegram_url} />
            </label>
            <label className="field">
              <span>VK</span>
              <input name="vk_url" defaultValue={user.vk_url} />
            </label>
            <label className="field">
              <span>Instagram</span>
              <input name="instagram_url" defaultValue={user.instagram_url} />
            </label>
          </div>

          {status ? <div className="form-banner is-info">{status}</div> : null}
          {error ? <div className="form-banner is-error">{error}</div> : null}

          <button type="submit" className="button button-primary">
            <Camera className="button-icon" />
            <span>Сохранить профиль</span>
          </button>
        </form>
      </section>

      <section className="panel stack-list">
        <div>
          <h2>Смена пароля</h2>
          <p className="muted">
            После смены пароля старые refresh-сессии будут сброшены.
          </p>
        </div>

        <form className="stack-list" onSubmit={savePassword}>
          <label className="field">
            <span>Текущий пароль</span>
            <input
              type="password"
              value={passwords.current_password}
              onChange={(event) =>
                setPasswords((current) => ({
                  ...current,
                  current_password: event.target.value,
                }))
              }
            />
          </label>

          <div className="two-columns">
            <label className="field">
              <span>Новый пароль</span>
              <input
                type="password"
                value={passwords.new_password}
                onChange={(event) =>
                  setPasswords((current) => ({
                    ...current,
                    new_password: event.target.value,
                  }))
                }
              />
            </label>
            <label className="field">
              <span>Повтор пароля</span>
              <input
                type="password"
                value={passwords.new_password_confirmation}
                onChange={(event) =>
                  setPasswords((current) => ({
                    ...current,
                    new_password_confirmation: event.target.value,
                  }))
                }
              />
            </label>
          </div>

          <button type="submit" className="button button-primary">
            Сменить пароль
          </button>
        </form>
      </section>
    </AppShell>
  );
}
