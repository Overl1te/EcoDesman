"use client";

import { X } from "lucide-react";
import { useEffect } from "react";

import { AppDownloadLinks } from "@/components/layout/app-download-links";

export function AppDownloadDialog({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  useEffect(() => {
    if (!open) {
      return;
    }

    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onClose();
      }
    };

    window.addEventListener("keydown", handleEscape);
    return () => window.removeEventListener("keydown", handleEscape);
  }, [onClose, open]);

  if (!open) {
    return null;
  }

  return (
    <div className="download-modal-root" role="presentation">
      <button
        type="button"
        className="download-modal-backdrop"
        aria-label="Закрыть окно скачивания приложения"
        onClick={onClose}
      />

      <section className="panel download-modal-panel" role="dialog" aria-modal="true">
        <div className="download-modal-header">
          <div>
            <p className="eyebrow">Скачать приложение</p>
            <h2>На телефоне лучше использовать нативную версию</h2>
            <p className="download-modal-description">
              В ней быстрее карта, стабильнее авторизация, удобнее уведомления и публикации.
            </p>
          </div>

          <button
            type="button"
            className="icon-button icon-button-muted"
            aria-label="Закрыть окно"
            onClick={onClose}
          >
            <X className="nav-icon" />
          </button>
        </div>

        <AppDownloadLinks
          compact
          title="Установить EcoDesman"
          description="iOS и Android доступны отдельными ссылками."
        />
      </section>
    </div>
  );
}
