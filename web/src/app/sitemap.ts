import type { MetadataRoute } from "next";

import { SITE_URL } from "@/lib/config";
import { buildPostPath, buildProfilePathFromParts } from "@/lib/paths";
import { listPublicSitemapEntities } from "@/lib/server-api";

export const dynamic = "force-dynamic";

const STATIC_ROUTES: Array<{
  path: string;
  changeFrequency: MetadataRoute.Sitemap[number]["changeFrequency"];
  priority: number;
}> = [
  { path: "/", changeFrequency: "daily", priority: 1 },
  { path: "/map", changeFrequency: "weekly", priority: 0.9 },
  { path: "/events", changeFrequency: "daily", priority: 0.88 },
  { path: "/download", changeFrequency: "monthly", priority: 0.74 },
  { path: "/help", changeFrequency: "monthly", priority: 0.72 },
];

function buildAbsoluteUrl(path: string): string {
  return `${SITE_URL}${path === "/" ? "" : path}`;
}

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const staticEntries = STATIC_ROUTES.map(
    ({ path, changeFrequency, priority }) => ({
      url: buildAbsoluteUrl(path),
      changeFrequency,
      priority,
    }),
  );

  try {
    const { posts, profiles } = await listPublicSitemapEntities();
    const dynamicEntries: MetadataRoute.Sitemap = [
      ...posts.map((post) => ({
        url: buildAbsoluteUrl(buildPostPath(post)),
        lastModified: post.updated_at || post.published_at,
        changeFrequency: "weekly" as const,
        priority: post.kind === "event" ? 0.76 : 0.68,
      })),
      ...profiles.map((profile) => ({
        url: buildAbsoluteUrl(
          buildProfilePathFromParts({
            userId: profile.id,
            username: profile.username,
          }),
        ),
        lastModified: profile.lastModified,
        changeFrequency: "weekly" as const,
        priority: 0.58,
      })),
    ];

    const uniqueEntries = new Map<string, MetadataRoute.Sitemap[number]>();

    for (const entry of [...staticEntries, ...dynamicEntries]) {
      uniqueEntries.set(entry.url, entry);
    }

    return [...uniqueEntries.values()];
  } catch {
    return staticEntries;
  }
}
