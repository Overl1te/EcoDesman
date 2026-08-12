"use client";

import { Apple, ArrowUpRight, FolderGit2, Smartphone } from "lucide-react";

import { MOBILE_APP_LINKS } from "@/lib/config";

export function AppDownloadLinks({
  title = "Мобильная версия EcoDesman",
  description = "Выберите платформу и откройте актуальную страницу установки.",
  compact = false,
}: {
  title?: string;
  titleEn?: string;
  description?: string;
  descriptionEn?: string;
  compact?: boolean;
}) {
  return (
    <section className={`download-links ${compact ? "is-compact" : ""}`}>
      <div className="download-links-head">
        <p className="eyebrow">Мобильное приложение</p>
        <h3>{title}</h3>
        <p className="download-links-description">{description}</p>
      </div>

      <div className="download-links-grid">
        <a
          href={MOBILE_APP_LINKS.ios}
          target="_blank"
          rel="noreferrer"
          className="download-link-card"
        >
          <span className="download-link-icon">
            <Apple className="nav-icon" />
          </span>
          <span className="download-link-copy">
            <strong>iPhone и iPad</strong>
            <small>Открыть страницу iOS-версии</small>
          </span>
          <ArrowUpRight className="nav-icon" />
        </a>

        <a
          href={MOBILE_APP_LINKS.android}
          target="_blank"
          rel="noreferrer"
          className="download-link-card"
        >
          <span className="download-link-icon">
            <Smartphone className="nav-icon" />
          </span>
          <span className="download-link-copy">
            <strong>Android</strong>
            <small>Открыть страницу Android-версии</small>
          </span>
          <ArrowUpRight className="nav-icon" />
        </a>
      </div>

      <a
        href={MOBILE_APP_LINKS.repository}
        target="_blank"
        rel="noreferrer"
        className="button button-muted download-links-repo"
      >
        <FolderGit2 className="button-icon" />
        <span>{compact ? "Исходники" : "Открыть репозиторий приложения"}</span>
      </a>
    </section>
  );
}
