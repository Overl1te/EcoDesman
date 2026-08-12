"use client";

import { useSearchParams } from "next/navigation";
import { Suspense, useEffect, useMemo, useState, type ReactNode } from "react";

import { FeedFilters } from "@/components/feed/feed-filters";
import { FeedPagination } from "@/components/feed/feed-pagination";
import { FeedPostList } from "@/components/feed/feed-post-list";
import { TopbarSearch } from "@/components/feed/topbar-search";
import { AppShell } from "@/components/layout/app-shell";
import { useAuth } from "@/components/providers/auth-provider";
import { EmptyState } from "@/components/ui/empty-state";
import { LoadingBlock } from "@/components/ui/loading-block";
import { listPosts } from "@/lib/api";
import { readFeedRequestFilters } from "@/lib/feed-filters";
import type { PaginatedResponse, PostListItem } from "@/lib/types";

const EMPTY_PAGE_RESPONSE: PaginatedResponse<PostListItem> = {
  count: 0,
  next: null,
  previous: null,
  results: [],
};

type FeedPageContentProps = {
  title: string;
  loadingLabel: string;
  emptyStateTitle: string;
  emptyStateDescription: string;
  intro?: ReactNode;
  afterContent?: ReactNode;
  eventsOnly?: boolean;
  kind?: "event";
  favoritesOnly?: boolean;
  requiresAuth?: boolean;
  authReturnTo?: string;
  authTitle?: string;
  authDescription?: string;
  titleTag?: "h1" | "p";
};

export function FeedPageContent({
  title,
  loadingLabel,
  emptyStateTitle,
  emptyStateDescription,
  intro,
  afterContent,
  eventsOnly = false,
  kind,
  favoritesOnly = false,
  requiresAuth = false,
  authReturnTo = "/",
  authTitle = "Нужен вход",
  authDescription = "",
  titleTag = "h1",
}: FeedPageContentProps) {
  return (
    <AppShell
      title={title}
      titleTag={titleTag}
      actions={<TopbarSearch placeholder="Поиск публикаций и авторов" />}
      contentClassName="page-content-feed"
    >
      {intro}
      <div className="feed-main">
        <section className="panel feed-panel">
          <FeedFilters eventsOnly={eventsOnly} />
        </section>

        <Suspense fallback={<LoadingBlock label={loadingLabel} />}>
          <FeedPageResults
            loadingLabel={loadingLabel}
            emptyStateTitle={emptyStateTitle}
            emptyStateDescription={emptyStateDescription}
            eventsOnly={eventsOnly}
            kind={kind}
            favoritesOnly={favoritesOnly}
            requiresAuth={requiresAuth}
            authReturnTo={authReturnTo}
            authTitle={authTitle}
            authDescription={authDescription}
          />
        </Suspense>
      </div>
      {afterContent}
    </AppShell>
  );
}

function FeedPageResults({
  loadingLabel,
  emptyStateTitle,
  emptyStateDescription,
  eventsOnly = false,
  kind,
  favoritesOnly = false,
  requiresAuth = false,
  authReturnTo = "/",
  authTitle = "Нужен вход",
  authDescription = "",
}: Omit<FeedPageContentProps, "intro" | "title">) {
  const searchParams = useSearchParams();
  const { isAuthenticated, openAuthModal } = useAuth();
  const [data, setData] = useState<PaginatedResponse<PostListItem>>(EMPTY_PAGE_RESPONSE);
  const [error, setError] = useState<string | null>(null);
  const [resolvedFiltersKey, setResolvedFiltersKey] = useState<string | null>(null);

  const isAuthBlocked = requiresAuth && !isAuthenticated;

  const filters = useMemo(() => {
    return readFeedRequestFilters(searchParams, {
      eventsOnly,
      favoritesOnly,
      kind,
    });
  }, [eventsOnly, favoritesOnly, kind, searchParams]);

  const filtersKey = useMemo(() => JSON.stringify(filters), [filters]);
  const loading = !isAuthBlocked && resolvedFiltersKey !== filtersKey;
  const visibleError = loading ? null : error;

  useEffect(() => {
    if (isAuthBlocked) {
      return;
    }

    let active = true;

    void listPosts(filters, isAuthenticated || requiresAuth)
      .then((response) => {
        if (!active) {
          return;
        }

        setData(response);
        setError(null);
        setResolvedFiltersKey(filtersKey);
      })
      .catch((nextError: Error) => {
        if (!active) {
          return;
        }

        setError(nextError.message || "Не удалось загрузить ленту");
        setResolvedFiltersKey(filtersKey);
      });

    return () => {
      active = false;
    };
  }, [filters, filtersKey, isAuthenticated, isAuthBlocked, requiresAuth]);

  if (isAuthBlocked) {
    return (
      <EmptyState
        title={authTitle}
        description={authDescription}
        action={
          <button
            type="button"
            className="button button-primary"
            onClick={() => openAuthModal({ returnTo: authReturnTo })}
          >
            Войти
          </button>
        }
      />
    );
  }

  return (
    <>
      {loading ? <LoadingBlock label={loadingLabel} /> : null}
      {visibleError ? (
        <EmptyState title="Ошибка загрузки" description={visibleError} />
      ) : null}

      {!loading && !visibleError ? (
        <>
          <FeedPostList
            posts={data.results}
            emptyStateTitle={emptyStateTitle}
            emptyStateDescription={emptyStateDescription}
            onPostUpdated={(nextPost) => {
              setData((current) => ({
                ...current,
                results: current.results.map((item) =>
                  item.id === nextPost.id ? nextPost : item,
                ),
              }));
            }}
          />

          <FeedPagination
            currentPage={filters.page || 1}
            hasPrevious={Boolean(data.previous)}
            hasNext={Boolean(data.next)}
            searchParamsString={searchParams.toString()}
          />
        </>
      ) : null}
    </>
  );
}
