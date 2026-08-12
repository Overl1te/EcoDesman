import type { Metadata } from "next";
import { notFound, permanentRedirect } from "next/navigation";

import { ProfilePage } from "@/components/profile/profile-page";
import { buildProfilePath } from "@/lib/paths";
import {
  getServerPublicProfile,
  getServerPublicProfileByUsername,
} from "@/lib/server-api";
import { buildPageMetadata } from "@/lib/seo";
import type { CurrentUser } from "@/lib/types";

type PublicProfileRouteProps = {
  params: Promise<{ profile: string }>;
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

async function getProfileByPublicSegment(segment: string): Promise<CurrentUser | null> {
  const numericId = Number(segment);
  if (Number.isInteger(numericId) && numericId > 0) {
    return getServerPublicProfile(numericId);
  }

  return getServerPublicProfileByUsername(segment);
}

function buildProfileMetadata(profile: CurrentUser | null, path: string): Metadata {
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
    path: buildProfilePath(profile),
  });
}

export async function generateMetadata({
  params,
}: PublicProfileRouteProps): Promise<Metadata> {
  const { profile: profileSegment } = await params;
  const profile = await getProfileByPublicSegment(profileSegment);
  const path = profile ? buildProfilePath(profile) : `/profiles/${profileSegment}`;
  return buildProfileMetadata(profile, path);
}

export default async function PublicProfileRoutePage({
  params,
}: PublicProfileRouteProps) {
  const { profile: profileSegment } = await params;
  const profile = await getProfileByPublicSegment(profileSegment);

  if (!profile) {
    notFound();
  }

  const canonicalPath = buildProfilePath(profile);
  if (canonicalPath !== `/profiles/${profileSegment}`) {
    permanentRedirect(canonicalPath);
  }

  return <ProfilePage userId={profile.id} />;
}
