import type { SourceSpecification, StyleSpecification } from "maplibre-gl";

type ThemeMode = "light" | "dark";

// Same-origin proxy: nginx `/map-raster/` in prod, Next.js rewrite in dev.
const osmTileSource: SourceSpecification = {
  type: "raster",
  tiles: ["/map-raster/{z}/{x}/{y}.png"],
  tileSize: 256,
  maxzoom: 19,
  attribution:
    '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
};

function cloneStyle(style: StyleSpecification): StyleSpecification {
  if (typeof structuredClone === "function") {
    return structuredClone(style);
  }

  return JSON.parse(JSON.stringify(style)) as StyleSpecification;
}

function createRasterMapStyle(mode: ThemeMode): StyleSpecification {
  const isDark = mode === "dark";

  return {
    version: 8,
    sources: {
      osm: osmTileSource,
    },
    layers: [
      {
        id: "background",
        type: "background",
        paint: {
          "background-color": isDark ? "#202733" : "#EEF2F4",
        },
      },
      {
        id: "osm-raster",
        type: "raster",
        source: "osm",
        paint: isDark
          ? {
              "raster-brightness-min": 0.12,
              "raster-brightness-max": 0.62,
              "raster-contrast": 0.22,
              "raster-saturation": -0.35,
            }
          : {},
      },
    ],
  };
}

export async function getMapStyle(mode: ThemeMode) {
  return cloneStyle(createRasterMapStyle(mode));
}
