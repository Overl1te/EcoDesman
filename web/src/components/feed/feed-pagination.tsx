import Link from "next/link";

function buildPageQuery(searchParamsString: string, page: number): string {
  const params = new URLSearchParams(searchParamsString);
  params.set("page", String(page));
  return params.toString();
}

export function FeedPagination({
  currentPage,
  hasPrevious,
  hasNext,
  searchParamsString,
}: {
  currentPage: number;
  hasPrevious: boolean;
  hasNext: boolean;
  searchParamsString: string;
}) {
  if (!hasPrevious && !hasNext) {
    return null;
  }

  return (
    <div className="pagination-row">
      {hasPrevious ? (
        <Link
          href={`?${buildPageQuery(searchParamsString, currentPage - 1)}`}
          className="button button-muted"
        >
          Назад
        </Link>
      ) : (
        <span />
      )}
      <span className="pagination-label">Страница {currentPage}</span>
      {hasNext ? (
        <Link
          href={`?${buildPageQuery(searchParamsString, currentPage + 1)}`}
          className="button button-muted"
        >
          Дальше
        </Link>
      ) : (
        <span />
      )}
    </div>
  );
}
