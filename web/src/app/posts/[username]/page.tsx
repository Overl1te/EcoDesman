import type { Metadata } from "next";
import { notFound, permanentRedirect } from "next/navigation";

import { PostDetailPage } from "@/components/post/post-detail-page";
import { StructuredDataScript } from "@/components/seo/structured-data-script";
import { buildPostPath } from "@/lib/paths";
import { buildPostMetadata, buildPostStructuredData } from "@/lib/post-seo";
import { getServerPost, hasServerAuthSession } from "@/lib/server-api";
import { buildPageMetadata } from "@/lib/seo";

type LegacyPostDetailRouteProps = {
  params: Promise<{ username: string }>;
};

export async function generateMetadata({
  params,
}: LegacyPostDetailRouteProps): Promise<Metadata> {
  const { username } = await params;
  const postId = Number(username);

  if (!Number.isFinite(postId)) {
    return buildPageMetadata({
      title: "Публикация сообщества",
      description:
        "Публичная публикация сообщества ЭкоВыхухоль: детали материала, обсуждение, комментарии и связанные экологические инициативы.",
      path: `/posts/${username}`,
      index: false,
    });
  }

  const post = await getServerPost(postId);
  return post
    ? buildPostMetadata(post)
    : buildPageMetadata({
        title: "Публикация сообщества",
        description:
          "Публичная публикация сообщества ЭкоВыхухоль: детали материала, обсуждение, комментарии и связанные экологические инициативы.",
        path: `/posts/${username}`,
        index: false,
      });
}

export default async function LegacyPostDetailRoutePage({
  params,
}: LegacyPostDetailRouteProps) {
  const { username } = await params;
  const postId = Number(username);

  if (!Number.isFinite(postId)) {
    notFound();
  }

  const post = await getServerPost(postId);

  if (!post) {
    if (!(await hasServerAuthSession())) {
      notFound();
    }

    return <PostDetailPage postId={postId} />;
  }

  const canonicalPath = buildPostPath(post);
  if (canonicalPath === `/posts/${username}`) {
    return (
      <>
        {post.is_published ? (
          <StructuredDataScript data={buildPostStructuredData(post)} />
        ) : null}
        <PostDetailPage postId={post.id} initialPost={post} />
      </>
    );
  }

  permanentRedirect(canonicalPath);
}
