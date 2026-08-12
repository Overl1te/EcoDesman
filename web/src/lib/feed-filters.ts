import type { FeedFilters } from "@/lib/types";

type SearchParamsSource = Pick<URLSearchParams, "get" | "toString">;
type FormDataSource = Pick<FormData, "get">;

export type FeedOrdering = NonNullable<FeedFilters["ordering"]>;
export type EventScope = NonNullable<FeedFilters["event_scope"]>;
export type ImageFilterMode = "all" | "with_images";

export interface FeedSelectOption<Value extends string> {
  value: Value;
  label: string;
}

export interface FeedToolbarState {
  ordering: FeedOrdering;
  eventScope: EventScope;
  imageFilterMode: ImageFilterMode;
}

interface FeedFilterStateOptions {
  eventsOnly?: boolean;
}

interface FeedRequestFilterOptions extends FeedFilterStateOptions {
  favoritesOnly?: boolean;
  kind?: FeedFilters["kind"];
}

const DEFAULT_FEED_ORDERING: FeedOrdering = "recommended";
const DEFAULT_EVENT_SCOPE: EventScope = "all";
const DEFAULT_IMAGE_FILTER_MODE: ImageFilterMode = "all";

export const FEED_ORDERING_OPTIONS: ReadonlyArray<FeedSelectOption<FeedOrdering>> = [
  { value: "recommended", label: "Рекомендации" },
  { value: "recent", label: "Сначала новые" },
  { value: "popular", label: "Популярные" },
];

export const EVENT_SCOPE_OPTIONS: ReadonlyArray<FeedSelectOption<EventScope>> = [
  { value: "all", label: "Все" },
  { value: "today", label: "Сегодня" },
  { value: "week", label: "На неделе" },
  { value: "upcoming", label: "Будущие" },
];

export const IMAGE_FILTER_OPTIONS: ReadonlyArray<FeedSelectOption<ImageFilterMode>> = [
  { value: "all", label: "Все публикации" },
  { value: "with_images", label: "Только с фото" },
];

function normalizeFeedOrdering(value: string | null): FeedOrdering {
  if (value === "recent" || value === "popular") {
    return value;
  }

  return DEFAULT_FEED_ORDERING;
}

function normalizeEventScope(value: string | null): EventScope {
  if (value === "today" || value === "week" || value === "upcoming") {
    return value;
  }

  return DEFAULT_EVENT_SCOPE;
}

function normalizeImageFilterMode(value: string | null): ImageFilterMode {
  return value === "with_images" ? value : DEFAULT_IMAGE_FILTER_MODE;
}

function hasImagesFilterEnabled(value: string | null): boolean {
  return value === "1" || value === "true";
}

function parsePositivePageNumber(value: string | null): number {
  const parsedPage = Number(value || "1");

  if (Number.isFinite(parsedPage) && parsedPage > 0) {
    return parsedPage;
  }

  return 1;
}

function readStringValue(value: FormDataEntryValue | null): string | null {
  return typeof value === "string" ? value : null;
}

export function readFeedToolbarState(
  searchParams: SearchParamsSource,
  options: FeedFilterStateOptions = {},
): FeedToolbarState {
  return {
    ordering: normalizeFeedOrdering(searchParams.get("ordering")),
    eventScope: options.eventsOnly
      ? normalizeEventScope(searchParams.get("event_scope"))
      : DEFAULT_EVENT_SCOPE,
    imageFilterMode: hasImagesFilterEnabled(searchParams.get("has_images"))
      ? "with_images"
      : DEFAULT_IMAGE_FILTER_MODE,
  };
}

export function readFeedToolbarStateFromFormData(
  formData: FormDataSource,
  options: FeedFilterStateOptions = {},
): FeedToolbarState {
  return {
    ordering: normalizeFeedOrdering(readStringValue(formData.get("ordering"))),
    eventScope: options.eventsOnly
      ? normalizeEventScope(readStringValue(formData.get("event_scope")))
      : DEFAULT_EVENT_SCOPE,
    imageFilterMode: normalizeImageFilterMode(readStringValue(formData.get("image_filter"))),
  };
}

export function buildFeedFilterSearchParams(
  searchParams: SearchParamsSource,
  toolbarState: FeedToolbarState,
  options: FeedFilterStateOptions = {},
): URLSearchParams {
  const nextSearchParams = new URLSearchParams(searchParams.toString());

  nextSearchParams.set("ordering", toolbarState.ordering);

  if (toolbarState.imageFilterMode === "with_images") {
    nextSearchParams.set("has_images", "1");
  } else {
    nextSearchParams.delete("has_images");
  }

  if (options.eventsOnly) {
    nextSearchParams.set("event_scope", toolbarState.eventScope);
  } else {
    nextSearchParams.delete("event_scope");
  }

  nextSearchParams.delete("page");

  return nextSearchParams;
}

export function readFeedRequestFilters(
  searchParams: SearchParamsSource,
  options: FeedRequestFilterOptions = {},
): FeedFilters {
  return {
    search: searchParams.get("search") || undefined,
    ordering: normalizeFeedOrdering(searchParams.get("ordering")),
    kind: options.kind,
    favorites_only: options.favoritesOnly,
    has_images: hasImagesFilterEnabled(searchParams.get("has_images")),
    event_scope: options.eventsOnly
      ? normalizeEventScope(searchParams.get("event_scope"))
      : undefined,
    page: parsePositivePageNumber(searchParams.get("page")),
  };
}
