"use client";

import maplibregl, {
  type GeoJSONSource,
  type LngLatBoundsLike,
  type Map as MapLibreMap,
  type MapGeoJSONFeature,
} from "maplibre-gl";
import {
  Cuboid,
  Clock3,
  Eye,
  EyeOff,
  Filter,
  MapPin,
  MessageSquarePlus,
  Plus,
  Send,
  Star,
  X,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react";

import { AppShell } from "@/components/layout/app-shell";
import { useAuth } from "@/components/providers/auth-provider";
import { ReportContentButton } from "@/components/support/report-content-button";
import { useThemeMode } from "@/components/providers/theme-provider";
import { EmptyState } from "@/components/ui/empty-state";
import { ImageDropzone } from "@/components/ui/image-dropzone";
import { LoadingBlock } from "@/components/ui/loading-block";
import {
  createUserMapMarker,
  createUserMapMarkerComment,
  createUserMapMarkerCommentReport,
  createUserMapMarkerReport,
  createMapReviewReport,
  createMapPointReview,
  getMapOverview,
  getMapPointDetail,
  getUserMapMarkerDetail,
  uploadImages,
  uploadMedia,
} from "@/lib/api";
import { formatDateTime } from "@/lib/format";
import { readMapOverviewCache, writeMapOverviewCache } from "@/lib/map-cache";
import {
  getCategoryPriority,
  getMapPointAppearance,
  getMapPointAppearanceForPoint,
  getPrimaryMapCategory,
} from "@/lib/map-point-style";
import { getMapStyle } from "@/lib/map-style";
import type {
  MapOverviewResponse,
  MapPointDetail,
  MapPointSummary,
  UserMapMarkerDetail,
  UserMapMarkerSummary,
} from "@/lib/types";

const pointSourceId = "eco-map-points";
const pointHaloLayerId = "eco-map-points-halo";
const pointLayerId = "eco-map-points";
const userMarkerSourceId = "eco-user-map-markers";
const userMarkerHaloLayerId = "eco-user-map-markers-halo";
const userMarkerLayerId = "eco-user-map-markers";
const userMarkerDraftSourceId = "eco-user-map-marker-draft";
const userMarkerDraftHaloLayerId = "eco-user-map-marker-draft-halo";
const userMarkerDraftLayerId = "eco-user-map-marker-draft";
const userMarkerColor = "#2563EB";
const userMarkerHaloColor = "rgba(37, 99, 235, 0.22)";
const userMarkerStrokeColor = "#DCEBFF";
const userMarkerSelectedColor = "#1D4ED8";
const userMarkerSelectedStrokeColor = "#F8FBFF";
const userMarkerDraftColor = "#0EA5E9";
const userMarkerDraftHaloColor = "rgba(14, 165, 233, 0.24)";
const userMarkersVisibilityStorageKey = "eco-map-show-user-markers";
const nizhnyCenter: [number, number] = [43.974881, 56.315048];
const nizhnyZoom = 11.8;
const twoDimensionalPitch = 0;
const threeDimensionalPitch = 52;
const threeDimensionalBearing = -16;

type PointFeatureProperties = {
  id: number;
  title: string;
  isSelected: boolean;
  color: string;
  haloColor: string;
  strokeColor: string;
  selectedColor: string;
  selectedStrokeColor: string;
};

type UserMarkerFeatureProperties = {
  id: number;
  title: string;
  isSelected: boolean;
};

type DraftMarkerFeatureProperties = {
  title: string;
};

function buildErrorMessage(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback;
}

function buildPointsGeoJson(points: MapPointSummary[], selectedId?: number | null): GeoJSON.FeatureCollection<GeoJSON.Point, PointFeatureProperties> {
  return {
    type: "FeatureCollection",
    features: points.map((point) => {
      const appearance = getMapPointAppearanceForPoint(
        point.marker_color,
        getPrimaryMapCategory(point),
      );
      return {
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: [point.longitude, point.latitude],
        },
        properties: {
          id: point.id,
          title: point.title,
          isSelected: point.id === selectedId,
          color: appearance.color,
          haloColor: appearance.haloColor,
          strokeColor: appearance.strokeColor,
          selectedColor: appearance.selectedColor,
          selectedStrokeColor: appearance.selectedStrokeColor,
        },
      };
    }),
  };
}

function buildUserMarkersGeoJson(
  markers: UserMapMarkerSummary[],
  selectedId?: number | null,
): GeoJSON.FeatureCollection<GeoJSON.Point, UserMarkerFeatureProperties> {
  return {
    type: "FeatureCollection",
    features: markers.map((marker) => ({
      type: "Feature",
      geometry: {
        type: "Point",
        coordinates: [marker.longitude, marker.latitude],
      },
      properties: {
        id: marker.id,
        title: marker.title,
        isSelected: marker.id === selectedId,
      },
    })),
  };
}

function buildUserMarkerDraftGeoJson(
  coordinates: [number, number] | null,
): GeoJSON.FeatureCollection<GeoJSON.Point, DraftMarkerFeatureProperties> {
  return {
    type: "FeatureCollection",
    features: coordinates
      ? [
          {
            type: "Feature",
            geometry: {
              type: "Point",
              coordinates,
            },
            properties: {
              title: "Новая метка",
            },
          },
        ]
      : [],
  };
}

function readInitialUserMarkersVisibility() {
  if (typeof window === "undefined") {
    return true;
  }

  return window.localStorage.getItem(userMarkersVisibilityStorageKey) !== "false";
}

