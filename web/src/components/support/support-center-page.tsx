"use client";

import { usePathname, useRouter, useSearchParams } from "next/navigation";
import type { LucideIcon } from "lucide-react";
import {
  Archive,
  BookOpenText,
  CircleCheckBig,
  Flag,
  Inbox,
  LifeBuoy,
  LoaderCircle,
  MapPinned,
  MessageSquareMore,
  RefreshCcw,
  Search,
  SendHorizonal,
  ShieldCheck,
  Sparkles,
  SquarePen,
  Star,
  UserRound,
} from "lucide-react";
import {
  FormEvent,
  startTransition,
  useCallback,
  useDeferredValue,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";

import { AppShell } from "@/components/layout/app-shell";
import { useAuth } from "@/components/providers/auth-provider";
import { Avatar } from "@/components/ui/avatar";
import { EmptyState } from "@/components/ui/empty-state";
import { LoadingBlock } from "@/components/ui/loading-block";
import { Modal } from "@/components/ui/modal";
import {
  askSupportBot,
  createSupportThread,
  getSupportKnowledge,
  getSupportThread,
  listSupportTeamReports,
  listSupportTeamThreads,
  listSupportThreads,
  sendSupportMessage,
  updateSupportTeamReport,
  updateSupportTeamThread,
} from "@/lib/api";
import { formatDateTime } from "@/lib/format";
import {
  getRoleLabel,
  getSupportReportReasonLabel,
  getSupportReportStatusLabel,
  getSupportReportTargetLabel,
  getSupportThreadCategoryLabel,
  getSupportThreadStatusLabel,
  SUPPORT_REPORT_STATUS_OPTIONS,
  SUPPORT_THREAD_CATEGORY_OPTIONS,
  SUPPORT_THREAD_STATUS_OPTIONS,
} from "@/lib/support";
import type {
  SupportBotReplyResponse,
  SupportKnowledgeEntry,
  SupportKnowledgeResponse,
  SupportMessage,
  SupportReport,
  SupportThreadDetail,
  SupportThreadSummary,
} from "@/lib/types";

type Pane = "chats" | "reports" | "faq";
type ThreadFilter = "open" | "archive";
type ThreadCategory = SupportThreadSummary["category"];
type ThreadStatus = SupportThreadSummary["status"];
type ReportStatus = SupportReport["status"];
type HelpCategoryId = "all" | "Аккаунт" | "Карта" | "Отзывы" | "Прочее";
type SupportModeConfig = {
  pane: Pane;
  label: string;
  description: string;
  icon: LucideIcon;
  count?: number;
};

const EMPTY_KNOWLEDGE: SupportKnowledgeResponse = {
  featured: [],
  faq: [],
  suggested_prompts: [],
};

const HELP_CATEGORIES: {
  id: HelpCategoryId;
  title: string;
  description: string;
  icon: LucideIcon;
}[] = [
  {
    id: "Аккаунт",
    title: "Аккаунт",
    description: "Вход, профиль и доступ.",
    icon: UserRound,
  },
  {
    id: "Карта",
    title: "Карта",
    description: "Точки, адреса и геолокация.",
    icon: MapPinned,
  },
  {
    id: "Отзывы",
    title: "Отзывы",
    description: "Публикация, фото и оценки.",
    icon: Star,
  },
  {
    id: "Прочее",
    title: "Прочее",
    description: "Уведомления и другие вопросы.",
    icon: BookOpenText,
  },
];

function getShortAnswer(answer: string): string {
  const firstSentence = answer.split(/(?<=[.!?])\s+/u)[0] ?? answer;
  return firstSentence.length > 140
    ? `${firstSentence.slice(0, 137).trim()}...`
    : firstSentence;
}

function toSummary(thread: SupportThreadDetail): SupportThreadSummary {
  return {
    id: thread.id,
    subject: thread.subject,
    category: thread.category,
    status: thread.status,
    created_at: thread.created_at,
    updated_at: thread.updated_at,
    last_message_at: thread.last_message_at,
    last_message_preview: thread.last_message_preview,
    unread_count: thread.unread_count,
    created_by: thread.created_by,
    assigned_to: thread.assigned_to,
    report: thread.report,
  };
}

function upsertThread(
  items: SupportThreadSummary[],
  thread: SupportThreadSummary,
): SupportThreadSummary[] {
  const nextItems = [thread, ...items.filter((item) => item.id !== thread.id)];
  return [...nextItems].sort((left, right) => {
    const timeDiff =
      new Date(right.last_message_at).getTime() -
      new Date(left.last_message_at).getTime();
    if (timeDiff !== 0) {
      return timeDiff;
    }
    return right.id - left.id;
  });
}

function parseThreadId(value: string | null): number | null {
  if (!value) {
    return null;
  }

  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    return null;
  }

  return parsed;
}

function getMessageClassName(message: SupportMessage): string {
  if (message.sender_type === "support") {
    return "is-support";
  }
  if (message.sender_type === "bot") {
    return "is-bot";
  }
  if (message.sender_type === "system") {
    return "is-system";
  }
  return "";
}

function getConversationTitle(
  thread: SupportThreadSummary,
  canAccessSupport: boolean,
): string {
  if (canAccessSupport) {
    return thread.created_by.name || thread.created_by.username;
  }
  return thread.subject;
}

function getConversationSubtitle(
  thread: SupportThreadSummary,
  canAccessSupport: boolean,
): string {
  if (canAccessSupport) {
    return thread.subject;
  }
  if (thread.assigned_to) {
    return `Ведёт: ${thread.assigned_to.name || thread.assigned_to.username}`;
  }
  return "FAQ-бот и поддержка";
}

function isOutgoingMessage(
  message: SupportMessage,
  canAccessSupport: boolean,
): boolean {
  if (message.sender_type === "bot" || message.sender_type === "system") {
    return false;
  }
  return canAccessSupport
    ? message.sender_type === "support"
    : message.sender_type === "user";
}

