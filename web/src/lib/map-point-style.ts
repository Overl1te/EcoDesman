import type { MapPointCategory, MapPointDetail, MapPointSummary } from "@/lib/types";

type MapPointAppearance = {
  color: string;
  haloColor: string;
  strokeColor: string;
  selectedColor: string;
  selectedStrokeColor: string;
};

const defaultAppearance = buildAppearance("#56616F");
const hexColorPattern = /^#[0-9A-F]{6}$/i;

function buildAppearance(color: string): MapPointAppearance {
  return {
    color,
    haloColor: hexToRgba(color, 0.2),
    strokeColor: mixWithWhite(color, 0.74),
    selectedColor: mixWithWhite(color, 0.12),
    selectedStrokeColor: mixWithWhite(color, 0.88),
  };
}

function hexToRgb(hex: string) {
  const normalized = hex.replace("#", "");
  const value = normalized.length === 3
    ? normalized
        .split("")
        .map((part) => `${part}${part}`)
        .join("")
    : normalized;
  const parsed = Number.parseInt(value, 16);
  return {
    r: (parsed >> 16) & 255,
    g: (parsed >> 8) & 255,
    b: parsed & 255,
  };
}

function hexToRgba(hex: string, alpha: number) {
  const { r, g, b } = hexToRgb(hex);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

function mixWithWhite(hex: string, ratio: number) {
  const { r, g, b } = hexToRgb(hex);
  const mixChannel = (channel: number) =>
    Math.round(channel * (1 - ratio) + 255 * ratio);
  const next = [mixChannel(r), mixChannel(g), mixChannel(b)]
    .map((channel) => channel.toString(16).padStart(2, "0"))
    .join("");
  return `#${next}`;
}

export function getCategoryPriority(category?: MapPointCategory | null) {
  if (!category) {
    return Number.NEGATIVE_INFINITY;
  }

  return category.sort_order ?? 0;
}

export function getPrimaryMapCategory(
  point: Pick<MapPointSummary, "categories" | "primary_category"> | Pick<MapPointDetail, "categories" | "primary_category">,
) {
  if (point.primary_category) {
    return point.primary_category;
  }

  return [...point.categories].sort((left, right) => {
    const priorityDiff = getCategoryPriority(right) - getCategoryPriority(left);
    if (priorityDiff !== 0) {
      return priorityDiff;
    }
    return left.title.localeCompare(right.title, "ru");
  })[0] ?? null;
}

export function getMapPointAppearance(category?: MapPointCategory | null) {
  return category?.color ? buildAppearance(category.color) : defaultAppearance;
}

export function resolvePointMarkerColor(
  markerColor?: string | null,
  category?: MapPointCategory | null,
) {
  const pointColor = markerColor?.trim() ?? "";
  if (hexColorPattern.test(pointColor)) {
    return pointColor.toUpperCase();
  }

  const categoryColor = category?.color?.trim() ?? "";
  if (hexColorPattern.test(categoryColor)) {
    return categoryColor.toUpperCase();
  }

  return defaultAppearance.color;
}

export function getMapPointAppearanceForPoint(
  markerColor?: string | null,
  category?: MapPointCategory | null,
) {
  return buildAppearance(resolvePointMarkerColor(markerColor, category));
}
