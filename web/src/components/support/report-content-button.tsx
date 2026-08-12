"use client";

import { AlertTriangle, CheckCircle2, Flag } from "lucide-react";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { useAuth } from "@/components/providers/auth-provider";
import { Modal } from "@/components/ui/modal";
import { REPORT_REASON_OPTIONS } from "@/lib/support";
import type { SupportReport } from "@/lib/types";

type ReportReason =
  | "spam"
  | "abuse"
  | "misinformation"
  | "dangerous"
  | "copyright"
  | "other";

export function ReportContentButton({
  label = "Пожаловаться",
  targetLabel,
  buttonClassName = "button button-inline button-ghost",
  onSubmit,
}: {
  label?: string;
  targetLabel: string;
  buttonClassName?: string;
  onSubmit: (payload: { reason: ReportReason; details?: string }) => Promise<SupportReport>;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const { isAuthenticated, openAuthModal } = useAuth();
  const [isOpen, setIsOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [reason, setReason] = useState<ReportReason>("abuse");
  const [details, setDetails] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [createdReport, setCreatedReport] = useState<SupportReport | null>(null);

  useEffect(() => {
    if (!isOpen) {
      return;
    }

    setError(null);
  }, [isOpen]);

  const handleOpen = () => {
    if (!isAuthenticated) {
      openAuthModal({ returnTo: pathname || "/" });
      return;
    }

    setIsOpen(true);
    setError(null);
    setCreatedReport(null);
  };

  const handleClose = () => {
    if (busy) {
      return;
    }

    setIsOpen(false);
    setCreatedReport(null);
    setError(null);
  };

  const handleSubmit = async () => {
    setBusy(true);
    setError(null);

    try {
      const report = await onSubmit({
        reason,
        details: details.trim() || undefined,
      });
      setCreatedReport(report);
      setDetails("");
    } catch (nextError) {
      setError(
        nextError instanceof Error ? nextError.message : "Не удалось отправить жалобу",
      );
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="report-button-root">
      <button type="button" className={buttonClassName} onClick={handleOpen}>
        <Flag className="button-icon" />
        <span>{label}</span>
      </button>

      <Modal
        open={isOpen}
        onClose={handleClose}
        title="Жалоба"
        description={targetLabel}
      >
        {createdReport ? (
          <div className="report-modal-success">
            <div className="report-modal-success-copy">
              <CheckCircle2 className="button-icon" />
              <div>
                <strong>Жалоба отправлена</strong>
                <p className="muted">
                  Команда модерации увидит обращение и при необходимости продолжит диалог в
                  разделе поддержки.
                </p>
              </div>
            </div>

            <div className="report-modal-actions">
              <button
                type="button"
                className="button button-primary"
                onClick={() => {
                  setIsOpen(false);
                  router.push("/support");
                }}
              >
                Открыть поддержку
              </button>
              <button type="button" className="button button-muted" onClick={handleClose}>
                Закрыть
              </button>
            </div>
          </div>
        ) : (
          <div className="report-modal-body">
            <label className="field">
              <span>Причина</span>
              <select
                value={reason}
                onChange={(event) => setReason(event.target.value as ReportReason)}
              >
                {REPORT_REASON_OPTIONS.map((option) => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </label>

            <p className="muted report-modal-reason-help">
              {REPORT_REASON_OPTIONS.find((option) => option.value === reason)?.description}
            </p>

            <label className="field">
              <span>Комментарий</span>
              <textarea
                value={details}
                onChange={(event) => setDetails(event.target.value)}
                placeholder="Что именно не так и почему это нужно проверить"
              />
            </label>

            {error ? (
              <div className="form-banner is-error">
                <AlertTriangle className="button-icon" />
                <span>{error}</span>
              </div>
            ) : null}

            <div className="report-modal-actions">
              <button
                type="button"
                className="button button-primary"
                onClick={() => void handleSubmit()}
                disabled={busy}
              >
                {busy ? "Отправляю..." : "Отправить жалобу"}
              </button>
              <button
                type="button"
                className="button button-muted"
                onClick={handleClose}
                disabled={busy}
              >
                Отмена
              </button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
}