function ConversationListRow({
  thread,
  active,
  canAccessSupport,
  onOpen,
}: {
  thread: SupportThreadSummary;
  active: boolean;
  canAccessSupport: boolean;
  onOpen: (threadId: number) => void;
}) {
  const person = canAccessSupport ? thread.created_by : thread.assigned_to ?? thread.created_by;

  return (
    <button
      type="button"
      className={`support-conversation-row ${active ? "is-active" : ""}`.trim()}
      onClick={() => onOpen(thread.id)}
    >
      <div className="support-conversation-avatar">
        {person ? (
          <Avatar
            user={{
              avatar_url: person.avatar_url,
              name: person.name,
              username: person.username,
            }}
            size="md"
          />
        ) : (
          <span className="support-conversation-avatar-fallback">
            <LifeBuoy className="button-icon" />
          </span>
        )}
      </div>

      <div className="support-conversation-copy">
        <div className="support-conversation-head">
          <strong>{getConversationTitle(thread, canAccessSupport)}</strong>
          <time dateTime={thread.last_message_at}>
            {new Intl.DateTimeFormat("ru-RU", {
              day: "2-digit",
              month: "2-digit",
              hour: "2-digit",
              minute: "2-digit",
            }).format(new Date(thread.last_message_at))}
          </time>
        </div>

        <p className="support-conversation-subtitle">
          {getConversationSubtitle(thread, canAccessSupport)}
        </p>
        <p className="support-conversation-preview">
          {thread.last_message_preview || "Пока без сообщений"}
        </p>

        <div className="support-conversation-meta">
          <span className="chip">{getSupportThreadStatusLabel(thread.status)}</span>
          <span className="chip">{getSupportThreadCategoryLabel(thread.category)}</span>
          {thread.report ? (
            <span className="chip">
              <Flag className="button-icon" />
              <span>{getSupportReportStatusLabel(thread.report.status)}</span>
            </span>
          ) : null}
        </div>
      </div>

      {thread.unread_count > 0 ? (
        <span className="support-conversation-unread">{thread.unread_count}</span>
      ) : null}
    </button>
  );
}

function ReportListRow({
  report,
  active,
  onOpen,
}: {
  report: SupportReport;
  active: boolean;
  onOpen: (reportId: number) => void;
}) {
  return (
    <button
      type="button"
      className={`support-report-row ${active ? "is-active" : ""}`.trim()}
      onClick={() => onOpen(report.id)}
    >
      <div className="support-report-row-head">
        <strong>{report.target_label}</strong>
        <span className="chip">{getSupportReportStatusLabel(report.status)}</span>
      </div>
      <p>
        {getSupportReportTargetLabel(report.target_type)} вЂў{" "}
        {getSupportReportReasonLabel(report.reason)}
      </p>
      <small>{formatDateTime(report.created_at)}</small>
    </button>
  );
}

function KnowledgeListRow({
  article,
  active,
  onOpen,
}: {
  article: SupportKnowledgeEntry;
  active: boolean;
  onOpen: (articleId: string) => void;
}) {
  return (
    <button
      type="button"
      className={`support-knowledge-row ${active ? "is-active" : ""}`.trim()}
      onClick={() => onOpen(article.id)}
    >
      <div className="support-knowledge-row-head">
        <strong>{article.title}</strong>
        {article.is_featured ? <span className="chip">FAQ</span> : null}
      </div>
      <p>{article.answer}</p>
    </button>
  );
}

function SupportModeButton({
  item,
  active,
  onSelect,
}: {
  item: SupportModeConfig;
  active: boolean;
  onSelect: (pane: Pane) => void;
}) {
  const Icon = item.icon;

  return (
    <button
      type="button"
      className={`support-mode-button ${active ? "is-active" : ""}`.trim()}
      onClick={() => onSelect(item.pane)}
    >
      <span className="support-mode-button-icon">
        <Icon className="button-icon" />
      </span>
      <strong>{item.label}</strong>
      {typeof item.count === "number" ? <small>{item.count}</small> : null}
    </button>
  );
}

