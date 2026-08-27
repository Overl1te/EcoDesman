import type { Metadata } from "next";
import { notFound, permanentRedirect } from "next/navigation";

import { PostDetailPage } from "@/components/post/post-detail-page";
import { StructuredDataScript } from "@/components/seo/structured-data-script";
import { buildPostPath } from "@/lib/paths";
import { buildPostMetadata, buildPostStructuredData } from "@/lib/post-seo";
import { getServerPostBySlug, hasServerAuthSession } from "@/lib/server-api";
import { buildPageMetadata } from "@/lib/seo";

type PostDetailRouteProps = {
  params: Promise<{ username: string; postSlug: string }>;
};

export async function generateMetadata({
  params,
}: PostDetailRouteProps): Promise<Metadata> {
  const { username, postSlug } = await params;
  const post = await getServerPostBySlug(username, postSlug);
  const path = post ? buildPostPath(post) : `/${username}/posts/${postSlug}`;

  if (!post) {
    return buildPageMetadata({
      title: "Публикация сообщества ЭкоВыхухоль",
      description:
        "Публичная публикация сообщества ЭкоВыхухоль: детали материала, обсуждение, комментарии и связанные экологические инициативы.",
      path,
      index: false,
    });
  }

  return buildPostMetadata(post);
}

export default async function PostDetailRoutePage({
  params,
}: PostDetailRouteProps) {
  const { username, postSlug } = await params;
  const post = await getServerPostBySlug(username, postSlug);

  if (!post) {
    if (!(await hasServerAuthSession())) {
      notFound();
    }

    return <PostDetailPage username={username} postSlug={postSlug} />;
  }

  const canonicalPath = buildPostPath(post);
  if (canonicalPath !== `/${username}/posts/${postSlug}`) {
    permanentRedirect(canonicalPath);
  }

  return (
    <>
      {post.is_published ? (
        <StructuredDataScript data={buildPostStructuredData(post)} />
      ) : null}
      <PostDetailPage postId={post.id} username={username} postSlug={postSlug} initialPost={post} />
    </>
  );
}
