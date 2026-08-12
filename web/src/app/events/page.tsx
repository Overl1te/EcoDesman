import type { Metadata } from "next";
import { connection } from "next/server";

import { EventsFeedPage } from "@/components/feed/events-feed-page";
import { StructuredDataScript } from "@/components/seo/structured-data-script";
import { buildPostPath } from "@/lib/paths";
import { listServerUpcomingEvents } from "@/lib/server-api";
import {
  absoluteUrl,
  buildCollectionPageStructuredData,
  buildPageMetadata,
} from "@/lib/seo";
import type { PostListItem } from "@/lib/types";

export const metadata: Metadata = buildPageMetadata({
  title: "Экологические мероприятия и акции в Нижнем Новгороде",
  description:
    "Календарь ЭкоВыхухоли помогает следить за экологическими мероприятиями, городскими акциями, лекциями и встречами сообщества в Нижнем Новгороде. Выбирайте события, изучайте детали и не пропускайте обновления.",
  path: "/events",
});

function buildEventDescription(event: PostListItem): string {
  const parts = [
    event.event_location?.trim(),
    event.preview_text?.trim(),
    event.body?.trim(),
  ].filter(Boolean);

  const description = parts.join(". ").replace(/\s+/g, " ").trim();
  if (description.length <= 220) {
    return description;
  }

  return `${description.slice(0, 219).trimEnd()}…`;
}

function toAbsoluteMediaUrl(url: string): string {
  try {
    return new URL(url).toString();
  } catch {
    return absoluteUrl(url.startsWith("/") ? url : `/${url}`);
  }
}

function buildEventStructuredData(event: PostListItem) {
  const url = absoluteUrl(buildPostPath(event));

  return {
    "@type": "Event",
    "@id": `${url}#event`,
    url,
    name: event.title?.trim() || "Экологическое событие",
    description: buildEventDescription(event),
    startDate: event.event_starts_at ?? event.event_date ?? undefined,
    endDate: event.event_ends_at ?? undefined,
    eventStatus: event.is_event_cancelled
      ? "https://schema.org/EventCancelled"
      : "https://schema.org/EventScheduled",
    eventAttendanceMode: "https://schema.org/OfflineEventAttendanceMode",
    isAccessibleForFree: true,
    inLanguage: "ru-RU",
    location: event.event_location
      ? {
          "@type": "Place",
          name: event.event_location,
        }
      : undefined,
    image: event.preview_image_url
      ? [toAbsoluteMediaUrl(event.preview_image_url)]
      : undefined,
  };
}

export default async function EventsPage() {
  await connection();

  const upcomingEvents = await listServerUpcomingEvents();
  const eventListStructuredData = upcomingEvents.length
    ? {
        "@type": "ItemList",
        "@id": `${absoluteUrl("/events")}#upcoming-events`,
        url: absoluteUrl("/events"),
        name: "Ближайшие экологические события ЭкоВыхухоли",
        numberOfItems: upcomingEvents.length,
        itemListOrder: "https://schema.org/ItemListOrderAscending",
        itemListElement: upcomingEvents.map((event, index) => ({
          "@type": "ListItem",
          position: index + 1,
          url: absoluteUrl(buildPostPath(event)),
          name: event.title?.trim() || "Экологическое событие",
        })),
      }
    : null;

  return (
    <>
      <StructuredDataScript
        data={[
          buildCollectionPageStructuredData({
            path: "/events",
            name: "Экологические мероприятия и акции в Нижнем Новгороде",
            description:
              "Календарь экологических событий, городских акций, лекций и встреч сообщества ЭкоВыхухоль.",
            about: [
              "экологические мероприятия",
              "городские акции",
              "экосообщество",
              "эколекции",
              "сбор вторсырья",
            ],
          }),
          ...(eventListStructuredData ? [eventListStructuredData] : []),
          ...upcomingEvents.map(buildEventStructuredData),
        ]}
      />
      <EventsFeedPage />
    </>
  );
}