export function SupportCenterPage() {
  const pathname = usePathname();
  const router = useRouter();
  const searchParams = useSearchParams();
  const { isAuthenticated, openAuthModal, user } = useAuth();
  const canAccessSupport = Boolean(user?.can_access_support);
  const threadIdFromQuery = parseThreadId(searchParams.get("thread"));
  const messageEndRef = useRef<HTMLDivElement | null>(null);

  const [activePane, setActivePane] = useState<Pane>("faq");
  const [threadFilter, setThreadFilter] = useState<ThreadFilter>("open");
  const [threadSearch, setThreadSearch] = useState("");
  const [faqSearch, setFaqSearch] = useState("");
  const [activeCategory, setActiveCategory] = useState<HelpCategoryId>("all");

  const [knowledge, setKnowledge] =
    useState<SupportKnowledgeResponse>(EMPTY_KNOWLEDGE);
  const [knowledgeLoading, setKnowledgeLoading] = useState(true);
  const [knowledgeError, setKnowledgeError] = useState<string | null>(null);
  const [selectedArticleId, setSelectedArticleId] = useState<string | null>(null);

  const [threads, setThreads] = useState<SupportThreadSummary[]>([]);
  const [threadsLoading, setThreadsLoading] = useState(false);
  const [threadsError, setThreadsError] = useState<string | null>(null);

  const [activeThreadId, setActiveThreadId] = useState<number | null>(null);
  const [activeThread, setActiveThread] = useState<SupportThreadDetail | null>(null);
  const [activeThreadLoading, setActiveThreadLoading] = useState(false);
  const [activeThreadError, setActiveThreadError] = useState<string | null>(null);

  const [threadModalOpen, setThreadModalOpen] = useState(false);
  const [threadCategory, setThreadCategory] = useState<ThreadCategory>("general");
  const [threadSubject, setThreadSubject] = useState("");
  const [threadBody, setThreadBody] = useState("");
  const [threadCreateBusy, setThreadCreateBusy] = useState(false);
  const [threadCreateError, setThreadCreateError] = useState<string | null>(null);

  const [messageBody, setMessageBody] = useState("");
  const [messageBusy, setMessageBusy] = useState(false);
  const [messageError, setMessageError] = useState<string | null>(null);

  const [botReply, setBotReply] = useState<SupportBotReplyResponse | null>(null);
  const [botBusy, setBotBusy] = useState(false);
  const [botError, setBotError] = useState<string | null>(null);

  const [reports, setReports] = useState<SupportReport[]>([]);
  const [reportsLoading, setReportsLoading] = useState(false);
  const [reportsError, setReportsError] = useState<string | null>(null);
  const [selectedReportId, setSelectedReportId] = useState<number | null>(null);
  const [reportStatusDraft, setReportStatusDraft] = useState<ReportStatus>("new");
  const [reportResolutionNote, setReportResolutionNote] = useState("");
  const [removeTarget, setRemoveTarget] = useState(false);
  const [reportBusy, setReportBusy] = useState(false);
  const [reportError, setReportError] = useState<string | null>(null);

  const deferredThreadSearch = useDeferredValue(threadSearch.trim().toLowerCase());
  const deferredFaqSearch = useDeferredValue(faqSearch.trim().toLowerCase());

  const openThreads = useMemo(
    () => threads.filter((item) => item.status !== "closed"),
    [threads],
  );
  const archivedThreads = useMemo(
    () => threads.filter((item) => item.status === "closed"),
    [threads],
  );
  const filteredThreads = useMemo(() => {
    const source = threadFilter === "archive" ? archivedThreads : openThreads;
    if (!deferredThreadSearch) {
      return source;
    }
    return source.filter((thread) => {
      const haystack = [
        thread.subject,
        thread.last_message_preview,
        thread.created_by.name,
        thread.created_by.username,
        thread.assigned_to?.name,
        thread.assigned_to?.username,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      return haystack.includes(deferredThreadSearch);
    });
  }, [archivedThreads, deferredThreadSearch, openThreads, threadFilter]);
  const filteredReports = useMemo(() => {
    if (!deferredThreadSearch) {
      return reports;
    }

    return reports.filter((report) => {
      const haystack = [
        report.target_label,
        report.reason,
        report.details,
        report.reporter.name,
        report.reporter.username,
      ]
        .join(" ")
        .toLowerCase();
      return haystack.includes(deferredThreadSearch);
    });
  }, [deferredThreadSearch, reports]);
  const unreadCount = useMemo(
    () => threads.reduce((sum, item) => sum + item.unread_count, 0),
    [threads],
  );
  const newReportsCount = useMemo(
    () => reports.filter((item) => item.status === "new").length,
    [reports],
  );

  const faqEntries = useMemo(() => {
    return knowledge.faq.filter((article) => {
      if (activeCategory !== "all" && article.category !== activeCategory) {
        return false;
      }
      if (!deferredFaqSearch) {
        return true;
      }
      const haystack = [
        article.title,
        article.answer,
        article.category,
        ...article.keywords,
      ]
        .join(" ")
        .toLowerCase();
      return haystack.includes(deferredFaqSearch);
    });
  }, [activeCategory, deferredFaqSearch, knowledge.faq]);

  const selectedArticle = useMemo(() => {
    if (selectedArticleId) {
      const match = knowledge.faq.find((article) => article.id === selectedArticleId);
      if (match) {
        return match;
      }
    }
    return knowledge.featured[0] ?? knowledge.faq[0] ?? null;
  }, [knowledge.faq, knowledge.featured, selectedArticleId]);
  const visibleArticle = useMemo(() => {
    if (selectedArticle && faqEntries.some((article) => article.id === selectedArticle.id)) {
      return selectedArticle;
    }
    return faqEntries[0] ?? null;
  }, [faqEntries, selectedArticle]);

  const selectedReport = useMemo(
    () => reports.find((item) => item.id === selectedReportId) ?? null,
    [reports, selectedReportId],
  );

  const activeConversation = useMemo(() => {
    if (!activeThread) {
      return null;
    }
    return canAccessSupport
      ? activeThread.created_by
      : activeThread.assigned_to ?? activeThread.created_by;
  }, [activeThread, canAccessSupport]);

  const syncThreadQuery = useCallback(
    (threadId: number | null) => {
      const params = new URLSearchParams(searchParams.toString());
      if (threadId) {
        params.set("thread", String(threadId));
      } else {
        params.delete("thread");
      }
      const nextUrl = params.size ? `${pathname}?${params.toString()}` : pathname;
      router.replace(nextUrl, { scroll: false });
    },
    [pathname, router, searchParams],
  );

  const selectThread = useCallback(
    (threadId: number | null) => {
      startTransition(() => {
        setActivePane("chats");
        setActiveThreadId(threadId);
      });
      syncThreadQuery(threadId);
    },
    [syncThreadQuery],
  );

  const loadKnowledge = useCallback(async () => {
    setKnowledgeLoading(true);
    setKnowledgeError(null);
    try {
      const nextKnowledge = await getSupportKnowledge();
      setKnowledge(nextKnowledge);
      setSelectedArticleId((current) => current ?? nextKnowledge.featured[0]?.id ?? null);
    } catch (error) {
      setKnowledgeError(
        error instanceof Error ? error.message : "Не удалось загрузить FAQ.",
      );
    } finally {
      setKnowledgeLoading(false);
    }
  }, []);

  const loadThreads = useCallback(
    async (showLoading = true) => {
      if (!isAuthenticated) {
        setThreads([]);
        setThreadsError(null);
        setThreadsLoading(false);
        return;
      }

      if (showLoading) {
        setThreadsLoading(true);
      }
      setThreadsError(null);

      try {
        setThreads(
          canAccessSupport ? await listSupportTeamThreads() : await listSupportThreads(),
        );
      } catch (error) {
        setThreadsError(
          error instanceof Error
            ? error.message
            : "Не удалось загрузить список чатов.",
        );
      } finally {
        if (showLoading) {
          setThreadsLoading(false);
        }
      }
    },
    [canAccessSupport, isAuthenticated],
  );

  const loadReports = useCallback(
    async (showLoading = true) => {
      if (!isAuthenticated || !canAccessSupport) {
        setReports([]);
        setReportsError(null);
        setReportsLoading(false);
        return;
      }

      if (showLoading) {
        setReportsLoading(true);
      }
      setReportsError(null);

      try {
        setReports(await listSupportTeamReports());
      } catch (error) {
        setReportsError(
          error instanceof Error
            ? error.message
            : "Не удалось загрузить очередь жалоб.",
        );
      } finally {
        if (showLoading) {
          setReportsLoading(false);
        }
      }
    },
    [canAccessSupport, isAuthenticated],
  );

  const loadThreadDetail = useCallback(
    async (threadId: number, showLoading = true) => {
      if (showLoading) {
        setActiveThreadLoading(true);
      }
      setActiveThreadError(null);

      try {
        const detail = await getSupportThread(threadId);
        setActiveThread(detail);
        setThreads((current) =>
          current.map((item) =>
            item.id === threadId
              ? {
                  ...item,
                  unread_count: 0,
                  status: detail.status,
                  assigned_to: detail.assigned_to,
                  last_message_at: detail.last_message_at,
                  last_message_preview: detail.last_message_preview,
                }
              : item,
          ),
        );
      } catch (error) {
        setActiveThreadError(
          error instanceof Error
            ? error.message
            : "Не удалось открыть выбранный чат.",
        );
      } finally {
        if (showLoading) {
          setActiveThreadLoading(false);
        }
      }
    },
    [],
  );

  const refreshAll = useCallback(async () => {
    await Promise.all([
      loadKnowledge(),
      loadThreads(false),
      loadReports(false),
      activeThreadId ? loadThreadDetail(activeThreadId, false) : Promise.resolve(),
    ]);
  }, [activeThreadId, loadKnowledge, loadReports, loadThreadDetail, loadThreads]);

  useEffect(() => {
    void loadKnowledge();
  }, [loadKnowledge]);

  useEffect(() => {
    void loadThreads();
    void loadReports();
  }, [loadReports, loadThreads]);

  useEffect(() => {
    if (!threads.length) {
      if (activeThreadId !== null) {
        setActiveThreadId(null);
        setActiveThread(null);
      }
      return;
    }

    const localThreadId =
      activeThreadId && threads.some((item) => item.id === activeThreadId)
        ? activeThreadId
        : null;
    const queryThreadId =
      threadIdFromQuery && threads.some((item) => item.id === threadIdFromQuery)
        ? threadIdFromQuery
        : null;
    const fallbackThreadId =
      openThreads[0]?.id ?? archivedThreads[0]?.id ?? null;
    const nextThreadId = localThreadId ?? queryThreadId ?? fallbackThreadId;

    if (nextThreadId !== activeThreadId) {
      setActiveThreadId(nextThreadId);
    }

    if (queryThreadId === null && nextThreadId !== threadIdFromQuery) {
      syncThreadQuery(nextThreadId);
    }
  }, [
    activeThreadId,
    archivedThreads,
    openThreads,
    syncThreadQuery,
    threadIdFromQuery,
    threads,
  ]);

  useEffect(() => {
    if (!activeThreadId) {
      setActiveThread(null);
      return;
    }
    void loadThreadDetail(activeThreadId);
  }, [activeThreadId, loadThreadDetail]);

  useEffect(() => {
    if (!isAuthenticated) {
      return;
    }

    const timer = window.setInterval(() => {
      if (document.visibilityState === "hidden") {
        return;
      }
      void loadThreads(false);
      void loadReports(false);
      if (activeThreadId) {
        void loadThreadDetail(activeThreadId, false);
      }
    }, activeThreadId ? 2500 : 7000);

    return () => window.clearInterval(timer);
  }, [activeThreadId, isAuthenticated, loadReports, loadThreadDetail, loadThreads]);

  useEffect(() => {
    if (!reports.length) {
      setSelectedReportId(null);
      return;
    }
    if (selectedReportId && reports.some((item) => item.id === selectedReportId)) {
      return;
    }
    setSelectedReportId(reports[0].id);
  }, [reports, selectedReportId]);

  useEffect(() => {
    if (!selectedReport) {
      return;
    }
    setReportStatusDraft(selectedReport.status);
    setReportResolutionNote(selectedReport.resolution_note);
    setRemoveTarget(false);
    setReportError(null);
  }, [selectedReport]);

  useEffect(() => {
    setMessageBody("");
    setMessageError(null);
    setBotReply(null);
    setBotError(null);
  }, [activeThreadId]);

  useEffect(() => {
    messageEndRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [activeThread?.id, activeThread?.messages.length]);

  const openThreadComposer = () => {
    if (!isAuthenticated) {
      openAuthModal({ returnTo: pathname });
      return;
    }
    setThreadCreateError(null);
    setBotReply(null);
    setBotError(null);
    setThreadModalOpen(true);
  };

  const handleCreateThread = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!isAuthenticated) {
      openAuthModal({ returnTo: pathname });
      return;
    }

    setThreadCreateBusy(true);
    setThreadCreateError(null);

    try {
      const created = await createSupportThread({
        category: threadCategory,
        subject: threadSubject.trim(),
        body: threadBody.trim(),
      });

      setThreadCategory("general");
      setThreadSubject("");
      setThreadBody("");
      setThreadModalOpen(false);
      setBotReply(null);
      setActiveThread(created);
      setThreads((current) => upsertThread(current, toSummary(created)));
      selectThread(created.id);
    } catch (error) {
      setThreadCreateError(
        error instanceof Error ? error.message : "Не удалось создать обращение.",
      );
    } finally {
      setThreadCreateBusy(false);
    }
  };

  const handleSendMessage = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!activeThreadId || !messageBody.trim()) {
      return;
    }

    setMessageBusy(true);
    setMessageError(null);

    try {
      await sendSupportMessage(activeThreadId, messageBody.trim());
      setMessageBody("");
      setBotReply(null);
      await Promise.all([loadThreads(false), loadThreadDetail(activeThreadId, false)]);
    } catch (error) {
      setMessageError(
        error instanceof Error ? error.message : "Не удалось отправить сообщение.",
      );
    } finally {
      setMessageBusy(false);
    }
  };

  const handleAskBot = async (query: string) => {
    if (!query.trim()) {
      setBotError("Сначала опишите вопрос.");
      return;
    }

    setBotBusy(true);
    setBotError(null);

    try {
      setBotReply(await askSupportBot(query.trim()));
    } catch (error) {
      setBotError(
        error instanceof Error ? error.message : "Не удалось получить ответ.",
      );
    } finally {
      setBotBusy(false);
    }
  };

  const handleAssignToSelf = async () => {
    if (!activeThread || !user) {
      return;
    }

    setActiveThreadLoading(true);
    setActiveThreadError(null);

    try {
      const detail = await updateSupportTeamThread(activeThread.id, {
        assigned_to_id: user.id,
      });
      setActiveThread(detail);
      setThreads((current) => upsertThread(current, toSummary(detail)));
    } catch (error) {
      setActiveThreadError(
        error instanceof Error ? error.message : "Не удалось назначить чат.",
      );
    } finally {
      setActiveThreadLoading(false);
    }
  };

  const handleThreadStatusChange = async (nextStatus: ThreadStatus) => {
    if (!activeThread) {
      return;
    }

    setActiveThreadLoading(true);
    setActiveThreadError(null);

    try {
      const detail = await updateSupportTeamThread(activeThread.id, {
        status: nextStatus,
      });
      setActiveThread(detail);
      setThreads((current) => upsertThread(current, toSummary(detail)));
      if (detail.status === "closed") {
        setThreadFilter("archive");
      }
    } catch (error) {
      setActiveThreadError(
        error instanceof Error ? error.message : "Не удалось обновить статус.",
      );
    } finally {
      setActiveThreadLoading(false);
    }
  };

  const handleReportUpdate = async () => {
    if (!selectedReport) {
      return;
    }

    setReportBusy(true);
    setReportError(null);

    try {
      const updated = await updateSupportTeamReport(selectedReport.id, {
        status: reportStatusDraft,
        resolution_note: reportResolutionNote.trim() || undefined,
        remove_target: removeTarget,
      });

      setReports((current) =>
        current.map((item) => (item.id === updated.id ? updated : item)),
      );

      if (updated.thread_id) {
        selectThread(updated.thread_id);
      }

      await Promise.all([loadThreads(false), loadReports(false)]);
    } catch (error) {
      setReportError(
        error instanceof Error
          ? error.message
          : "Не удалось сохранить решение по жалобе.",
      );
    } finally {
      setReportBusy(false);
    }
  };

  const prefillThreadFromArticle = useCallback(
    (title: string, answer?: string) => {
      if (!isAuthenticated) {
        openAuthModal({ returnTo: pathname });
        return;
      }

      setThreadModalOpen(true);
      setThreadCategory("general");
      setThreadSubject(title);
      setThreadBody(
        answer
          ? `Не помогла статья «${title}».\n\nЧто уже проверил:\n${answer}\n\nЧто именно не работает:`
          : `Не помогла статья «${title}».\n\nЧто именно не работает:`,
      );
    },
    [isAuthenticated, openAuthModal, pathname],
  );
  const mainPaneTitle =
    activePane === "reports"
      ? "Очередь жалоб"
      : activePane === "faq"
        ? "Статьи"
        : activeThread
          ? activeThread.subject
          : "Мои обращения";
  const supportModes = useMemo<SupportModeConfig[]>(
    () =>
      canAccessSupport
        ? [
            {
              pane: "chats",
              label: "Диалоги",
              description: "Живые обращения, новые сообщения и архив переписки.",
              icon: MessageSquareMore,
              count: unreadCount,
            },
            {
              pane: "reports",
              label: "Жалобы",
              description: "Очередь модерации, связанный диалог и принятое решение.",
              icon: Flag,
              count: newReportsCount,
            },
            {
              pane: "faq",
              label: "FAQ",
              description: "Статьи, подсказки и типовые сценарии для быстрых ответов.",
              icon: BookOpenText,
              count: knowledge.faq.length,
            },
          ]
        : [
            {
              pane: "faq",
              label: "FAQ",
              description: "Сначала проверьте FAQ и готовые инструкции по частым вопросам.",
              icon: BookOpenText,
              count: knowledge.faq.length,
            },
            {
              pane: "chats",
              label: "Чаты",
              description: "История личных диалогов с поддержкой и статус каждого чата.",
              icon: MessageSquareMore,
              count: openThreads.length,
            },
          ],
    [canAccessSupport, knowledge.faq.length, newReportsCount, openThreads.length, unreadCount],
  );
  const activeMode = useMemo(
    () => supportModes.find((item) => item.pane === activePane) ?? supportModes[0],
    [activePane, supportModes],
  );
  const sidebarDescription = canAccessSupport
    ? "Операционный режим: разберите очередь, откройте диалог и зафиксируйте решение без переключений по разделам."
    : "Ответы на вопросы и поддержка пользователей";
  const stageDescription =
    activePane === "reports"
      ? "Сначала выберите кейс, затем примите решение и при необходимости откройте связанный диалог."
      : activePane === "faq"
        ? "Сначала найдите ответ в статье. Если не помогло, напишите в поддержку."
        : isAuthenticated
          ? "Вся переписка, статус обращения и ответ собраны в одном окне без лишней навигации."
          : "Личный чат появится после входа, а база знаний доступна сразу.";
  const threadSearchPlaceholder = canAccessSupport
    ? "Тема, пользователь или последнее сообщение"
    : "Тема обращения или последнее сообщение";
  const reportSearchPlaceholder = "Причина, объект или пользователь";
  const faqSearchPlaceholder = "Опишите проблему или вопрос";

  return (
    <AppShell
      title="Помощь"
      contentClassName="support-page-content"
      shellContentClassName="shell-content-locked"
      actions={
        <button
          type="button"
          className="button button-muted"
          onClick={() => void refreshAll()}
        >
          <RefreshCcw className="button-icon" />
          <span>Обновить</span>
        </button>
      }
      >
        <section className="support-messenger-shell">
          <aside className="support-messenger-sidebar">
            {canAccessSupport ? (
              <>
                <div className="support-messenger-sidebar-head">
                  <div>
                    <p className="eyebrow">Support workspace</p>
                    <h2>Очередь</h2>
                  </div>
                </div>

                <p className="support-messenger-sidebar-note">{sidebarDescription}</p>

                <div className="support-mode-menu" aria-label="Режимы поддержки">
                  {supportModes.map((item) => (
                    <SupportModeButton
                      key={item.pane}
                      item={item}
                      active={item.pane === activePane}
                      onSelect={setActivePane}
                    />
                  ))}
                </div>
              </>
            ) : activePane === "faq" ? (
              <>
                <div className="support-messenger-sidebar-head support-help-heading">
                  <div>
                    <h2>Помощь</h2>
                    <p>{sidebarDescription}</p>
                  </div>
                </div>

                <label className="support-search-field support-search-field-large">
                  <Search className="button-icon" />
                  <input
                    value={faqSearch}
                    onChange={(event) => setFaqSearch(event.target.value)}
                    placeholder={faqSearchPlaceholder}
                  />
                </label>

                <button
                  type="button"
                  className="button button-primary support-main-cta"
                  onClick={openThreadComposer}
                >
                  <SquarePen className="button-icon" />
                  <span>Написать в поддержку</span>
                </button>

                <div className="support-category-grid" aria-label="Категории помощи">
                  {HELP_CATEGORIES.map((category) => {
                    const Icon = category.icon;
                    return (
                      <button
                        key={category.id}
                        type="button"
                        className={`support-category-card ${
                          activeCategory === category.id ? "is-active" : ""
                        }`.trim()}
                        onClick={() => {
                          setActiveCategory(category.id);
                          setSelectedArticleId(null);
                        }}
                      >
                        <span className="support-category-icon">
                          <Icon className="button-icon" />
                        </span>
                        <span>
                          <strong>{category.title}</strong>
                          <small>{category.description}</small>
                        </span>
                      </button>
                    );
                  })}
                </div>

                <button
                  type="button"
                  className="button button-muted support-my-requests-button"
                  onClick={() =>
                    isAuthenticated
                      ? setActivePane("chats")
                      : openAuthModal({ returnTo: pathname })
                  }
                >
                  <MessageSquareMore className="button-icon" />
                  <span>Мои обращения</span>
                </button>
              </>
            ) : (
              <>
                <div className="support-messenger-sidebar-head">
                  <div>
                    <p className="eyebrow">Поддержка</p>
                    <h2>Мои обращения</h2>
                  </div>

                  <button
                    type="button"
                    className="button button-muted button-inline"
                    onClick={() => setActivePane("faq")}
                  >
                    <BookOpenText className="button-icon" />
                    <span>Помощь</span>
                  </button>
                </div>

                <button
                  type="button"
                  className="button button-primary support-main-cta"
                  onClick={openThreadComposer}
                >
                  <SquarePen className="button-icon" />
                  <span>Написать в поддержку</span>
                </button>
              </>
            )}

          {activePane === "chats" ? (
            <>
              <div className="support-messenger-toolbar">
                <div className="support-messenger-segment">
                  <button
                    type="button"
                    className={`support-messenger-segment-button ${threadFilter === "open" ? "is-active" : ""}`.trim()}
                    onClick={() => setThreadFilter("open")}
                  >
                    <Inbox className="button-icon" />
                    <span>Активные</span>
                  </button>
                  <button
                    type="button"
                    className={`support-messenger-segment-button ${threadFilter === "archive" ? "is-active" : ""}`.trim()}
                    onClick={() => setThreadFilter("archive")}
                  >
                    <Archive className="button-icon" />
                    <span>Архив</span>
                  </button>
                </div>

                <label className="support-search-field">
                  <Search className="button-icon" />
                  <input
                    value={threadSearch}
                    onChange={(event) => setThreadSearch(event.target.value)}
                    placeholder={threadSearchPlaceholder}
                  />
                </label>
              </div>

              {!isAuthenticated ? (
                <EmptyState
                  title="Войдите, чтобы открыть чат"
                  description="FAQ доступен и без входа, но личные обращения появляются только после авторизации."
                  action={
                    <button
                      type="button"
                      className="button button-primary"
                      onClick={() => openAuthModal({ returnTo: pathname })}
                    >
                      Войти
                    </button>
                  }
                />
              ) : threadsLoading && !threads.length ? (
                <LoadingBlock label="Загружаю чаты..." />
              ) : (
                <>
                  {threadsError ? <div className="form-banner is-error">{threadsError}</div> : null}

                  <div className="support-conversation-list">
                    {filteredThreads.map((thread) => (
                      <ConversationListRow
                        key={thread.id}
                        thread={thread}
                        active={thread.id === activeThreadId}
                        canAccessSupport={canAccessSupport}
                        onOpen={selectThread}
                      />
                    ))}
                  </div>

                  {!filteredThreads.length ? (
                    <EmptyState
                      title={
                        threadFilter === "archive"
                          ? "Архив пуст"
                          : "Подходящих диалогов нет"
                      }
                      description={
                        threadFilter === "archive"
                          ? "Закрытые треды появятся здесь."
                          : deferredThreadSearch
                            ? "Попробуйте другой запрос."
                            : canAccessSupport
                              ? "Новые обращения появятся автоматически."
                              : "У вас пока нет обращений. Попробуйте найти ответ или напишите нам."
                      }
                      action={
                        !canAccessSupport && threadFilter !== "archive" ? (
                          <button
                            type="button"
                            className="button button-primary"
                            onClick={openThreadComposer}
                          >
                            Написать в поддержку
                          </button>
                        ) : undefined
                      }
                    />
                  ) : null}
                </>
              )}
            </>
          ) : null}

          {activePane === "reports" && canAccessSupport ? (
            <>
              <label className="support-search-field">
                <Search className="button-icon" />
                <input
                  value={threadSearch}
                  onChange={(event) => setThreadSearch(event.target.value)}
                  placeholder={reportSearchPlaceholder}
                />
              </label>

              {reportsLoading && !reports.length ? (
                <LoadingBlock label="Загружаю жалобы..." />
              ) : (
                <>
                  {reportsError ? <div className="form-banner is-error">{reportsError}</div> : null}

                  <div className="support-report-list">
                    {filteredReports.map((report) => (
                      <ReportListRow
                        key={report.id}
                        report={report}
                        active={report.id === selectedReportId}
                        onOpen={setSelectedReportId}
                      />
                    ))}
                  </div>

                  {!filteredReports.length ? (
                    <EmptyState
                      title={
                        deferredThreadSearch ? "Ничего не найдено" : "Жалоб пока нет"
                      }
                      description={
                        deferredThreadSearch
                          ? "Попробуйте другой запрос по жалобам."
                          : "Новые кейсы модерации появятся здесь."
                      }
                    />
                  ) : null}
                </>
              )}
            </>
          ) : null}

          {activePane === "faq" && canAccessSupport ? (
            <>
              <label className="support-search-field">
                <Search className="button-icon" />
                <input
                  value={faqSearch}
                  onChange={(event) => setFaqSearch(event.target.value)}
                  placeholder={faqSearchPlaceholder}
                />
              </label>

              {knowledgeLoading && !knowledge.faq.length ? (
                <LoadingBlock label="Загружаю FAQ..." />
              ) : (
                <>
                  {knowledgeError ? <div className="form-banner is-error">{knowledgeError}</div> : null}

                  <div className="support-knowledge-list">
                    {faqEntries.map((article) => (
                      <KnowledgeListRow
                        key={article.id}
                        article={article}
                        active={article.id === selectedArticle?.id}
                        onOpen={setSelectedArticleId}
                      />
                    ))}
                  </div>
                </>
              )}
            </>
          ) : null}
        </aside>
        <section className="support-messenger-stage">
          <div className="support-messenger-stage-head">
            <div>
              <p className="eyebrow">
                {activePane === "faq" && !canAccessSupport
                  ? "База знаний"
                  : activeMode.label}
              </p>
              <h3>{mainPaneTitle}</h3>
            </div>

            {activePane === "chats" && activeThread ? (
              <div className="support-chat-head-chips">
                <span className="chip">{getSupportThreadStatusLabel(activeThread.status)}</span>
                <span className="chip">
                  {getSupportThreadCategoryLabel(activeThread.category)}
                </span>
                {activeThread.report ? (
                  <span className="chip">
                    <Flag className="button-icon" />
                    <span>{getSupportReportStatusLabel(activeThread.report.status)}</span>
                  </span>
                ) : null}
              </div>
            ) : null}
          </div>

          <div className="support-stage-toolbar">
            <p className="support-stage-note">{stageDescription}</p>
            <div className="support-stage-intro-meta">
              {activePane === "faq" && canAccessSupport ? (
                <>
                  <span className="chip">Статей: {knowledge.faq.length}</span>
                  <span className="chip">Подборок: {knowledge.featured.length}</span>
                </>
              ) : null}
              {activePane === "reports" ? (
                <>
                  <span className="chip">Всего: {reports.length}</span>
                  <span className="chip">
                    Новые: {reports.filter((item) => item.status === "new").length}
                  </span>
                </>
              ) : null}
              {activePane === "chats" && canAccessSupport ? (
                <>
                  <span className="chip">Открытых: {openThreads.length}</span>
                  <span className="chip">Архив: {archivedThreads.length}</span>
                </>
              ) : null}
            </div>
          </div>

          {activePane === "faq" ? (
            <div className="support-faq-workspace">
              {knowledgeLoading && !knowledge.faq.length ? (
                <LoadingBlock label="Загружаю статьи..." />
              ) : (
                <>
                  {knowledgeError ? (
                    <div className="form-banner is-error">{knowledgeError}</div>
                  ) : null}

                  <section className="support-articles-panel">
                    {faqEntries.map((article) => (
                      <article key={article.id} className="support-article-card">
                        <div>
                          <p className="eyebrow">{article.category}</p>
                          <h4>{article.title}</h4>
                          <p>{getShortAnswer(article.answer)}</p>
                        </div>
                        <button
                          type="button"
                          className="button button-muted button-inline"
                          onClick={() => setSelectedArticleId(article.id)}
                        >
                          Открыть
                        </button>
                      </article>
                    ))}
                  </section>

                  {!faqEntries.length ? (
                    <EmptyState
                      title="Ничего не найдено"
                      description="Попробуйте другой запрос или напишите в поддержку."
                      action={
                        <button
                          type="button"
                          className="button button-primary"
                          onClick={openThreadComposer}
                        >
                          Написать в поддержку
                        </button>
                      }
                    />
                  ) : null}

                  {visibleArticle ? (
                    <section className="support-faq-article panel">
                      <div className="support-faq-article-head">
                        <div>
                          <p className="eyebrow">{visibleArticle.category}</p>
                          <h4>{visibleArticle.title}</h4>
                        </div>
                      </div>

                      <p className="support-faq-article-body">{visibleArticle.answer}</p>

                      {!canAccessSupport ? (
                        <button
                          type="button"
                          className="button button-primary button-inline"
                          onClick={() =>
                            prefillThreadFromArticle(
                              visibleArticle.title,
                              visibleArticle.answer,
                            )
                          }
                        >
                          <LifeBuoy className="button-icon" />
                          <span>Не помогло? Написать в поддержку</span>
                        </button>
                      ) : null}
                    </section>
                  ) : null}
                </>
              )}
            </div>
          ) : null}

          {activePane === "reports" && canAccessSupport ? (
            selectedReport ? (
              <div className="support-report-workspace">
                <section className="panel support-report-detail-card">
                  <div className="section-row">
                    <div>
                      <p className="eyebrow">Выбранная жалоба</p>
                      <h4>{selectedReport.target_label}</h4>
                    </div>

                    {selectedReport.thread_id ? (
                      <button
                        type="button"
                        className="button button-muted button-inline"
                        onClick={() => selectThread(selectedReport.thread_id)}
                      >
                        <Inbox className="button-icon" />
                        <span>Открыть диалог</span>
                      </button>
                    ) : null}
                  </div>

                  <div className="support-report-meta">
                    <span className="chip">
                      <Flag className="button-icon" />
                      <span>{getSupportReportTargetLabel(selectedReport.target_type)}</span>
                    </span>
                    <span className="chip">
                      <ShieldCheck className="button-icon" />
                      <span>{getSupportReportReasonLabel(selectedReport.reason)}</span>
                    </span>
                    <span className="chip">
                      <UserRound className="button-icon" />
                      <span>
                        {selectedReport.reporter.name || selectedReport.reporter.username}
                      </span>
                    </span>
                  </div>

                  {selectedReport.details ? (
                    <div className="support-report-note">
                      <strong>Комментарий пользователя</strong>
                      <p>{selectedReport.details}</p>
                    </div>
                  ) : null}
                </section>

                <section className="panel support-report-editor">
                  <label className="field">
                    <span>Статус</span>
                    <select
                      value={reportStatusDraft}
                      onChange={(event) =>
                        setReportStatusDraft(event.target.value as ReportStatus)
                      }
                    >
                      {SUPPORT_REPORT_STATUS_OPTIONS.map((option) => (
                        <option key={option.value} value={option.value}>
                          {option.label}
                        </option>
                      ))}
                    </select>
                  </label>

                  <label className="field">
                    <span>Решение или комментарий</span>
                    <textarea
                      value={reportResolutionNote}
                      onChange={(event) => setReportResolutionNote(event.target.value)}
                      placeholder="Что проверили и какое решение приняли."
                    />
                  </label>

                  <label className="toggle-checkbox">
                    <input
                      type="checkbox"
                      checked={removeTarget}
                      onChange={(event) => setRemoveTarget(event.target.checked)}
                    />
                    <span>Удалить контент вместе с применением решения</span>
                  </label>

                  {reportError ? <div className="form-banner is-error">{reportError}</div> : null}

                  <button
                    type="button"
                    className="button button-primary"
                    onClick={() => void handleReportUpdate()}
                    disabled={reportBusy}
                  >
                    {reportBusy ? (
                      <LoaderCircle className="button-icon support-spin" />
                    ) : (
                      <ShieldCheck className="button-icon" />
                    )}
                    <span>{reportBusy ? "Сохраняю..." : "Применить решение"}</span>
                  </button>
                </section>
              </div>
            ) : (
              <EmptyState
                title="Выберите жалобу"
                description="Детали модерации и связанный диалог будут показаны здесь."
              />
            )
          ) : null}
          {activePane === "chats" ? (
            !isAuthenticated ? (
              <EmptyState
                title="Нужен вход в аккаунт"
                description="После входа можно открыть чат, следить за ответами и историей обращений."
                action={
                  <button
                    type="button"
                    className="button button-primary"
                    onClick={() => openAuthModal({ returnTo: pathname })}
                  >
                    Войти
                  </button>
                }
              />
            ) : activeThreadLoading && !activeThread ? (
              <LoadingBlock label="Открываю чат..." />
            ) : activeThread ? (
              <div className="support-chat-workspace">
                <header className="support-chat-header">
                  <div className="support-chat-partner">
                    {activeConversation ? (
                      <Avatar
                        user={{
                            avatar_url: activeConversation.avatar_url,
                            name: activeConversation.name,
                            username: activeConversation.username,
                          }}
                        size="md"
                      />
                    ) : (
                      <span className="support-conversation-avatar-fallback is-large">
                        <LifeBuoy className="button-icon" />
                      </span>
                    )}

                    <div className="support-chat-partner-copy">
                      <strong>
                        {activeConversation
                          ? activeConversation.name || activeConversation.username
                          : "Поддержка"}
                      </strong>
                      <p>
                        {canAccessSupport
                          ? activeThread.subject
                          : activeThread.assigned_to
                            ? `Диалог ведёт ${activeThread.assigned_to.name || activeThread.assigned_to.username}`
                            : "FAQ-бот отвечает на типовые вопросы, пока оператор не подключился."}
                      </p>

                      {canAccessSupport ? (
                        <div className="support-chat-partner-meta">
                          <span className="chip">
                            Пользователь:{" "}
                            {activeThread.created_by.name || activeThread.created_by.username}
                          </span>
                          <span className="chip">
                            Ответственный:{" "}
                            {activeThread.assigned_to
                              ? activeThread.assigned_to.name ||
                                activeThread.assigned_to.username
                              : "не назначен"}
                          </span>
                        </div>
                      ) : null}
                    </div>
                  </div>

                  {canAccessSupport ? (
                    <div className="support-thread-adminbar-actions">
                      <label className="field support-inline-field">
                        <span>Статус</span>
                        <select
                          value={activeThread.status}
                          onChange={(event) =>
                            void handleThreadStatusChange(
                              event.target.value as ThreadStatus,
                            )
                          }
                          disabled={activeThreadLoading}
                        >
                          {SUPPORT_THREAD_STATUS_OPTIONS.map((option) => (
                            <option key={option.value} value={option.value}>
                              {option.label}
                            </option>
                          ))}
                        </select>
                      </label>

                      {user && activeThread.assigned_to?.id !== user.id ? (
                        <button
                          type="button"
                          className="button button-muted button-inline"
                          onClick={() => void handleAssignToSelf()}
                          disabled={activeThreadLoading}
                        >
                          <ShieldCheck className="button-icon" />
                          <span>Забрать себе</span>
                        </button>
                      ) : null}
                    </div>
                  ) : null}
                </header>

                <div className="support-chat-main">
                  {activeThreadError ? (
                    <div className="form-banner is-error">{activeThreadError}</div>
                  ) : null}

                  {activeThread.status === "closed" ? (
                    <div className="support-chat-status-banner">
                      <strong>Чат закрыт и перенесён в архив.</strong>
                      <span>Новые сообщения в этот тред больше отправить нельзя.</span>
                    </div>
                  ) : null}

                  {!canAccessSupport &&
                  activeThread.category !== "report" &&
                  activeThread.status !== "closed" ? (
                    <div className="support-inline-bot">
                      <div className="support-inline-bot-copy">
                        <strong>FAQ-бот в этом диалоге</strong>
                        <p>
                          Пока оператор не ответил, бот может подсказать решение по
                          типовым вопросам.
                        </p>
                      </div>

                      <div className="support-inline-bot-actions">
                        {knowledge.suggested_prompts.map((prompt) => (
                          <button
                            key={prompt}
                            type="button"
                            className="chip support-prompt-chip"
                            onClick={() => void handleAskBot(prompt)}
                          >
                            {prompt}
                          </button>
                        ))}

                        <button
                          type="button"
                          className="button button-muted button-inline"
                          onClick={() => void handleAskBot(messageBody.trim())}
                          disabled={botBusy}
                        >
                          <Sparkles className="button-icon" />
                          <span>{botBusy ? "Ищу..." : "Проверить вопрос"}</span>
                        </button>
                      </div>

                      {botError ? <div className="form-banner is-error">{botError}</div> : null}

                      {botReply ? (
                        <div className="support-bot-result">
                          <div className="support-bot-result-head">
                            <CircleCheckBig className="button-icon" />
                            <strong>Подсказка FAQ-бота</strong>
                          </div>
                          <p>{botReply.reply}</p>
                          {botReply.matched_article ? (
                            <div className="support-bot-match">
                              <strong>{botReply.matched_article.title}</strong>
                              <p>{botReply.matched_article.answer}</p>
                            </div>
                          ) : null}
                        </div>
                      ) : null}
                    </div>
                  ) : null}

                  <div className="support-chat-messages">
                    {activeThread.messages.map((message) => (
                      <article
                        key={message.id}
                        className={`support-chat-message ${getMessageClassName(message)} ${
                          isOutgoingMessage(message, canAccessSupport)
                            ? "is-outgoing"
                            : "is-incoming"
                        }`.trim()}
                      >
                        <div className="support-chat-message-meta">
                          <strong>{message.sender_name}</strong>
                          <span>{formatDateTime(message.created_at)}</span>
                          {message.author ? <span>{getRoleLabel(message.author.role)}</span> : null}
                        </div>
                        <div className="support-chat-message-bubble">{message.body}</div>
                      </article>
                    ))}
                    <div ref={messageEndRef} />
                  </div>
                </div>

                {activeThread.status !== "closed" ? (
                  <form className="support-chat-composer" onSubmit={handleSendMessage}>
                    <label className="field support-chat-composer-field">
                      <span>
                        {canAccessSupport ? "Ответ в чат" : "Новое сообщение"}
                      </span>
                      <textarea
                        value={messageBody}
                        onChange={(event) => setMessageBody(event.target.value)}
                        placeholder={
                          canAccessSupport
                            ? "Напишите решение, уточнение или итог по обращению."
                            : "Опишите новую деталь, ошибку или уточнение."
                        }
                      />
                    </label>

                    {messageError ? (
                      <div className="form-banner is-error">{messageError}</div>
                    ) : null}

                    <div className="support-chat-composer-actions">
                      <button
                        type="submit"
                        className="button button-primary"
                        disabled={messageBusy}
                      >
                        {messageBusy ? (
                          <LoaderCircle className="button-icon support-spin" />
                        ) : (
                          <SendHorizonal className="button-icon" />
                        )}
                        <span>{messageBusy ? "Отправляю..." : "Отправить"}</span>
                      </button>
                    </div>
                  </form>
                ) : null}
              </div>
            ) : (
              <EmptyState
                title="Выберите диалог слева"
                description="Здесь появится переписка, статус и управление текущим обращением."
              />
            )
          ) : null}
        </section>
      </section>

      <Modal
        open={threadModalOpen}
        title="Новое обращение"
        description="Опишите проблему коротко: что делали, что ожидали и что пошло не так."
        onClose={() => setThreadModalOpen(false)}
        size="lg"
      >
        <form className="support-thread-form" onSubmit={handleCreateThread}>
          <label className="field">
            <span>Категория</span>
            <select
              value={threadCategory}
              onChange={(event) =>
                setThreadCategory(event.target.value as ThreadCategory)
              }
            >
              {SUPPORT_THREAD_CATEGORY_OPTIONS.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </label>

          <label className="field">
            <span>Тема</span>
            <input
              value={threadSubject}
              onChange={(event) => setThreadSubject(event.target.value)}
              placeholder="Например: не открывается карта"
            />
          </label>

          <label className="field">
            <span>Что случилось</span>
            <textarea
              value={threadBody}
              onChange={(event) => setThreadBody(event.target.value)}
              placeholder="Опишите страницу, шаги, ошибку и что ожидали увидеть."
            />
          </label>

          <div className="support-inline-bot">
            <div className="support-inline-bot-copy">
              <strong>Проверить FAQ перед отправкой</strong>
              <p>Если вопрос типовой, бот подскажет решение ещё до создания чата.</p>
            </div>

            <div className="support-inline-bot-actions">
              <button
                type="button"
                className="button button-muted button-inline"
                onClick={() => void handleAskBot(threadBody.trim() || threadSubject.trim())}
                disabled={botBusy}
              >
                <Sparkles className="button-icon" />
                <span>{botBusy ? "Ищу..." : "Проверить по FAQ"}</span>
              </button>
            </div>

            {botError ? <div className="form-banner is-error">{botError}</div> : null}

            {botReply ? (
              <div className="support-bot-result">
                <div className="support-bot-result-head">
                  <CircleCheckBig className="button-icon" />
                  <strong>Ответ FAQ-бота</strong>
                </div>
                <p>{botReply.reply}</p>
              </div>
            ) : null}
          </div>

          {threadCreateError ? <div className="form-banner is-error">{threadCreateError}</div> : null}

          <div className="support-thread-form-actions">
            <button
              type="submit"
              className="button button-primary"
              disabled={threadCreateBusy}
            >
              {threadCreateBusy ? (
                <LoaderCircle className="button-icon support-spin" />
              ) : (
                <SendHorizonal className="button-icon" />
              )}
              <span>{threadCreateBusy ? "Создаю..." : "Написать в поддержку"}</span>
            </button>

            <button
              type="button"
              className="button button-ghost"
              onClick={() => setThreadModalOpen(false)}
              disabled={threadCreateBusy}
            >
              Отмена
            </button>
          </div>
        </form>
      </Modal>
    </AppShell>
  );
}