export function MapPage({
  intro,
  afterContent,
}: {
  intro?: ReactNode;
  afterContent?: ReactNode;
}) {
  const { isAuthenticated, openAuthModal } = useAuth();
  const { mode } = useThemeMode();
  const [overview, setOverview] = useState<MapOverviewResponse | null>(null);
  const [selected, setSelected] = useState<MapPointDetail | null>(null);
  const [selectedUserMarker, setSelectedUserMarker] = useState<UserMapMarkerDetail | null>(null);
  const [activeCategory, setActiveCategory] = useState("");
  const [loading, setLoading] = useState(true);
  const [detailLoading, setDetailLoading] = useState(false);
  const [userMarkerDetailLoading, setUserMarkerDetailLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [reviewFormOpen, setReviewFormOpen] = useState(false);
  const [reviewRating, setReviewRating] = useState(5);
  const [reviewBody, setReviewBody] = useState("");
  const [reviewImages, setReviewImages] = useState<File[]>([]);
  const [reviewBusy, setReviewBusy] = useState(false);
  const [reviewError, setReviewError] = useState<string | null>(null);
  const [mapReady, setMapReady] = useState(false);
  const [filtersExpanded, setFiltersExpanded] = useState(true);
  const [isThreeDimensional, setIsThreeDimensional] = useState(false);
  const [showUserMarkers, setShowUserMarkers] = useState(readInitialUserMarkersVisibility);
  const [markerAddMode, setMarkerAddMode] = useState(false);
  const [markerDraftCoords, setMarkerDraftCoords] = useState<[number, number] | null>(null);
  const [markerTitle, setMarkerTitle] = useState("");
  const [markerDescription, setMarkerDescription] = useState("");
  const [markerIsPublic, setMarkerIsPublic] = useState(true);
  const [markerFiles, setMarkerFiles] = useState<File[]>([]);
  const [markerBusy, setMarkerBusy] = useState(false);
  const [markerError, setMarkerError] = useState<string | null>(null);
  const [markerCommentFormOpen, setMarkerCommentFormOpen] = useState(false);
  const [markerCommentBody, setMarkerCommentBody] = useState("");
  const [markerCommentBusy, setMarkerCommentBusy] = useState(false);
  const [markerCommentError, setMarkerCommentError] = useState<string | null>(null);
  const mapRef = useRef<HTMLDivElement | null>(null);
  const mapInstanceRef = useRef<MapLibreMap | null>(null);
  const visiblePointsRef = useRef<MapPointSummary[]>([]);
  const visibleUserMarkersRef = useRef<UserMapMarkerSummary[]>([]);
  const selectedIdRef = useRef<number | null>(null);
  const selectedUserMarkerIdRef = useRef<number | null>(null);
  const markerAddModeRef = useRef(false);
  const markerDraftCoordsRef = useRef<[number, number] | null>(null);

  const resetReviewForm = useCallback(() => {
    setReviewFormOpen(false);
    setReviewRating(5);
    setReviewBody("");
    setReviewImages([]);
    setReviewError(null);
  }, []);

  const resetMarkerForm = useCallback(() => {
    setMarkerDraftCoords(null);
    setMarkerTitle("");
    setMarkerDescription("");
    setMarkerIsPublic(true);
    setMarkerFiles([]);
    setMarkerError(null);
  }, []);

  const refreshOverview = useCallback(async () => {
    const response = await getMapOverview();
    setOverview(response);
    writeMapOverviewCache(response);
    return response;
  }, []);

  const loadPointDetail = useCallback(async (pointId: number) => {
    const point = await getMapPointDetail(pointId);
    setSelected(point);
    setSelectedUserMarker(null);
    return point;
  }, []);

  const loadUserMarkerDetail = useCallback(async (markerId: number) => {
    const marker = await getUserMapMarkerDetail(markerId);
    setSelectedUserMarker(marker);
    setSelected(null);
    return marker;
  }, []);

  const openPoint = useCallback(
    async (pointId: number) => {
      setDetailLoading(true);
      setError(null);

      try {
        await loadPointDetail(pointId);
      } catch (nextError) {
        setError(buildErrorMessage(nextError, "Не удалось открыть точку"));
      } finally {
        setDetailLoading(false);
      }
    },
    [loadPointDetail],
  );

  const openUserMarker = useCallback(
    async (markerId: number) => {
      setUserMarkerDetailLoading(true);
      setError(null);

      try {
        await loadUserMarkerDetail(markerId);
      } catch (nextError) {
        setError(buildErrorMessage(nextError, "Не удалось открыть пользовательскую метку"));
      } finally {
        setUserMarkerDetailLoading(false);
      }
    },
    [loadUserMarkerDetail],
  );

  useEffect(() => {
    let active = true;
    const cachedOverview = readMapOverviewCache();

    if (cachedOverview) {
      setOverview(cachedOverview);
      setLoading(false);
    }

    void refreshOverview()
      .then(() => {
        if (!active) {
          return;
        }

        setError(null);
      })
      .catch((nextError) => {
        if (!active) {
          return;
        }

        if (!cachedOverview) {
          setError(buildErrorMessage(nextError, "Не удалось загрузить карту"));
        }
      })
      .finally(() => {
        if (active) {
          setLoading(false);
        }
      });

    return () => {
      active = false;
    };
  }, [refreshOverview]);

  useEffect(() => {
    resetReviewForm();
  }, [resetReviewForm, selected?.id]);

  useEffect(() => {
    setMarkerCommentFormOpen(false);
    setMarkerCommentBody("");
    setMarkerCommentError(null);
  }, [selectedUserMarker?.id]);

  useEffect(() => {
    markerAddModeRef.current = markerAddMode;
  }, [markerAddMode]);

  useEffect(() => {
    markerDraftCoordsRef.current = markerDraftCoords;
  }, [markerDraftCoords]);

  useEffect(() => {
    window.localStorage.setItem(
      userMarkersVisibilityStorageKey,
      String(showUserMarkers),
    );
  }, [showUserMarkers]);

  const visiblePoints = useMemo(() => {
    if (!overview) {
      return [];
    }

    if (!activeCategory) {
      return overview.points;
    }

    return overview.points.filter((point) =>
      point.categories.some((category) => category.slug === activeCategory),
    );
  }, [activeCategory, overview]);

  const visibleUserMarkers = useMemo(() => {
    if (!overview || !showUserMarkers) {
      return [];
    }

    return overview.user_markers ?? [];
  }, [overview, showUserMarkers]);

  const filterOptions = useMemo(() => {
    if (!overview) {
      return [];
    }

    return [...overview.categories]
      .sort((left, right) => {
        const priorityDiff = getCategoryPriority(right) - getCategoryPriority(left);
        if (priorityDiff !== 0) {
          return priorityDiff;
        }
        return left.title.localeCompare(right.title, "ru");
      })
      .map((category) => ({
        ...category,
        appearance: getMapPointAppearance(category),
        count: overview.points.filter((point) =>
          point.categories.some((item) => item.slug === category.slug),
        ).length,
      }));
  }, [overview]);

  const selectedCategoryTitle = useMemo(() => {
    if (!overview || !activeCategory) {
      return "Все точки";
    }

    return (
      overview.categories.find((category) => category.slug === activeCategory)?.title ??
      "Фильтры"
    );
  }, [activeCategory, overview]);

  const visibleMapItemsCount = visiblePoints.length + visibleUserMarkers.length;

  useEffect(() => {
    visiblePointsRef.current = visiblePoints;
    visibleUserMarkersRef.current = visibleUserMarkers;
    selectedIdRef.current = selected?.id ?? null;
    selectedUserMarkerIdRef.current = selectedUserMarker?.id ?? null;
  }, [selected?.id, selectedUserMarker?.id, visiblePoints, visibleUserMarkers]);

  useEffect(() => {
    if (!selected || !activeCategory) {
      return;
    }

    const matchesFilter = selected.categories.some(
      (category) => category.slug === activeCategory,
    );

    if (!matchesFilter) {
      setSelected(null);
    }
  }, [activeCategory, selected]);

  function removeReviewImage(index: number) {
    setReviewImages((current) => current.filter((_, currentIndex) => currentIndex !== index));
  }

  async function submitReview() {
    if (!selected) {
      return;
    }

    if (!isAuthenticated) {
      openAuthModal({ returnTo: "/map" });
      return;
    }

    const body = reviewBody.trim();
    if (body.length < 3) {
      setReviewError("Напишите хотя бы несколько слов об этой точке.");
      return;
    }

    setReviewBusy(true);
    setReviewError(null);

    try {
      const imageUrls = reviewImages.length ? await uploadImages(reviewImages) : [];
      await createMapPointReview(selected.id, {
        rating: reviewRating,
        body,
        image_urls: imageUrls,
      });
      await loadPointDetail(selected.id);
      resetReviewForm();
    } catch (nextError) {
      setReviewError(buildErrorMessage(nextError, "Не удалось отправить отзыв"));
    } finally {
      setReviewBusy(false);
    }
  }

  function removeMarkerFile(index: number) {
    setMarkerFiles((current) => current.filter((_, currentIndex) => currentIndex !== index));
  }

  async function submitUserMarker() {
    if (!markerDraftCoords) {
      return;
    }

    if (!isAuthenticated) {
      openAuthModal({ returnTo: "/map" });
      return;
    }

    const title = markerTitle.trim();
    const description = markerDescription.trim();
    if (title.length < 3) {
      setMarkerError("Добавьте короткое название места.");
      return;
    }
    if (description.length < 3) {
      setMarkerError("Опишите, что там интересного.");
      return;
    }

    setMarkerBusy(true);
    setMarkerError(null);

    try {
      const media = markerFiles.length ? await uploadMedia(markerFiles) : [];
      const marker = await createUserMapMarker({
        title,
        description,
        latitude: markerDraftCoords[1],
        longitude: markerDraftCoords[0],
        is_public: markerIsPublic,
        media,
      });
      await refreshOverview();
      setSelectedUserMarker(marker);
      setSelected(null);
      setMarkerAddMode(false);
      resetMarkerForm();
    } catch (nextError) {
      setMarkerError(buildErrorMessage(nextError, "Не удалось создать метку"));
    } finally {
      setMarkerBusy(false);
    }
  }

  async function submitMarkerComment() {
    if (!selectedUserMarker) {
      return;
    }

    if (!isAuthenticated) {
      openAuthModal({ returnTo: "/map" });
      return;
    }

    const body = markerCommentBody.trim();
    if (body.length < 2) {
      setMarkerCommentError("Напишите комментарий.");
      return;
    }

    setMarkerCommentBusy(true);
    setMarkerCommentError(null);

    try {
      await createUserMapMarkerComment(selectedUserMarker.id, body);
      await loadUserMarkerDetail(selectedUserMarker.id);
      setMarkerCommentBody("");
      setMarkerCommentFormOpen(false);
    } catch (nextError) {
      setMarkerCommentError(buildErrorMessage(nextError, "Не удалось отправить комментарий"));
    } finally {
      setMarkerCommentBusy(false);
    }
  }

  useEffect(() => {
    let cancelled = false;
    let resizeObserver: ResizeObserver | null = null;

    const setupMap = async () => {
      if (!overview || !mapRef.current || mapInstanceRef.current) {
        return;
      }

      try {
        const bounds: LngLatBoundsLike = [
          [overview.bounds.west, overview.bounds.south],
          [overview.bounds.east, overview.bounds.north],
        ];
        const mapStyle = await getMapStyle(mode);

        if (cancelled) {
          return;
        }

        const map = new maplibregl.Map({
          container: mapRef.current,
          style: mapStyle,
          center: nizhnyCenter,
          zoom: nizhnyZoom,
          pitch: twoDimensionalPitch,
          bearing: 0,
          maxPitch: 60,
          attributionControl: false,
          maxBounds: bounds,
          renderWorldCopies: false,
        });

        map.addControl(
          new maplibregl.NavigationControl({
            showCompass: false,
            visualizePitch: false,
          }),
          "bottom-right",
        );

        let hasInitializedMapLayers = false;
        const initializeMapLayers = () => {
          if (cancelled || hasInitializedMapLayers) {
            return;
          }

          hasInitializedMapLayers = true;

          map.addSource(pointSourceId, {
            type: "geojson",
            data: buildPointsGeoJson(
              visiblePointsRef.current,
              selectedIdRef.current,
            ),
          });
          map.addSource(userMarkerSourceId, {
            type: "geojson",
            data: buildUserMarkersGeoJson(
              visibleUserMarkersRef.current,
              selectedUserMarkerIdRef.current,
            ),
          });
          map.addSource(userMarkerDraftSourceId, {
            type: "geojson",
            data: buildUserMarkerDraftGeoJson(markerDraftCoordsRef.current),
          });

          map.addLayer({
            id: pointHaloLayerId,
            type: "circle",
            source: pointSourceId,
            paint: {
              "circle-radius": [
                "case",
                ["boolean", ["get", "isSelected"], false],
                19,
                15,
              ],
              "circle-color": ["get", "haloColor"],
            },
          });

          map.addLayer({
            id: pointLayerId,
            type: "circle",
            source: pointSourceId,
            paint: {
              "circle-radius": [
                "case",
                ["boolean", ["get", "isSelected"], false],
                10.5,
                8.5,
              ],
              "circle-color": [
                "case",
                ["boolean", ["get", "isSelected"], false],
                ["get", "selectedColor"],
                ["get", "color"],
              ],
              "circle-stroke-width": [
                "case",
                ["boolean", ["get", "isSelected"], false],
                3,
                2,
              ],
              "circle-stroke-color": [
                "case",
                ["boolean", ["get", "isSelected"], false],
                ["get", "selectedStrokeColor"],
                ["get", "strokeColor"],
              ],
            },
          });
          map.addLayer({
            id: userMarkerHaloLayerId,
            type: "circle",
            source: userMarkerSourceId,
            paint: {
              "circle-radius": [
                "case",
                ["boolean", ["get", "isSelected"], false],
                20,
                15,
              ],
              "circle-color": userMarkerHaloColor,
            },
          });

          map.addLayer({
            id: userMarkerLayerId,
            type: "circle",
            source: userMarkerSourceId,
            paint: {
              "circle-radius": [
                "case",
                ["boolean", ["get", "isSelected"], false],
                10.5,
                8.5,
              ],
              "circle-color": [
                "case",
                ["boolean", ["get", "isSelected"], false],
                userMarkerSelectedColor,
                userMarkerColor,
              ],
              "circle-stroke-width": [
                "case",
                ["boolean", ["get", "isSelected"], false],
                3,
                2,
              ],
              "circle-stroke-color": [
                "case",
                ["boolean", ["get", "isSelected"], false],
                userMarkerSelectedStrokeColor,
                userMarkerStrokeColor,
              ],
            },
          });
          map.addLayer({
            id: userMarkerDraftHaloLayerId,
            type: "circle",
            source: userMarkerDraftSourceId,
            paint: {
              "circle-radius": 22,
              "circle-color": userMarkerDraftHaloColor,
              "circle-blur": 0.18,
            },
          });

          map.addLayer({
            id: userMarkerDraftLayerId,
            type: "circle",
            source: userMarkerDraftSourceId,
            paint: {
              "circle-radius": 10.5,
              "circle-color": userMarkerDraftColor,
              "circle-stroke-width": 3,
              "circle-stroke-color": "#FFFFFF",
            },
          });

          map.on("mouseenter", pointLayerId, () => {
            map.getCanvas().style.cursor = "pointer";
          });
          map.on("mouseenter", userMarkerLayerId, () => {
            map.getCanvas().style.cursor = "pointer";
          });

          map.on("mouseleave", pointLayerId, () => {
            map.getCanvas().style.cursor = "";
          });
          map.on("mouseleave", userMarkerLayerId, () => {
            map.getCanvas().style.cursor = "";
          });

          map.on("click", pointLayerId, (event) => {
            if (markerAddModeRef.current) {
              return;
            }
            const feature = event.features?.[0] as MapGeoJSONFeature | undefined;
            const pointId = Number(feature?.properties?.id);
            if (!Number.isNaN(pointId)) {
              void openPoint(pointId);
            }
          });
          map.on("click", userMarkerLayerId, (event) => {
            if (markerAddModeRef.current) {
              return;
            }
            const feature = event.features?.[0] as MapGeoJSONFeature | undefined;
            const markerId = Number(feature?.properties?.id);
            if (!Number.isNaN(markerId)) {
              void openUserMarker(markerId);
            }
          });
          map.on("click", (event) => {
            if (!markerAddModeRef.current) {
              return;
            }
            setSelected(null);
            setSelectedUserMarker(null);
            const coordinates: [number, number] = [event.lngLat.lng, event.lngLat.lat];
            setMarkerDraftCoords(coordinates);
            setMarkerError(null);
            map.easeTo({
              center: coordinates,
              zoom: Math.max(map.getZoom(), 14.2),
              pitch: twoDimensionalPitch,
              bearing: 0,
              duration: 520,
            });
          });

          setMapReady(true);
          requestAnimationFrame(() => {
            map.resize();
          });
        };

        map.once("style.load", initializeMapLayers);
        map.once("load", initializeMapLayers);
        if (map.isStyleLoaded()) {
          initializeMapLayers();
        }

        map.on("error", (event) => {
          console.error("maplibre-error", event.error);
        });

        resizeObserver = new ResizeObserver(() => {
          map.resize();
        });
        resizeObserver.observe(mapRef.current);

        mapInstanceRef.current = map;
      } catch (nextError) {
        console.error("maplibre-init-error", nextError);
        if (!cancelled) {
          setError(buildErrorMessage(nextError, "Не удалось инициализировать карту"));
        }
      }
    };

    void setupMap();

    return () => {
      cancelled = true;
      resizeObserver?.disconnect();
      mapInstanceRef.current?.remove();
      mapInstanceRef.current = null;
      setMapReady(false);
    };
  }, [mode, openPoint, openUserMarker, overview]);

  useEffect(() => {
    const map = mapInstanceRef.current;
    if (!mapReady || !map) {
      return;
    }

    const source = map.getSource(pointSourceId) as GeoJSONSource | undefined;
    source?.setData(buildPointsGeoJson(visiblePoints, selected?.id));
  }, [mapReady, selected?.id, visiblePoints]);

  useEffect(() => {
    const map = mapInstanceRef.current;
    if (!mapReady || !map) {
      return;
    }

    const source = map.getSource(userMarkerSourceId) as GeoJSONSource | undefined;
    source?.setData(buildUserMarkersGeoJson(visibleUserMarkers, selectedUserMarker?.id));
  }, [mapReady, selectedUserMarker?.id, visibleUserMarkers]);

  useEffect(() => {
    const map = mapInstanceRef.current;
    if (!mapReady || !map) {
      return;
    }

    const source = map.getSource(userMarkerDraftSourceId) as GeoJSONSource | undefined;
    source?.setData(buildUserMarkerDraftGeoJson(markerDraftCoords));
  }, [mapReady, markerDraftCoords]);

  useEffect(() => {
    const map = mapInstanceRef.current;
    if (!mapReady || !map) {
      return;
    }

    const focusedItem = selected ?? selectedUserMarker;

    if (focusedItem) {
      map.easeTo({
        center: [focusedItem.longitude, focusedItem.latitude],
        zoom: 13.6,
        duration: 600,
      });
      return;
    }

    map.easeTo({
      center: nizhnyCenter,
      zoom: nizhnyZoom,
      duration: 600,
    });
  }, [mapReady, selected, selectedUserMarker]);

  useEffect(() => {
    const map = mapInstanceRef.current;
    if (!mapReady || !map) {
      return;
    }

    map.easeTo({
      pitch: isThreeDimensional ? threeDimensionalPitch : twoDimensionalPitch,
      bearing: isThreeDimensional ? threeDimensionalBearing : 0,
      duration: 700,
    });
  }, [isThreeDimensional, mapReady]);

  return (
    <AppShell title="Карта" titleTag="p" contentClassName="page-content-map">
      {intro}
      {loading ? <LoadingBlock label="Загружаю карту..." /> : null}
      {error ? <EmptyState title="Ошибка загрузки карты" description={error} /> : null}

      {!loading && !error && overview ? (
        <section className="map-stage">
          <div ref={mapRef} className="map-canvas map-canvas-full" />

          {!mapReady ? (
            <div className="map-loading-overlay">
              <LoadingBlock label="Поднимаю карту..." />
            </div>
          ) : null}

          <div className={`map-toolbar ${filtersExpanded ? "" : "is-collapsed"}`}>
            <div className="map-toolbar-header">
              <div className="map-toolbar-header-copy">
                <strong className="map-toolbar-title">
                  {`${selectedCategoryTitle} · ${visibleMapItemsCount} объектов`}
                </strong>
                <p className="eyebrow map-toolbar-label">Фильтры</p>
              </div>
              <div className="map-toolbar-actions">
                <button
                  type="button"
                  className="button button-muted button-inline map-toolbar-mode"
                  aria-label={
                    isThreeDimensional
                      ? "Переключить карту в 2D"
                      : "Переключить карту в 3D"
                  }
                  onClick={() => setIsThreeDimensional((current) => !current)}
                >
                  <Cuboid className="button-icon" />
                  <span>{isThreeDimensional ? "3D" : "2D"}</span>
                </button>
                <button
                  type="button"
                  className={`button button-inline ${markerAddMode ? "button-primary" : "button-muted"} map-toolbar-mode`}
                  onClick={() => {
                    if (!isAuthenticated) {
                      openAuthModal({ returnTo: "/map" });
                      return;
                    }
                    setMarkerAddMode((current) => !current);
                    resetMarkerForm();
                    setSelected(null);
                    setSelectedUserMarker(null);
                  }}
                >
                  <Plus className="button-icon" />
                  <span>{markerAddMode ? "Выберите точку" : "Место"}</span>
                </button>
                <button
                  type="button"
                  className="icon-button icon-button-muted map-toolbar-toggle"
                  aria-label={filtersExpanded ? "Скрыть фильтры" : "Показать фильтры"}
                  aria-controls="map-filter-grid"
                  aria-expanded={filtersExpanded}
                  onClick={() => setFiltersExpanded((current) => !current)}
                >
                  <Filter className="nav-icon" />
                </button>
              </div>
            </div>

            {filtersExpanded ? (
              <div id="map-filter-grid" className="map-filter-grid">
                <button
                  type="button"
                  className={`map-filter-pill ${activeCategory === "" ? "is-active" : ""}`}
                  onClick={() => setActiveCategory("")}
                >
                  <span
                    className="map-filter-pill-swatch"
                    style={{ backgroundColor: "#56616F" }}
                    aria-hidden="true"
                  />
                  <span>Все</span>
                  <strong>{overview.points.length}</strong>
                </button>

                <button
                  type="button"
                  className={`map-filter-pill ${showUserMarkers ? "is-active" : ""}`}
                  onClick={() => {
                    setShowUserMarkers((current) => !current);
                    setSelectedUserMarker(null);
                  }}
                >
                  <span
                    className="map-filter-pill-swatch"
                    style={{ backgroundColor: userMarkerColor }}
                    aria-hidden="true"
                  />
                  <span>Метки людей</span>
                  <strong>{overview.user_markers?.length ?? 0}</strong>
                  {showUserMarkers ? (
                    <Eye className="button-icon" aria-hidden="true" />
                  ) : (
                    <EyeOff className="button-icon" aria-hidden="true" />
                  )}
                </button>

                {filterOptions.map((category) => (
                  <button
                    key={category.id}
                    type="button"
                    className={`map-filter-pill ${
                      activeCategory === category.slug ? "is-active" : ""
                    }`}
                    onClick={() => setActiveCategory(category.slug)}
                  >
                    <span
                      className="map-filter-pill-swatch"
                      style={{ backgroundColor: category.appearance.color }}
                      aria-hidden="true"
                    />
                    <span>{category.title}</span>
                    <strong>{category.count}</strong>
                  </button>
                ))}
              </div>
            ) : null}
          </div>

          <div className="map-hint">
            <span className="map-hint-dot" />
            <span>
              {markerAddMode
                ? markerDraftCoords
                  ? "Место выбрано, заполните карточку"
                  : "Нажмите на карту, чтобы поставить пользовательскую метку"
                : "Нажмите на точку, чтобы открыть подробности"}
            </span>
          </div>

          <div className="map-attribution" aria-label="Атрибуция карты">
            <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noreferrer">
              © OpenStreetMap
            </a>
          </div>

          {selected || detailLoading ? (
            <aside className={`map-detail-overlay ${selected ? "is-open" : ""}`}>
              <div className="map-detail-header">
                <div>
                  <p className="eyebrow">Точка</p>
                  <h3>{selected?.title || "Загружаю..."}</h3>
                </div>
                <button
                  type="button"
                  className="icon-button icon-button-muted"
                  aria-label="Закрыть карточку точки"
                  onClick={() => setSelected(null)}
                >
                  <X className="nav-icon" />
                </button>
              </div>

              {detailLoading && !selected ? (
                <LoadingBlock label="Открываю точку..." />
              ) : selected ? (
                <div className="map-detail-content">

                  {selected.images.length ? (
                    <div className="map-gallery-grid">
                      {selected.images.map((image) => (
                        <a key={image.id} href={image.image_url} target="_blank" rel="noreferrer">
                          {/* eslint-disable-next-line @next/next/no-img-element */}
                          <img
                            src={image.image_url}
                            alt={image.caption || selected.title}
                            className="gallery-image"
                          />
                        </a>
                      ))}
                    </div>
                  ) : null}

                  <p className="muted">{selected.short_description}</p>

                  {selected.categories.length ? (
                    <div className="map-category-row" aria-label="Категории точки">
                      {selected.categories.map((category) => {
                        const appearance = getMapPointAppearance(category);

                        return (
                          <span
                            key={category.id}
                            className="map-category-chip"
                            style={{
                              borderColor: appearance.color,
                              backgroundColor: appearance.haloColor,
                            }}
                          >
                            <span
                              className="map-category-chip-dot"
                              style={{ backgroundColor: appearance.color }}
                              aria-hidden="true"
                            />
                            {category.title}
                          </span>
                        );
                      })}
                    </div>
                  ) : null}

                  <p className="map-detail-text">{selected.description}</p>

                  <div className="map-detail-meta">
                    {selected.address ? (
                      <div className="map-meta-row">
                        <MapPin className="nav-icon" />
                        <span>{selected.address}</span>
                      </div>
                    ) : null}
                    {selected.working_hours ? (
                      <div className="map-meta-row">
                        <Clock3 className="nav-icon" />
                        <span>{selected.working_hours}</span>
                      </div>
                    ) : null}
                  </div>

                  <div className="section-row">
                    <h4>Отзывы</h4>
                    <button
                      type="button"
                      className="button button-muted button-inline"
                      onClick={() => {
                        if (!isAuthenticated) {
                          openAuthModal({ returnTo: "/map" });
                          return;
                        }
                        setReviewFormOpen((current) => !current);
                        setReviewError(null);
                      }}
                    >
                      <MessageSquarePlus className="button-icon" />
                      <span>{reviewFormOpen ? "Скрыть форму" : "Добавить отзыв"}</span>
                    </button>
                  </div>

                  {reviewFormOpen ? (
                    <div className="panel stack-list map-review-form">
                      <div className="map-review-stars" role="radiogroup" aria-label="Оценка">
                        {Array.from({ length: 5 }, (_, index) => {
                          const value = index + 1;
                          const active = value <= reviewRating;

                          return (
                            <button
                              key={value}
                              type="button"
                              className={`map-review-star ${active ? "is-active" : ""}`}
                              onClick={() => setReviewRating(value)}
                              aria-label={`Оценка ${value}`}
                            >
                              <Star className="review-rating-icon" />
                            </button>
                          );
                        })}
                      </div>

                      <label className="field">
                        <span>Ваш отзыв</span>
                        <textarea
                          value={reviewBody}
                          onChange={(event) => setReviewBody(event.target.value)}
                          placeholder="Напишите, что понравилось или что стоит улучшить"
                        />
                      </label>

                      <ImageDropzone
                        title="Фотографии места"
                        description="Можно приложить несколько снимков к отзыву."
                        files={reviewImages}
                        disabled={reviewBusy}
                        browseLabel={reviewImages.length ? "Добавить ещё" : "Добавить фото"}
                        onAddFiles={(nextFiles) => {
                          setReviewImages((current) => [...current, ...nextFiles]);
                        }}
                        onRemoveFile={removeReviewImage}
                      />

                      {reviewError ? <div className="form-banner is-error">{reviewError}</div> : null}

                      <div className="comment-actions">
                        <button
                          type="button"
                          className="button button-primary"
                          onClick={() => void submitReview()}
                          disabled={reviewBusy}
                        >
                          <Send className="button-icon" />
                          <span>{reviewBusy ? "Отправляю..." : "Опубликовать"}</span>
                        </button>
                        <button
                          type="button"
                          className="button button-ghost"
                          onClick={resetReviewForm}
                          disabled={reviewBusy}
                        >
                          Отмена
                        </button>
                      </div>
                    </div>
                  ) : null}

                  {selected.reviews.length ? (
                    <div className="stack-list">
                      {selected.reviews.map((review) => (
                        <article key={review.id} className="review-card">
                          <div className="review-card-header">
                            <strong>{review.author_name}</strong>
                            <div className="support-chat-header-chips">
                              <span className="review-rating">
                                <Star className="review-rating-icon" />
                                {review.rating}/5
                              </span>
                              {!review.is_owner ? (
                                <ReportContentButton
                                  label="Пожаловаться"
                                  targetLabel={review.body.slice(0, 80) || "Отзыв на карте"}
                                  onSubmit={(payload) =>
                                    createMapReviewReport(selected.id, review.id, payload)
                                  }
                                />
                              ) : null}
                            </div>
                          </div>
                          <span className="muted">{formatDateTime(review.created_at)}</span>
                          <p>{review.body}</p>
                          {review.images.length ? (
                            <div className="map-review-image-grid">
                              {review.images.map((image) => (
                                <a
                                  key={image.id}
                                  href={image.image_url}
                                  target="_blank"
                                  rel="noreferrer"
                                  className="map-review-image-card"
                                >
                                  {/* eslint-disable-next-line @next/next/no-img-element */}
                                  <img
                                    src={image.image_url}
                                    alt={image.caption || review.author_name}
                                    className="gallery-image"
                                  />
                                </a>
                              ))}
                            </div>
                          ) : null}
                        </article>
                      ))}
                    </div>
                  ) : (
                    <EmptyState
                      title="Пока нет отзывов"
                      description="Станьте первым, кто поделится впечатлениями об этой точке."
                    />
                  )}
                </div>
              ) : null}
            </aside>
          ) : null}

          {selectedUserMarker || userMarkerDetailLoading ? (
            <aside className={`map-detail-overlay ${selectedUserMarker ? "is-open" : ""}`}>
              <div className="map-detail-header">
                <div>
                  <p className="eyebrow">Пользовательская метка</p>
                  <h3>{selectedUserMarker?.title || "Загружаю..."}</h3>
                </div>
                <button
                  type="button"
                  className="icon-button icon-button-muted"
                  aria-label="Закрыть карточку пользовательской метки"
                  onClick={() => setSelectedUserMarker(null)}
                >
                  <X className="nav-icon" />
                </button>
              </div>

              {userMarkerDetailLoading && !selectedUserMarker ? (
                <LoadingBlock label="Открываю метку..." />
              ) : selectedUserMarker ? (
                <div className="map-detail-content">
                  {selectedUserMarker.media.length ? (
                    <div className="map-gallery-grid">
                      {selectedUserMarker.media.map((item) => (
                        <a key={item.id} href={item.media_url} target="_blank" rel="noreferrer">
                          {item.media_type === "video" ? (
                            <video src={item.media_url} className="gallery-image" controls />
                          ) : (
                            // eslint-disable-next-line @next/next/no-img-element
                            <img
                              src={item.media_url}
                              alt={item.caption || selectedUserMarker.title}
                              className="gallery-image"
                            />
                          )}
                        </a>
                      ))}
                    </div>
                  ) : null}

                  <p className="map-detail-text">{selectedUserMarker.description}</p>

                  <div className="map-detail-meta">
                    <div className="map-meta-row">
                      <MapPin className="nav-icon" />
                      <span>
                        {selectedUserMarker.latitude.toFixed(6)}, {selectedUserMarker.longitude.toFixed(6)}
                      </span>
                    </div>
                    <div className="map-meta-row">
                      <MessageSquarePlus className="nav-icon" />
                      <span>
                        Автор: {selectedUserMarker.author?.name || selectedUserMarker.author?.username || "Пользователь"}
                      </span>
                    </div>
                  </div>

                  <div className="section-row">
                    <h4>Комментарии</h4>
                    <div className="support-chat-header-chips">
                      {!selectedUserMarker.is_owner ? (
                        <ReportContentButton
                          label="Пожаловаться"
                          targetLabel={selectedUserMarker.title}
                          onSubmit={(payload) =>
                            createUserMapMarkerReport(selectedUserMarker.id, payload)
                          }
                        />
                      ) : null}
                      <button
                        type="button"
                        className="button button-muted button-inline"
                        onClick={() => {
                          if (!isAuthenticated) {
                            openAuthModal({ returnTo: "/map" });
                            return;
                          }
                          setMarkerCommentFormOpen((current) => !current);
                          setMarkerCommentError(null);
                        }}
                      >
                        <MessageSquarePlus className="button-icon" />
                        <span>{markerCommentFormOpen ? "Скрыть" : "Комментировать"}</span>
                      </button>
                    </div>
                  </div>

                  {markerCommentFormOpen ? (
                    <div className="panel stack-list map-review-form">
                      <label className="field">
                        <span>Комментарий</span>
                        <textarea
                          value={markerCommentBody}
                          onChange={(event) => setMarkerCommentBody(event.target.value)}
                          placeholder="Добавьте уточнение или впечатление об этом месте"
                        />
                      </label>
                      {markerCommentError ? (
                        <div className="form-banner is-error">{markerCommentError}</div>
                      ) : null}
                      <div className="comment-actions">
                        <button
                          type="button"
                          className="button button-primary"
                          onClick={() => void submitMarkerComment()}
                          disabled={markerCommentBusy}
                        >
                          <Send className="button-icon" />
                          <span>{markerCommentBusy ? "Отправляю..." : "Отправить"}</span>
                        </button>
                      </div>
                    </div>
                  ) : null}

                  {selectedUserMarker.comments.length ? (
                    <div className="stack-list">
                      {selectedUserMarker.comments.map((comment) => (
                        <article key={comment.id} className="review-card">
                          <div className="review-card-header">
                            <strong>{comment.author_name}</strong>
                            {!comment.is_owner ? (
                              <ReportContentButton
                                label="Пожаловаться"
                                targetLabel={comment.body.slice(0, 80) || "Комментарий к метке"}
                                onSubmit={(payload) =>
                                  createUserMapMarkerCommentReport(
                                    selectedUserMarker.id,
                                    comment.id,
                                    payload,
                                  )
                                }
                              />
                            ) : null}
                          </div>
                          <span className="muted">{formatDateTime(comment.created_at)}</span>
                          <p>{comment.body}</p>
                        </article>
                      ))}
                    </div>
                  ) : (
                    <EmptyState
                      title="Комментариев пока нет"
                      description="Можно первым добавить уточнение к пользовательской метке."
                    />
                  )}
                </div>
              ) : null}
            </aside>
          ) : null}

          {markerDraftCoords ? (
            <aside className="map-detail-overlay is-open">
              <div className="map-detail-header">
                <div>
                  <p className="eyebrow">Новая метка</p>
                  <h3>Интересное место</h3>
                </div>
                <button
                  type="button"
                  className="icon-button icon-button-muted"
                  aria-label="Закрыть форму новой метки"
                  onClick={resetMarkerForm}
                >
                  <X className="nav-icon" />
                </button>
              </div>

              <div className="map-detail-content">
                <div className="map-detail-meta">
                  <div className="map-meta-row">
                    <MapPin className="nav-icon" />
                    <span>
                      {markerDraftCoords[1].toFixed(6)}, {markerDraftCoords[0].toFixed(6)}
                    </span>
                  </div>
                </div>

                <label className="field">
                  <span>Название</span>
                  <input
                    value={markerTitle}
                    onChange={(event) => setMarkerTitle(event.target.value)}
                    placeholder="Например: тихая смотровая площадка"
                  />
                </label>
                <label className="field">
                  <span>Что там интересного</span>
                  <textarea
                    value={markerDescription}
                    onChange={(event) => setMarkerDescription(event.target.value)}
                    placeholder="Опишите место, ориентиры, что стоит посмотреть"
                  />
                </label>
                <label
                  className={`marker-visibility-toggle ${
                    markerIsPublic ? "is-public" : ""
                  }`}
                >
                  <input
                    type="checkbox"
                    className="visually-hidden"
                    checked={markerIsPublic}
                    onChange={(event) => setMarkerIsPublic(event.target.checked)}
                  />
                  <span className="marker-visibility-head">
                    <span className="marker-visibility-icon" aria-hidden="true">
                      {markerIsPublic ? <Eye className="nav-icon" /> : <EyeOff className="nav-icon" />}
                    </span>
                    <span className="marker-visibility-main">
                      <strong>
                        {markerIsPublic ? "Видно всем на карте" : "Только для меня"}
                      </strong>
                      <span className="marker-visibility-description">
                        {markerIsPublic
                          ? "Другие пользователи смогут открыть метку и оставить комментарий."
                          : "Метка сохранится, но не появится у других пользователей."}
                      </span>
                    </span>
                    <span className="marker-visibility-switch" aria-hidden="true">
                      <span />
                    </span>
                  </span>
                </label>

                <ImageDropzone
                  title="Фото или видео"
                  description="Можно приложить фотографии или короткое видео места."
                  emptyHint="Перетащите фото/видео сюда или откройте системный выбор файлов."
                  browseLabel={markerFiles.length ? "Добавить ещё" : "Добавить медиа"}
                  accept="image/*,video/*"
                  allowVideo
                  files={markerFiles}
                  disabled={markerBusy}
                  onAddFiles={(nextFiles) => {
                    setMarkerFiles((current) => [...current, ...nextFiles]);
                  }}
                  onRemoveFile={removeMarkerFile}
                />

                {markerError ? <div className="form-banner is-error">{markerError}</div> : null}

                <div className="comment-actions">
                  <button
                    type="button"
                    className="button button-primary"
                    onClick={() => void submitUserMarker()}
                    disabled={markerBusy}
                  >
                    <Send className="button-icon" />
                    <span>{markerBusy ? "Сохраняю..." : "Опубликовать метку"}</span>
                  </button>
                  <button
                    type="button"
                    className="button button-ghost"
                    onClick={resetMarkerForm}
                    disabled={markerBusy}
                  >
                    Отмена
                  </button>
                </div>
              </div>
            </aside>
          ) : null}
        </section>
      ) : null}
      {afterContent}
    </AppShell>
  );
}
