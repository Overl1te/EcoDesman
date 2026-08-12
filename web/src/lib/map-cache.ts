import type { MapOverviewResponse } from "@/lib/types";

const MAP_OVERVIEW_CACHE_KEY = "eco-vyhuhol-map-overview-v3";
const MAP_OVERVIEW_TTL_MS = 24 * 60 * 60 * 1000;

type MapOverviewCachePayload = {
  cachedAt: number;
  data: MapOverviewResponse;
};

function canUseStorage() {
  return typeof window !== "undefined" && typeof window.localStorage !== "undefined";
}

export function readMapOverviewCache(): MapOverviewResponse | null {
  if (!canUseStorage()) {
    return null;
  }

  try {
    const raw = window.localStorage.getItem(MAP_OVERVIEW_CACHE_KEY);
    if (!raw) {
      return null;
    }

    const parsed = JSON.parse(raw) as MapOverviewCachePayload;
    if (!parsed?.cachedAt || !parsed?.data) {
      window.localStorage.removeItem(MAP_OVERVIEW_CACHE_KEY);
      return null;
    }

    if (Date.now() - parsed.cachedAt > MAP_OVERVIEW_TTL_MS) {
      window.localStorage.removeItem(MAP_OVERVIEW_CACHE_KEY);
      return null;
    }

    return parsed.data;
  } catch {
    window.localStorage.removeItem(MAP_OVERVIEW_CACHE_KEY);
    return null;
  }
}

export function writeMapOverviewCache(data: MapOverviewResponse) {
  if (!canUseStorage()) {
    return;
  }

  const payload: MapOverviewCachePayload = {
    cachedAt: Date.now(),
    data,
  };

  try {
    window.localStorage.setItem(MAP_OVERVIEW_CACHE_KEY, JSON.stringify(payload));
  } catch {
    // ignore quota and private mode failures
  }
}
