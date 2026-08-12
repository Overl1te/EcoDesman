"use client";

import { useEffect } from "react";
import { createPortal } from "react-dom";
import { X } from "lucide-react";

export function Modal({
  open,
  title,
  description,
  onClose,
  children,
  size = "md",
}: {
  open: boolean;
  title: string;
  description?: string;
  onClose: () => void;
  children: React.ReactNode;
  size?: "md" | "lg";
}) {
  useEffect(() => {
    if (!open) {
      return;
    }

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onClose();
      }
    };

    window.addEventListener("keydown", handleEscape);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", handleEscape);
    };
  }, [onClose, open]);

  if (!open || typeof document === "undefined") {
    return null;
  }

  return createPortal(
    <div className="app-modal-root" role="presentation">
      <button
        type="button"
        className="app-modal-backdrop"
        aria-label="Закрыть модальное окно"
        onClick={onClose}
      />

      <section
        className={`panel app-modal-panel ${size === "lg" ? "is-large" : ""}`}
        role="dialog"
        aria-modal="true"
        aria-label={title}
      >
        <div className="app-modal-header">
          <div>
            <h2>{title}</h2>
            {description ? <p className="app-modal-description">{description}</p> : null}
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

        {children}
      </section>
    </div>,
    document.body,
  );
}
