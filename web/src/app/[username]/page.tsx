import type { Metadata } from "next";
import { notFound, permanentRedirect } from "next/navigation";

import { buildProfilePath } from "@/lib/paths";
import { getServerPublicProfileByUsername } from "@/lib/server-api";
import { buildPageMetadata } from "@/lib/seo";

type PublicProfileRouteProps = {
  params: Promise<{ username: string }>;
};

function joinMetaSegments(values: Array<string | undefined>): string {
  return values
    .filter(Boolean)
    .map((value) => value!.trim().replace(/[. ]+$/g, ""))
    .join(". ");
}

function buildExcerpt(value: string, limit = 190): string {
  const normalized = value.replace(/\s+/g, " ").trim();
  if (normalized.length <= limit) {
    return normalized;
  }

  return `${normalized.slice(0, limit - 1).trimEnd()}…`;
}

export async function generateMetadata({
  params,
}: PublicProfileRouteProps): Promise<Metadata> {
  const { username } = await params;
  const profile = await getServerPublicProfileByUsername(username);
  const path = profile ? buildProfilePath(profile) : `/${username}`;

  if (!profile) {
    return buildPageMetadata({
      title: "Профиль участника ЭкоВыхухоль",
      description:
        "Публичный профиль участника ЭкоВыхухоль с публикациями, активностью и вкладом в экологическое сообщество.",
      path,
    });
  }

  const title = `${profile.name || profile.username} — профиль участника ЭкоВыхухоль`;
  const description =
    buildExcerpt(
      joinMetaSegments([
        profile.status_text || undefined,
        profile.bio || undefined,
        profile.city ? `Город: ${profile.city}` : undefined,
        `Публикаций: ${profile.stats.posts_count}`,
      ]),
    ) ||
    "Публичный профиль участника ЭкоВыхухоль с активностью и публикациями сообщества.";

  return buildPageMetadata({
    title,
    description,
    path,
  });
}

export default async function PublicProfileRoutePage({
  params,
}: PublicProfileRouteProps) {
  const { username } = await params;
  const profile = await getServerPublicProfileByUsername(username);

  if (!profile) {
    notFound();
  }

  const canonicalPath = buildProfilePath(profile);
  permanentRedirect(canonicalPath);
}
