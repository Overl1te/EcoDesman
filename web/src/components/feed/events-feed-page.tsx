"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { FormEvent, startTransition, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import {
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  CircleOff,
  Clock3,
  LayoutGrid,
  List,
  MapPin,
  Plus,
} from "lucide-react";

import { AppShell } from "@/components/layout/app-shell";
import { useAuth } from "@/components/providers/auth-provider";
import { Avatar } from "@/components/ui/avatar";
import { EmptyState } from "@/components/ui/empty-state";
import { LoadingBlock } from "@/components/ui/loading-block";
import { getEventCalendar, setEventCancelled } from "@/lib/api";
import { formatDate, formatDateTime } from "@/lib/format";
import { buildPostPathFromParts, buildProfilePath } from "@/lib/paths";
import type { CalendarEventEntry } from "@/lib/types";

const WEEKDAY_LABELS = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"];

type ViewMode = "month" | "list";
type QuickFilter = "all" | "today" | "week" | "mine";

export function EventsFeedPage({
  intro,
  afterContent,
}: {
  intro?: ReactNode;
  afterContent?: ReactNode;
}) {
  const router = useRouter();
  const { isAuthenticated, openAuthModal } = useAuth();
  const [visibleMonth, setVisibleMonth] = useState(() => startOfMonth(new Date()));
  const [selectedDate, setSelectedDate] = useState(() => toDateKey(new Date()));
  const [events, setEvents] = useState<CalendarEventEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [updatingEventId, setUpdatingEventId] = useState<number | null>(null);
  const [viewMode, setViewMode] = useState<ViewMode>("month");
  const [quickFilter, setQuickFilter] = useState<QuickFilter>("all");
  const [hoveredDate, setHoveredDate] = useState<string | null>(null);
  const [quickCreateDate, setQuickCreateDate] = useState<string | null>(null);
  const [quickCreateTitle, setQuickCreateTitle] = useState("");
  const quickCreateRef = useRef<HTMLDivElement | null>(null);

  const todayKey = useMemo(() => toDateKey(new Date()), []);
  const monthStart = useMemo(() => startOfMonth(new Date()), []);
  const monthLimit = useMemo(
    () => new Date(monthStart.getFullYear() + 10, monthStart.getMonth(), 1),
    [monthStart],
  );

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    void getEventCalendar(
      visibleMonth.getFullYear(),
      visibleMonth.getMonth() + 1,
      isAuthenticated,
    )
      .then((response) => {
        if (cancelled) return;
        setEvents(response.events);
        const currentMonthKey = `${response.year}-${String(response.month).padStart(2, "0")}`;
        setSelectedDate((current) =>
          current.startsWith(currentMonthKey)
            ? current
            : response.events[0]?.event_date ?? `${currentMonthKey}-01`,
        );
      })
      .catch((nextError: Error) => {
        if (!cancelled) setError(nextError.message);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => { cancelled = true; };
  }, [isAuthenticated, visibleMonth]);

  useEffect(() => {
    if (!quickCreateDate) return;
    const handleClick = (e: MouseEvent) => {
      if (quickCreateRef.current && !quickCreateRef.current.contains(e.target as Node)) {
        setQuickCreateDate(null);
        setQuickCreateTitle("");
      }
    };
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [quickCreateDate]);

  const filteredEvents = useMemo(() => {
    return events.filter((event) => {
      if (quickFilter === "today") return event.event_date === todayKey;
      if (quickFilter === "week") {
        const weekEnd = new Date(`${todayKey}T00:00:00`);
        weekEnd.setDate(weekEnd.getDate() + 7);
        return (event.event_date ?? "") >= todayKey && (event.event_date ?? "") <= toDateKey(weekEnd);
      }
      if (quickFilter === "mine") return event.can_edit;
      return true;
    });
  }, [events, quickFilter, todayKey]);

  const eventsByDate = useMemo(() => {
    const grouped = new Map<string, CalendarEventEntry[]>();
    for (const event of filteredEvents) {
      if (!event.event_date) continue;
      const bucket = grouped.get(event.event_date) ?? [];
      bucket.push(event);
      grouped.set(event.event_date, bucket);
    }
    return grouped;
  }, [filteredEvents]);

  const selectedDayEvents = useMemo(
    () => sortEventsForAgenda(eventsByDate.get(selectedDate) ?? []),
    [eventsByDate, selectedDate],
  );

  const upcomingEvents = useMemo(() => {
    return sortEventsForAgenda(
      filteredEvents.filter((e) => (e.event_date ?? "") >= todayKey),
    ).slice(0, 8);
  }, [filteredEvents, todayKey]);

  const monthGrid = useMemo(() => buildMonthGrid(visibleMonth), [visibleMonth]);
  const monthLabel = useMemo(
    () =>
      new Intl.DateTimeFormat("ru-RU", { month: "long", year: "numeric" }).format(visibleMonth),
    [visibleMonth],
  );

  const canGoPrev = compareMonth(visibleMonth, monthStart) > 0;
  const canGoNext = compareMonth(visibleMonth, monthLimit) < 0;
  const canJumpToToday =
    compareMonth(visibleMonth, monthStart) !== 0 || selectedDate !== todayKey;

  const hasAnyEvents = filteredEvents.length > 0;

  const navigateMonth = (direction: -1 | 1) => {
    startTransition(() => {
      const nextMonth = new Date(visibleMonth.getFullYear(), visibleMonth.getMonth() + direction, 1);
      setVisibleMonth(nextMonth);
      setSelectedDate(toDateKey(nextMonth));
    });
  };

  const handleDayClick = (dateKey: string, dayEvents: CalendarEventEntry[]) => {
    const dayDate = new Date(`${dateKey}T00:00:00`);
    if (
      dayDate.getFullYear() !== visibleMonth.getFullYear()
      || dayDate.getMonth() !== visibleMonth.getMonth()
    ) {
      startTransition(() => {
        setVisibleMonth(startOfMonth(dayDate));
        setSelectedDate(dateKey);
      });
      return;
    }
    setSelectedDate(dateKey);
    if (dayEvents.length === 0) {
      setQuickCreateDate(dateKey);
      setQuickCreateTitle("");
    }
  };

  const handleCreateEvent = (date?: string) => {
    if (!isAuthenticated) {
      openAuthModal({ returnTo: "/posts/new" });
      return;
    }
    const url = date ? `/posts/new?event_date=${date}` : "/posts/new";
    router.push(url);
  };

  const handleJumpToToday = () => {
    const today = new Date();
    startTransition(() => {
      setVisibleMonth(startOfMonth(today));
      setSelectedDate(todayKey);
    });
  };

  const handleToggleCancellation = async (eventItem: CalendarEventEntry) => {
    if (!isAuthenticated) {
      openAuthModal({ returnTo: "/events" });
      return;
    }
    setUpdatingEventId(eventItem.id);
    setError(null);
    try {
      const nextPost = await setEventCancelled(eventItem.id, !eventItem.is_event_cancelled);
      setEvents((current) =>
        current.map((item) =>
          item.id === nextPost.id
            ? {
                ...item,
                event_date: nextPost.event_date,
                event_starts_at: nextPost.event_starts_at,
                event_ends_at: nextPost.event_ends_at,
                event_location: nextPost.event_location,
                is_event_cancelled: nextPost.is_event_cancelled,
                event_cancelled_at: nextPost.event_cancelled_at,
              }
            : item,
        ),
      );
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Не удалось обновить статус мероприятия.");
    } finally {
      setUpdatingEventId(null);
    }
  };

  const handleQuickCreate = (e: FormEvent) => {
    e.preventDefault();
    if (!isAuthenticated) {
      openAuthModal({ returnTo: "/posts/new" });
      return;
    }
    const params = new URLSearchParams({ kind: "event" });
    if (quickCreateDate) params.set("event_date", quickCreateDate);
    if (quickCreateTitle.trim()) params.set("title", quickCreateTitle.trim());
    router.push(`/posts/new?${params.toString()}`);
  };

  return (
    <AppShell
      title="Мероприятия"
      titleTag="p"
      contentClassName="page-content-events"
      actions={
        <div className="events-topbar-actions">
          <button
            type="button"
            className="button button-muted"
            onClick={handleJumpToToday}
            disabled={!canJumpToToday}
          >
            Сегодня
          </button>
          <button type="button" className="button button-primary events-cta-main" onClick={() => handleCreateEvent()}>
            <Plus className="button-icon" />
            Создать мероприятие
          </button>
        </div>
      }
    >
      {intro}

      <div className="events-hero">
        <div className="events-hero-text">
          <p className="eyebrow">Календарь событий</p>
          <p className="events-hero-subtitle">Создавайте события и участвуйте в жизни сообщества</p>
        </div>
        <div className="events-hero-controls">
          <div className="events-quick-filters" role="toolbar" aria-label="Быстрые фильтры">
            {(["all", "today", "week", "mine"] as QuickFilter[]).map((f) => (
              <button
                key={f}
                type="button"
                className={`events-quick-filter${quickFilter === f ? " is-active" : ""}`}
                onClick={() => setQuickFilter(f)}
              >
                {QUICK_FILTER_LABELS[f]}
              </button>
            ))}
          </div>
          {!loading && !error ? (
            <div className="events-view-bar">
              <div className="events-view-switcher">
                <button
                  type="button"
                  className={`events-view-btn${viewMode === "month" ? " is-active" : ""}`}
                  onClick={() => setViewMode("month")}
                >
                  <LayoutGrid className="button-icon" />
                  Месяц
                </button>
                <button
                  type="button"
                  className={`events-view-btn${viewMode === "list" ? " is-active" : ""}`}
                  onClick={() => setViewMode("list")}
                >
                  <List className="button-icon" />
                  Список
                </button>
              </div>
            </div>
          ) : null}
        </div>
      </div>

      {loading ? <LoadingBlock label="Загружаю календарь мероприятий..." /> : null}
      {error && !loading ? <EmptyState title="Не удалось открыть календарь" description={error} /> : null}

      {!loading && !error ? (
        <>
          {!hasAnyEvents && viewMode === "month" ? (
            <div className="events-onboarding panel">
              <div className="events-onboarding-icon">
                <CalendarDays size={40} />
              </div>
              <strong>Пока ничего не запланировано</strong>
              <p>Создайте первое событие и пригласите участников сообщества</p>
              <button type="button" className="button button-primary" onClick={() => handleCreateEvent()}>
                <Plus className="button-icon" />
                Создать мероприятие
              </button>
            </div>
          ) : null}

          {hasAnyEvents && viewMode === "month" ? (
            <section className="events-workspace">
              <div className="events-calendar-board panel">
                <header className="events-calendar-header">
                  <button
                    type="button"
                    className="events-nav-btn"
                    onClick={() => navigateMonth(-1)}
                    disabled={!canGoPrev}
                    aria-label="Предыдущий месяц"
                  >
                    <ChevronLeft size={18} />
                  </button>
                  <div className="events-month-label">
                    <h2>{capitalize(monthLabel)}</h2>
                  </div>
                  <button
                    type="button"
                    className="events-nav-btn"
                    onClick={() => navigateMonth(1)}
                    disabled={!canGoNext}
                    aria-label="Следующий месяц"
                  >
                    <ChevronRight size={18} />
                  </button>
                </header>

                <div className="events-calendar-grid" role="grid">
                  {WEEKDAY_LABELS.map((label) => (
                    <div key={label} className="events-calendar-weekday">
                      {label}
                    </div>
                  ))}

                  {monthGrid.map((day) => {
                    const dayEvents = sortEventsForAgenda(eventsByDate.get(day.dateKey) ?? []);
                    const isSelected = day.dateKey === selectedDate;
                    const isToday = day.dateKey === todayKey;
                    const isHovered = hoveredDate === day.dateKey;
                    const firstEvent = dayEvents[0];
                    const extraCount = dayEvents.length - 1;

                    return (
                      <button
                        key={day.dateKey}
                        type="button"
                        className={[
                          "events-calendar-day",
                          day.inCurrentMonth ? "" : "is-muted",
                          isSelected ? "is-selected" : "",
                          isToday ? "is-today" : "",
                          dayEvents.length > 0 ? "has-events" : "",
                        ].filter(Boolean).join(" ")}
                        onClick={() => handleDayClick(day.dateKey, dayEvents)}
                        onMouseEnter={() => setHoveredDate(day.dateKey)}
                        onMouseLeave={() => setHoveredDate(null)}
                        title={dayEvents.length === 0 ? "Создать событие" : undefined}
                      >
                        <div className="events-calendar-day-top">
                          <span className={`events-calendar-day-number${isToday ? " is-today" : ""}`}>
                            {day.dayNumber}
                          </span>
                          {isToday && <span className="events-today-badge">Сегодня</span>}
                          {dayEvents.length === 0 && (isHovered || isSelected) ? (
                            <span className="events-calendar-day-add">
                              <Plus size={12} />
                            </span>
                          ) : null}
                        </div>

                        {firstEvent ? (
                          <div className="events-calendar-day-events">
                            <span className={`events-calendar-day-event-title${firstEvent.is_event_cancelled ? " is-cancelled" : ""}`}>
                              {firstEvent.title || "Мероприятие"}
                            </span>
                            {extraCount > 0 && (
                              <span className="events-calendar-day-extra">+{extraCount}</span>
                            )}
                          </div>
                        ) : null}

                        <span className="events-calendar-day-dots">
                          {dayEvents.slice(0, 3).map((eventItem) => (
                            <span
                              key={eventItem.id}
                              className={`events-calendar-dot${eventItem.is_event_cancelled ? " is-cancelled" : ""}`}
                            />
                          ))}
                        </span>
                      </button>
                    );
                  })}
                </div>

                {quickCreateDate ? (
                  <div className="events-quick-create-overlay" ref={quickCreateRef}>
                    <form className="events-quick-create" onSubmit={handleQuickCreate}>
                      <p className="eyebrow">Новое событие · {formatCalendarDay(quickCreateDate)}</p>
                      <input
                        autoFocus
                        className="events-quick-create-input"
                        placeholder="Название мероприятия..."
                        value={quickCreateTitle}
                        onChange={(e) => setQuickCreateTitle(e.target.value)}
                      />
                      <div className="events-quick-create-actions">
                        <button type="submit" className="button button-primary button-sm">
                          Создать
                        </button>
                        <button
                          type="button"
                          className="button button-muted button-sm"
                          onClick={() => { setQuickCreateDate(null); setQuickCreateTitle(""); }}
                        >
                          Отмена
                        </button>
                      </div>
                    </form>
                  </div>
                ) : null}
              </div>

              <aside className="events-agenda panel">
                <header className="events-agenda-header">
                  <div>
                    <p className="eyebrow">Выбранный день</p>
                    <h2>{formatCalendarDay(selectedDate)}</h2>
                  </div>
                  {selectedDayEvents.length > 0 && (
                    <span className="events-agenda-pill">
                      {selectedDayEvents.length} {pluralizeEvents(selectedDayEvents.length)}
                    </span>
                  )}
                </header>

                {selectedDayEvents.length > 0 ? (
                  <div className="events-agenda-list">
                    {selectedDayEvents.map((eventItem) => (
                      <EventAgendaCard
                        key={eventItem.id}
                        eventItem={eventItem}
                        updatingEventId={updatingEventId}
                        onToggleCancellation={handleToggleCancellation}
                      />
                    ))}
                  </div>
                ) : (
                  <div className="events-agenda-empty">
                    <CalendarDays size={32} className="events-agenda-empty-icon" />
                    <strong>Пока ничего не запланировано</strong>
                    <p>Создайте событие или выберите другую дату в календаре</p>
                    <button
                      type="button"
                      className="button button-primary button-sm"
                      onClick={() => handleCreateEvent(selectedDate)}
                    >
                      <Plus className="button-icon" />
                      Создать событие
                    </button>
                  </div>
                )}
              </aside>
            </section>
          ) : null}

          {viewMode === "list" ? (
            <section className="events-list-view panel">
              <header className="events-list-header">
                <div>
                  <p className="eyebrow">Список событий</p>
                  <h2>Ближайшие мероприятия</h2>
                </div>
                <button type="button" className="button button-primary" onClick={() => handleCreateEvent()}>
                  <Plus className="button-icon" />
                  Создать мероприятие
                </button>
              </header>

              {upcomingEvents.length === 0 ? (
                <div className="events-onboarding" style={{ border: "none", padding: 0 }}>
                  <div className="events-onboarding-icon">
                    <CalendarDays size={36} />
                  </div>
                  <strong>Пока ничего не запланировано</strong>
                  <p>Создайте первое событие и пригласите участников</p>
                  <button type="button" className="button button-primary" onClick={() => handleCreateEvent()}>
                    <Plus className="button-icon" />
                    Создать мероприятие
                  </button>
                </div>
              ) : (
                <div className="events-list-cards">
                  {upcomingEvents.map((eventItem) => (
                    <EventListCard key={eventItem.id} eventItem={eventItem} />
                  ))}
                </div>
              )}
            </section>
          ) : null}

          {hasAnyEvents && viewMode === "month" && upcomingEvents.length > 0 ? (
            <section className="events-upcoming panel">
              <header className="events-upcoming-header">
                <div>
                  <p className="eyebrow">Скоро</p>
                  <h2>Ближайшие мероприятия</h2>
                </div>
              </header>
              <div className="events-list-cards">
                {upcomingEvents.map((eventItem) => (
                  <EventListCard key={eventItem.id} eventItem={eventItem} />
                ))}
              </div>
            </section>
          ) : null}
        </>
      ) : null}

      {afterContent}
    </AppShell>
  );
}

function EventAgendaCard({
  eventItem,
  updatingEventId,
  onToggleCancellation,
}: {
  eventItem: CalendarEventEntry;
  updatingEventId: number | null;
  onToggleCancellation: (event: CalendarEventEntry) => void;
}) {
  return (
    <article
      className={`events-agenda-card${eventItem.is_event_cancelled ? " is-cancelled" : ""}`}
    >
      <div className="events-agenda-card-head">
        <Link href={buildProfilePath(eventItem.author)} className="author-link">
          <Avatar
            user={{
              avatar_url: eventItem.author.avatar_url,
              name: eventItem.author.name,
              username: eventItem.author.username,
            }}
            size="sm"
          />
          <span className="author-copy">
            <strong>{eventItem.author.name}</strong>
            <small>{eventItem.author.status_text || "Автор события"}</small>
          </span>
        </Link>
        {eventItem.is_event_cancelled ? (
          <span className="tag tag-danger">Отменено</span>
        ) : (
          <span className="tag">Запланировано</span>
        )}
      </div>

      <div className="events-agenda-card-body">
        <h3>{eventItem.title || "Мероприятие без заголовка"}</h3>
        <p>
          {eventItem.body || "Откройте карточку события, чтобы посмотреть полное описание и детали."}
        </p>
      </div>

      <div className="events-agenda-card-meta">
        <span className="metric-item">
          <CalendarDays className="meta-icon" />
          <span>{formatCalendarDay(eventItem.event_date)}</span>
        </span>
        {eventItem.event_starts_at ? (
          <span className="metric-item">
            <Clock3 className="meta-icon" />
            <span>{formatDateTime(eventItem.event_starts_at)}</span>
          </span>
        ) : null}
        {eventItem.event_location ? (
          <span className="metric-item">
            <MapPin className="meta-icon" />
            <span>{eventItem.event_location}</span>
          </span>
        ) : null}
        {eventItem.is_event_cancelled && eventItem.event_cancelled_at ? (
          <span className="metric-item">
            <CircleOff className="meta-icon" />
            <span>Отменено {formatDateTime(eventItem.event_cancelled_at)}</span>
          </span>
        ) : null}
      </div>

      <div className="events-agenda-card-actions">
        <Link
          href={buildPostPathFromParts({
            postId: eventItem.id,
            postSlug: eventItem.slug,
            authorUsername: eventItem.author.username,
          })}
          className="button button-inline button-primary"
        >
          Открыть пост
        </Link>
        {eventItem.can_edit ? (
          <button
            type="button"
            className={`button button-inline ${eventItem.is_event_cancelled ? "button-muted" : "button-ghost"}`}
            onClick={() => onToggleCancellation(eventItem)}
            disabled={updatingEventId === eventItem.id}
          >
            {updatingEventId === eventItem.id
              ? "Сохраняю..."
              : eventItem.is_event_cancelled
                ? "Вернуть в календарь"
                : "Отменить мероприятие"}
          </button>
        ) : null}
      </div>
    </article>
  );
}

function EventListCard({ eventItem }: { eventItem: CalendarEventEntry }) {
  return (
    <article className={`events-list-card${eventItem.is_event_cancelled ? " is-cancelled" : ""}`}>
      <div className="events-list-card-date">
        <span className="events-list-card-day">
          {eventItem.event_date ? new Date(`${eventItem.event_date}T00:00:00`).getDate() : "—"}
        </span>
        <span className="events-list-card-month">
          {eventItem.event_date
            ? new Intl.DateTimeFormat("ru-RU", { month: "short" }).format(
                new Date(`${eventItem.event_date}T00:00:00`),
              )
            : ""}
        </span>
      </div>
      <div className="events-list-card-body">
        <h3>{eventItem.title || "Мероприятие"}</h3>
        <div className="events-list-card-meta">
          {eventItem.event_starts_at ? (
            <span className="metric-item">
              <Clock3 size={13} className="meta-icon" />
              <span>{formatDateTime(eventItem.event_starts_at)}</span>
            </span>
          ) : null}
          {eventItem.event_location ? (
            <span className="metric-item">
              <MapPin size={13} className="meta-icon" />
              <span>{eventItem.event_location}</span>
            </span>
          ) : null}
        </div>
        {eventItem.is_event_cancelled && (
          <span className="tag tag-danger" style={{ marginTop: 4 }}>Отменено</span>
        )}
      </div>
      <Link
        href={buildPostPathFromParts({
          postId: eventItem.id,
          postSlug: eventItem.slug,
          authorUsername: eventItem.author.username,
        })}
        className="button button-muted button-sm events-list-card-open"
      >
        Открыть
      </Link>
    </article>
  );
}

const QUICK_FILTER_LABELS: Record<QuickFilter, string> = {
  all: "Все",
  today: "Сегодня",
  week: "На неделе",
  mine: "Мои",
};

function buildMonthGrid(
  monthDate: Date,
): Array<{ dateKey: string; dayNumber: number; inCurrentMonth: boolean }> {
  const firstDay = startOfMonth(monthDate);
  const firstWeekday = (firstDay.getDay() + 6) % 7;
  const gridStart = new Date(firstDay);
  gridStart.setDate(firstDay.getDate() - firstWeekday);

  return Array.from({ length: 42 }, (_, index) => {
    const day = new Date(gridStart);
    day.setDate(gridStart.getDate() + index);
    const dateKey = toDateKey(day);
    return {
      dateKey,
      dayNumber: day.getDate(),
      inCurrentMonth: day.getMonth() === monthDate.getMonth(),
    };
  });
}

function startOfMonth(value: Date): Date {
  return new Date(value.getFullYear(), value.getMonth(), 1);
}

function compareMonth(left: Date, right: Date): number {
  return left.getFullYear() * 12 + left.getMonth() - (right.getFullYear() * 12 + right.getMonth());
}

function toDateKey(value: Date): string {
  const year = value.getFullYear();
  const month = String(value.getMonth() + 1).padStart(2, "0");
  const day = String(value.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function formatCalendarDay(dateKey: string | null | undefined): string {
  if (!dateKey) return "Дата не указана";
  return formatDate(`${dateKey}T00:00:00`, {
    weekday: "long",
    day: "2-digit",
    month: "long",
    year: "numeric",
  });
}

function capitalize(value: string): string {
  return value ? value[0].toUpperCase() + value.slice(1) : value;
}

function sortEventsForAgenda(events: CalendarEventEntry[]): CalendarEventEntry[] {
  return [...events].sort((left, right) => {
    if (left.is_event_cancelled !== right.is_event_cancelled) {
      return Number(left.is_event_cancelled) - Number(right.is_event_cancelled);
    }
    const leftDate = left.event_starts_at ?? left.event_date ?? "";
    const rightDate = right.event_starts_at ?? right.event_date ?? "";
    return leftDate.localeCompare(rightDate);
  });
}

function pluralizeEvents(count: number): string {
  const mod10 = count % 10;
  const mod100 = count % 100;
  if (mod10 === 1 && mod100 !== 11) return "событие";
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return "события";
  return "событий";
}
