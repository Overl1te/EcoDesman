"use client";

import { Clock3, ImageIcon, ListFilter, type LucideIcon, Sparkles } from "lucide-react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useTransition } from "react";

import {
  buildFeedFilterSearchParams,
  EVENT_SCOPE_OPTIONS,
  FEED_ORDERING_OPTIONS,
  IMAGE_FILTER_OPTIONS,
  readFeedToolbarState,
  readFeedToolbarStateFromFormData,
} from "@/lib/feed-filters";

interface FeedFiltersProps {
  eventsOnly?: boolean;
}

interface FilterSelectFieldProps {
  defaultValue: string;
  icon: LucideIcon;
  label: string;
  name: string;
  options: ReadonlyArray<{
    value: string;
    label: string;
  }>;
}

function FilterSelectField({
  defaultValue,
  icon: Icon,
  label,
  name,
  options,
}: FilterSelectFieldProps) {
  return (
    <label className="field field-inline filter-field">
      <span className="filter-label">
        <Icon className="meta-icon" />
        <span>{label}</span>
      </span>
      <select name={name} defaultValue={defaultValue}>
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
    </label>
  );
}

export function FeedFilters({ eventsOnly = false }: FeedFiltersProps) {
  const searchParams = useSearchParams();
  const pathname = usePathname();
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const toolbarState = readFeedToolbarState(searchParams, { eventsOnly });

  function applyFeedFilters(formData: FormData) {
    const nextToolbarState = readFeedToolbarStateFromFormData(formData, { eventsOnly });
    const nextSearchParams = buildFeedFilterSearchParams(searchParams, nextToolbarState, {
      eventsOnly,
    });
    const nextQuery = nextSearchParams.toString();

    startTransition(() => {
      router.replace(nextQuery ? `${pathname}?${nextQuery}` : pathname);
    });
  }

  return (
    <form className="filters-toolbar" action={applyFeedFilters}>
      <div className="filters-toolbar-head">
        <div>
          <p className="eyebrow">Фильтры</p>
          <h3>{eventsOnly ? "Настройка событий" : "Настройка ленты"}</h3>
        </div>
        {isPending ? <span className="filters-status">Обновляю...</span> : null}
      </div>

      <div
        className={`filters-toolbar-grid ${
          eventsOnly ? "filters-toolbar-grid-events" : "filters-toolbar-grid-feed"
        }`}
      >
        <FilterSelectField
          defaultValue={toolbarState.ordering}
          icon={Sparkles}
          label="Сортировка"
          name="ordering"
          options={FEED_ORDERING_OPTIONS}
        />

        {eventsOnly ? (
          <FilterSelectField
            defaultValue={toolbarState.eventScope}
            icon={Clock3}
            label="Когда"
            name="event_scope"
            options={EVENT_SCOPE_OPTIONS}
          />
        ) : null}

        <FilterSelectField
          defaultValue={toolbarState.imageFilterMode}
          icon={ImageIcon}
          label="Только с фото"
          name="image_filter"
          options={IMAGE_FILTER_OPTIONS}
        />

        <div className="filter-submit-wrap">
          <button
            type="submit"
            className="button button-primary filter-submit"
            disabled={isPending}
          >
            <ListFilter className="button-icon" />
            <span>Применить</span>
          </button>
        </div>
      </div>
    </form>
  );
}
