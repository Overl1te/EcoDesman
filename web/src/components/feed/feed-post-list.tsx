"use client";

import { PostCard } from "@/components/post/post-card";
import { EmptyState } from "@/components/ui/empty-state";
import type { PostListItem } from "@/lib/types";

export function FeedPostList({
  posts,
  emptyStateTitle,
  emptyStateDescription,
  onPostUpdated,
}: {
  posts: PostListItem[];
  emptyStateTitle: string;
  emptyStateDescription: string;
  onPostUpdated: (nextPost: PostListItem) => void;
}) {
  return (
    <section className="feed-column">
      {posts.length ? (
        posts.map((post) => (
          <PostCard key={post.id} post={post} onUpdated={onPostUpdated} />
        ))
      ) : (
        <EmptyState title={emptyStateTitle} description={emptyStateDescription} />
      )}
    </section>
  );
}
