import type { Metadata } from "next";
import { notFound, permanentRedirect } from "next/navigation";

import { PostDetailPage } from "@/components/post/post-detail-page";
import { StructuredDataScript } from "@/components/seo/structured-data-script";
import { buildPostPath } from "@/lib/paths";
import { buildPostMetadata, buildPostStructuredData } from "@/lib/post-seo";
import { getServerPostBySlug } from "@/lib/server-api";
import { buildPageMetadata } from "@/lib/seo";

type CanonicalPostRouteProps = {
  params: Promise<{ username: string; postSlug: string }>;
};

export async function generateMetadata({
  params,
}: CanonicalPostRouteProps): Promise<Metadata> {
  const { username, postSlug } = await params;
  const post = await getServerPostBySlug(username, postSlug);
  const path = post ? buildPostPath(post) : `/posts/${username}/${postSlug}`;

  if (!post) {
    return buildPageMetadata({
      title: "Публикация сообщества ЭкоВыхухоль",
      description:
        "Публичная публикация сообщества ЭкоВыхухоль: детали материала, обсуждение, комментарии и связанные экологические инициативы.",
      path,
    });
  }

  return buildPostMetadata(post);
}

export default async function CanonicalPostRoutePage({
  params,
}: CanonicalPostRouteProps) {
  const { username, postSlug } = await params;
  const post = await getServerPostBySlug(username, postSlug);

  if (!post) {
    notFound();
  }

  const canonicalPath = buildPostPath(post);
  if (canonicalPath !== `/posts/${username}/${postSlug}`) {
    permanentRedirect(canonicalPath);
  }

  return (
    <>
      <StructuredDataScript data={buildPostStructuredData(post)} />
      <PostDetailPage postId={post.id} initialPost={post} />
    </>
  );
}
