import { API_BASE_URL, SITE_URL } from "@/lib/config";
import type {
  CurrentUser,
  PaginatedResponse,
  PostDetail,
  PostListItem,
} from "@/lib/types";

const DEFAULT_REVALIDATE_SECONDS = 1800;
const MAX_SITEMAP_PAGES = 50;
const LOCAL_API_HOSTNAMES = new Set(["localhost", "127.0.0.1", "0.0.0.0", "::1"]);

function getServerApiBaseUrl(): string {
  try {
    const parsed = new URL(API_BASE_URL);
    parsed.hash = "";
    parsed.search = "";

    if (
      process.env.NODE_ENV === "production"
      && LOCAL_API_HOSTNAMES.has(parsed.hostname)
    ) {
      return `${SITE_URL}${parsed.pathname}`.replace(/\/$/, "");
    }

    if (parsed.protocol === "http:" && !LOCAL_API_HOSTNAMES.has(parsed.hostname)) {
      parsed.protocol = "https:";
    }

    return parsed.toString().replace(/\/$/, "");
  } catch {
    const normalized = API_BASE_URL.startsWith("/")
      ? API_BASE_URL
      : `/${API_BASE_URL}`;

    return `${SITE_URL}${normalized}`.replace(/\/$/, "");
  }
}

function buildServerApiUrl(path: string): URL {
  const normalizedPath = path.startsWith("/") ? path : `/${path}`;
  return new URL(`${getServerApiBaseUrl()}${normalizedPath}`);
}

async function serverApiGet<T>(
  path: string,
  options: {
    cacheMode?: RequestCache;
    searchParams?: Record<string, number | string | null | undefined>;
    revalidate?: number;
  } = {},
): Promise<T> {
  const url = buildServerApiUrl(path);

  for (const [key, value] of Object.entries(options.searchParams ?? {})) {
    if (value === null || value === undefined || value === "") {
      continue;
    }

    url.searchParams.set(key, String(value));
  }

  const response = await fetch(url, {
    headers: {
      Accept: "application/json",
    },
    ...(options.cacheMode
      ? { cache: options.cacheMode }
      : {
          next: {
            revalidate: options.revalidate ?? DEFAULT_REVALIDATE_SECONDS,
          },
        }),
  });

  if (!response.ok) {
    throw new Error(`Server API request failed with status ${response.status}`);
  }

  return response.json() as Promise<T>;
}

export async function getServerPost(postId: number): Promise<PostDetail | null> {
  try {
    return await serverApiGet<PostDetail>(`/posts/${postId}`, {
      revalidate: 300,
    });
  } catch {
    return null;
  }
}

export async function getServerPostBySlug(
  username: string,
  postSlug: string,
): Promise<PostDetail | null> {
  try {
    return await serverApiGet<PostDetail>(
      `/posts/by-slug/${encodeURIComponent(username)}/${encodeURIComponent(postSlug)}`,
      {
        revalidate: 300,
      },
    );
  } catch {
    return null;
  }
}

export async function getServerPublicProfile(
  userId: number,
): Promise<CurrentUser | null> {
  try {
    return await serverApiGet<CurrentUser>(`/profiles/${userId}`, {
      revalidate: 900,
    });
  } catch {
    return null;
  }
}

export async function getServerPublicProfileByUsername(
  username: string,
): Promise<CurrentUser | null> {
  try {
    return await serverApiGet<CurrentUser>(
      `/profiles/by-username/${encodeURIComponent(username)}`,
      {
        revalidate: 900,
      },
    );
  } catch {
    return null;
  }
}

export async function listServerUpcomingEvents(
  limit = 8,
): Promise<PostListItem[]> {
  const variants: Array<Record<string, string | number>> = [
    {
      kind: "event",
      event_scope: "upcoming",
      ordering: "recent",
      page: 1,
    },
    {
      kind: "event",
      ordering: "recent",
      page: 1,
    },
  ];

  for (const searchParams of variants) {
    try {
      const response = await serverApiGet<PaginatedResponse<PostListItem>>(
        "/posts",
        {
          cacheMode: "no-store",
          searchParams,
          revalidate: 900,
        },
      );

      const events = response.results
        .filter((item) => item.is_published && item.kind === "event")
        .slice(0, limit);

      if (events.length) {
        return events;
      }
    } catch {
      continue;
    }
  }

  return [];
}

export async function listPublicSitemapEntities(): Promise<{
  posts: PostListItem[];
  profiles: Array<{ id: number; username: string; lastModified: string }>;
}> {
  const posts = new Map<number, PostListItem>();
  const profiles = new Map<number, { username: string; lastModified: string }>();

  for (let page = 1; page <= MAX_SITEMAP_PAGES; page += 1) {
    const response = await serverApiGet<PaginatedResponse<PostListItem>>(
      "/posts",
      {
        searchParams: {
          ordering: "recent",
          page_size: 20,
          page,
        },
        revalidate: 1800,
      },
    );

    for (const item of response.results) {
      if (!item.is_published) {
        continue;
      }

      posts.set(item.id, item);

      const currentProfile = profiles.get(item.author.id);
      if (
        !currentProfile ||
        new Date(item.updated_at || item.published_at).getTime() >
          new Date(currentProfile.lastModified).getTime()
      ) {
        profiles.set(item.author.id, {
          username: item.author.username,
          lastModified: item.updated_at || item.published_at,
        });
      }
    }

    if (!response.next) {
      break;
    }
  }

  return {
    posts: [...posts.values()],
    profiles: [...profiles.entries()].map(([id, profile]) => ({
      id,
      username: profile.username,
      lastModified: profile.lastModified,
    })),
  };
}
