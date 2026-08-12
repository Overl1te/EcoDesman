"use client";

import Link from "next/link";
import { Download, Info, Mail, Printer } from "lucide-react";
import { useEffect, useState } from "react";

import { AppShell } from "@/components/layout/app-shell";
import { LoadingBlock } from "@/components/ui/loading-block";
import { getHelpDocument } from "@/lib/api";
import type { HelpDocument } from "@/lib/types";

function BulletList({ items }: { items?: string[] }) {
  if (!items?.length) {
    return null;
  }

  return (
    <ul>
      {items.map((item) => (
        <li key={item}>{item}</li>
      ))}
    </ul>
  );
}

function OperatorDetails({ document }: { document: HelpDocument }) {
  const details = document.operator_details;
  if (!details) {
    return null;
  }

  return (
    <section className="legal-document-details" aria-labelledby="operator-details">
      <h2 id="operator-details">Оператор</h2>
      <dl>
        <div>
          <dt>Наименование</dt>
          <dd>{details.name}</dd>
        </div>
        <div>
          <dt>ИНН</dt>
          <dd>{details.inn}</dd>
        </div>
        <div>
          <dt>ОГРН</dt>
          <dd>{details.ogrn}</dd>
        </div>
        <div>
          <dt>Адрес</dt>
          <dd>{details.address}</dd>
        </div>
        <div>
          <dt>Email</dt>
          <dd>
            <a href={`mailto:${details.email}`}>{details.email}</a>
          </dd>
        </div>
      </dl>
    </section>
  );
}

export function HelpDocumentPage({ slug }: { slug: string }) {
  const [document, setDocument] = useState<HelpDocument | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    void getHelpDocument(slug)
      .then((nextDocument) => {
        if (!cancelled) {
          setDocument(nextDocument);
        }
      })
      .catch((nextError) => {
        if (!cancelled) {
          setError(
            nextError instanceof Error ? nextError.message : "Не удалось загрузить документ",
          );
        }
      });

    return () => {
      cancelled = true;
    };
  }, [slug]);

  if (!document && !error) {
    return (
      <AppShell title="Справка" titleTag="p">
        <LoadingBlock />
      </AppShell>
    );
  }

  if (!document) {
    return (
      <AppShell title="Справка" titleTag="p">
        <main className="legal-document-page">
          <section className="legal-help-error">
            <h1>Документ не найден</h1>
            <p>{error ?? "Проверьте ссылку или вернитесь к списку документов."}</p>
            <Link href="/help" className="button button-primary">
              К списку документов
            </Link>
          </section>
        </main>
      </AppShell>
    );
  }

  return (
    <AppShell title="Справка" titleTag="p">
      <main className="legal-document-page">
        <nav className="legal-breadcrumbs" aria-label="Хлебные крошки">
          <Link href="/help">Справка</Link>
          <span aria-hidden="true">→</span>
          <span>{document.label}</span>
        </nav>

        <header className="legal-document-header">
          <div className="legal-document-title">
            <p className="eyebrow">Редакция от {document.updated_at}</p>
            <h1>{document.label}</h1>
            <p>{document.description || document.summary}</p>
            <dl className="legal-document-meta">
              <div>
                <dt>Дата редакции</dt>
                <dd>{document.revision}</dd>
              </div>
              <div>
                <dt>Статус</dt>
                <dd>{document.status}</dd>
              </div>
              <div>
                <dt>Оператор</dt>
                <dd>{document.operator}</dd>
              </div>
            </dl>
          </div>

          <div className="legal-document-actions">
            <a
              href={document.pdf_download_url}
              className="button button-primary"
              target="_blank"
              rel="noreferrer"
            >
              <Download className="button-icon" />
              <span>Скачать PDF</span>
            </a>
            <button type="button" className="button button-muted" onClick={() => window.print()}>
              <Printer className="button-icon" />
              <span>Распечатать</span>
            </button>
          </div>
        </header>

        <article className="legal-document-shell">
          {document.quick_facts?.length ? (
            <section className="legal-summary-box" aria-labelledby="legal-summary-title">
              <Info className="legal-summary-icon" />
              <div>
                <h2 id="legal-summary-title">Кратко</h2>
                <ul>
                  {document.quick_facts.map((fact) => (
                    <li key={fact.label}>
                      <strong>{fact.label}:</strong> {fact.value}
                    </li>
                  ))}
                </ul>
              </div>
            </section>
          ) : null}

          {document.table_of_contents?.length ? (
            <details className="legal-toc" open>
              <summary>Содержание</summary>
              <ol>
                {document.table_of_contents.map((item) => (
                  <li key={item.id}>
                    <a href={`#${item.id}`}>{item.title.replace(/^\d+\.\s*/, "")}</a>
                  </li>
                ))}
              </ol>
            </details>
          ) : null}

          <div className="legal-document-body">
            {document.sections.map((section) => (
              <section key={section.id} id={section.id}>
                <h2>{section.title}</h2>
                {section.paragraphs.map((paragraph) => (
                  <p key={paragraph}>{paragraph}</p>
                ))}
                <BulletList items={section.bullets} />
              </section>
            ))}
          </div>

          {document.withdrawal ? (
            <section className="legal-withdrawal">
              <h2>{document.withdrawal.title}</h2>
              <BulletList items={document.withdrawal.items} />
            </section>
          ) : null}

          <OperatorDetails document={document} />

          {document.archive_url ? (
            <p className="legal-archive-link">
              <a href={document.archive_url}>Архив редакций</a>
            </p>
          ) : null}
        </article>

        <section className="legal-document-contact">
          <div>
            <h2>Есть вопрос по документу?</h2>
            <p>Напишите нам, если нужно уточнить порядок применения документа.</p>
          </div>
          <a href={`mailto:${document.operator_details?.email ?? document.approval.contact}`} className="button button-primary">
            <Mail className="button-icon" />
            <span>Написать</span>
          </a>
        </section>
      </main>
    </AppShell>
  );
}
