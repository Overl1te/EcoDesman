import type { Metadata } from "next";

import { APP_NAME } from "@/lib/config";
import { buildPostPath, buildProfilePath } from "@/lib/paths";
import {
  absoluteUrl,
  buildBreadcrumbStructuredData,
  buildPageMetadata,
  OPEN_GRAPH_IMAGE,
  SITE_KEYWORDS,
  type SeoImage,
} from "@/lib/seo";
import type { PostDetail } from "@/lib/types";

const POST_KIND_COPY: Record<
  PostDetail["kind"],
  { label: string; articleType: "Article" | "SocialMediaPosting"; keywords: string[] }
> = {
  news: {
    label: "Экологическая публикация",
    articleType: "Article",
    keywords: ["экологические новости", "экология Нижний Новгород", "экосообщество"],
  },
  event: {
    label: "Экологическое событие",
    articleType: "Article",
    keywords: ["экологические мероприятия", "экоакции", "события Нижний Новгород"],
  },
  story: {
    label: "История сообщества",
    articleType: "SocialMediaPosting",
    keywords: ["истории экосообщества", "городские инициативы", "экопривычки"],
  },
};

function cleanText(value: string | null | undefined): string {
  return (value || "").replace(/\s+/g, " ").trim();
}

function trimSentenceEnd(value: string): string {
  return value.trim().replace(/[. ]+$/g, "");
}

function joinMetaSegments(values: Array<string | null | undefined>): string {
  return values
    .map(cleanText)
    .filter(Boolean)
    .map(trimSentenceEnd)
    .join(". ");
}

function buildExcerpt(value: string, limit = 190): string {
  const normalized = cleanText(value);
  if (normalized.length <= limit) {
    return normalized;
  }

  return `${normalized.slice(0, limit - 1).trimEnd()}…`;
}

function toAbsoluteMediaUrl(url: string): string {
  try {
    return new URL(url).toString();
  } catch {
    return absoluteUrl(url.startsWith("/") ? url : `/${url}`);
  }
}

export function getPostKindSeoLabel(kind: PostDetail["kind"]): string {
  return POST_KIND_COPY[kind]?.label ?? POST_KIND_COPY.news.label;
}

export function buildPostSeoTitle(post: PostDetail): string {
  const title = cleanText(post.title);
  if (title) {
    return title;
  }

  return `${getPostKindSeoLabel(post.kind)} от ${post.author.name || post.author.username}`;
}

export function buildPostSeoDescription(post: PostDetail): string {
  const description = buildExcerpt(
    joinMetaSegments([
      getPostKindSeoLabel(post.kind),
      post.event_location ? `Место: ${post.event_location}` : undefined,
      post.event_date ? `Дата: ${post.event_date}` : undefined,
      post.body,
    ]),
  );

  return (
    description ||
    "Публичная публикация сообщества ЭкоВыхухоль с деталями, материалами и обсуждением."
  );
}

export function buildPostSeoImages(post: PostDetail): SeoImage[] {
  const title = buildPostSeoTitle(post);
  const postImages = post.images
    .map((image) => cleanText(image.image_url))
    .filter(Boolean)
    .slice(0, 4)
    .map((url) => ({
      url: toAbsoluteMediaUrl(url),
      alt: title,
    }));

  return postImages.length ? postImages : [OPEN_GRAPH_IMAGE];
}

export function buildPostMetadata(post: PostDetail): Metadata {
  const path = buildPostPath(post);
  const authorName = post.author.name || post.author.username;
  const kindCopy = POST_KIND_COPY[post.kind] ?? POST_KIND_COPY.news;

  return buildPageMetadata({
    title: buildPostSeoTitle(post),
    description: buildPostSeoDescription(post),
    path,
    openGraphType: "article",
    images: buildPostSeoImages(post),
    publishedTime: post.published_at,
    modifiedTime: post.updated_at || post.published_at,
    authors: [authorName],
    tags: [getPostKindSeoLabel(post.kind), ...kindCopy.keywords],
    keywords: [
      APP_NAME,
      authorName,
      buildPostSeoTitle(post),
      ...kindCopy.keywords,
      ...SITE_KEYWORDS,
    ],
  });
}

export function buildPostStructuredData(post: PostDetail) {
  const path = buildPostPath(post);
  const url = absoluteUrl(path);
  const authorUrl = absoluteUrl(buildProfilePath(post.author));
  const title = buildPostSeoTitle(post);
  const description = buildPostSeoDescription(post);
  const image = buildPostSeoImages(post).map((item) => item.url);
  const authorName = post.author.name || post.author.username;
  const kindCopy = POST_KIND_COPY[post.kind] ?? POST_KIND_COPY.news;

  const article = {
    "@type": kindCopy.articleType,
    "@id": `${url}#article`,
    mainEntityOfPage: {
      "@id": `${url}#webpage`,
    },
    headline: title,
    name: title,
    description,
    image,
    inLanguage: "ru-RU",
    datePublished: post.published_at,
    dateModified: post.updated_at || post.published_at,
    author: {
      "@type": "Person",
      name: authorName,
      url: authorUrl,
    },
    publisher: {
      "@id": `${absoluteUrl()}#organization`,
    },
    keywords: [getPostKindSeoLabel(post.kind), ...kindCopy.keywords].join(", "),
    commentCount: post.comments_count,
    interactionStatistic: [
      {
        "@type": "InteractionCounter",
        interactionType: "https://schema.org/ViewAction",
        userInteractionCount: post.view_count,
      },
      {
        "@type": "InteractionCounter",
        interactionType: "https://schema.org/LikeAction",
        userInteractionCount: post.likes_count,
      },
      {
        "@type": "InteractionCounter",
        interactionType: "https://schema.org/CommentAction",
        userInteractionCount: post.comments_count,
      },
    ],
  };

  const breadcrumb = buildBreadcrumbStructuredData([
    { name: APP_NAME, path: "/" },
    { name: "Публикации", path: "/" },
    { name: title, path },
  ]);

  if (post.kind !== "event") {
    return [article, breadcrumb];
  }

  return [
    article,
    {
      "@type": "Event",
      "@id": `${url}#event`,
      url,
      name: title,
      description,
      image,
      startDate: post.event_starts_at ?? post.event_date ?? undefined,
      endDate: post.event_ends_at ?? undefined,
      eventStatus: post.is_event_cancelled
        ? "https://schema.org/EventCancelled"
        : "https://schema.org/EventScheduled",
      eventAttendanceMode: "https://schema.org/OfflineEventAttendanceMode",
      isAccessibleForFree: true,
      inLanguage: "ru-RU",
      organizer: {
        "@id": `${absoluteUrl()}#organization`,
      },
      location: post.event_location
        ? {
            "@type": "Place",
            name: post.event_location,
          }
        : undefined,
    },
    breadcrumb,
  ];
}
