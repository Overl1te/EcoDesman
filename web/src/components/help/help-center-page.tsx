"use client";

import Link from "next/link";
import { Download, FileText, Mail, ShieldCheck } from "lucide-react";
import { useEffect, useMemo, useState, type ReactNode } from "react";

import { AppShell } from "@/components/layout/app-shell";
import { LoadingBlock } from "@/components/ui/loading-block";
import { getHelpCenterContent } from "@/lib/api";
import type { HelpCenterResponse, HelpDocument } from "@/lib/types";

function DocumentCard({ document }: { document: HelpDocument }) {
  return (
    <article className="legal-doc-card">
      <div className="legal-doc-card-main">
        <div className="legal-doc-card-icon" aria-hidden="true">
          <FileText className="nav-icon" />
        </div>
        <h3>{document.label}</h3>
        <p>{document.description || document.summary}</p>
      </div>

      <div className="legal-doc-card-footer">
        <div className="legal-doc-meta">
          <span>Обновлено: {document.updated_at}</span>
          <span className="legal-doc-status">
            <ShieldCheck className="status-icon" />
            {document.status}
          </span>
        </div>

        <div className="legal-doc-actions">
          <Link href={`/help/${document.slug}`} className="button button-primary">
            Открыть
          </Link>
          <a
            href={document.pdf_download_url}
            className="button button-muted"
            target="_blank"
            rel="noreferrer"
          >
            <Download className="button-icon" />
            <span>Скачать PDF</span>
          </a>
        </div>
      </div>
    </article>
  );
}

export function HelpCenterPage({
  intro,
  afterContent,
}: {
  intro?: ReactNode;
  afterContent?: ReactNode;
}) {
  const [content, setContent] = useState<HelpCenterResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    void getHelpCenterContent()
      .then((nextContent) => {
        if (!cancelled) {
          setContent(nextContent);
        }
      })
      .catch((nextError) => {
        if (!cancelled) {
          setError(
            nextError instanceof Error
              ? nextError.message
              : "Не удалось загрузить справочные документы",
          );
        }
      });

    return () => {
      cancelled = true;
    };
  }, []);

  const documentsById = useMemo(() => {
    const map = new Map<string, HelpDocument>();
    content?.documents.forEach((document) => {
      map.set(document.id, document);
    });
    return map;
  }, [content]);

  if (!content && !error) {
    return (
      <AppShell title="Справка" titleTag="p">
        {intro}
        <LoadingBlock />
        {afterContent}
      </AppShell>
    );
  }

  if (!content) {
    return (
      <AppShell title="Справка" titleTag="p">
        {intro}
        <section className="legal-help-page">
          <div className="legal-help-error">
            <h2>Не удалось загрузить справку</h2>
            <p>{error ?? "Попробуйте обновить страницу позже."}</p>
          </div>
        </section>
        {afterContent}
      </AppShell>
    );
  }

  return (
    <AppShell title="Справка" titleTag="p">
      {intro}
      <main className="legal-help-page">
        <header className="legal-help-header">
          <p className="eyebrow">Документы сервиса</p>
          <h1>{content.overview.title}</h1>
          <p className="legal-help-subtitle">{content.overview.description}</p>
          <p className="legal-help-lead">{content.overview.lead}</p>
        </header>

        <div className="legal-doc-groups">
          {content.document_groups.map((group) => {
            const documents = group.document_ids
              .map((documentId) => documentsById.get(documentId))
              .filter((document): document is HelpDocument => Boolean(document));

            if (!documents.length) {
              return null;
            }

            return (
              <section key={group.id} className="legal-doc-group">
                <div className="legal-doc-group-head">
                  <h2>{group.title}</h2>
                </div>
                <div className="legal-doc-grid">
                  {documents.map((document) => (
                    <DocumentCard key={document.id} document={document} />
                  ))}
                </div>
              </section>
            );
          })}
        </div>

        <section className="legal-help-contact">
          <div>
            <h2>{content.contact_block.title}</h2>
            <p>
              По вопросам документов и обработки персональных данных можно написать
              оператору сервиса.
            </p>
            <dl className="legal-help-contact-details">
              {content.contact_block.operator ? (
                <div>
                  <dt>Оператор</dt>
                  <dd>{content.contact_block.operator}</dd>
                </div>
              ) : null}
              {content.contact_block.inn ? (
                <div>
                  <dt>ИНН</dt>
                  <dd>{content.contact_block.inn}</dd>
                </div>
              ) : null}
              {content.contact_block.ogrn ? (
                <div>
                  <dt>ОГРН</dt>
                  <dd>{content.contact_block.ogrn}</dd>
                </div>
              ) : null}
              {content.contact_block.address ? (
                <div>
                  <dt>Адрес</dt>
                  <dd>{content.contact_block.address}</dd>
                </div>
              ) : null}
            </dl>
          </div>
          <a href={`mailto:${content.contact_block.email}`} className="button button-primary">
            <Mail className="button-icon" />
            <span>{content.contact_block.email}</span>
          </a>
        </section>
      </main>
      {afterContent}
    </AppShell>
  );
}
