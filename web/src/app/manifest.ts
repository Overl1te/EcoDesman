import type { MetadataRoute } from "next";

import { APP_NAME, APP_SHORT_NAME } from "@/lib/config";
import { SITE_DESCRIPTION } from "@/lib/seo";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: APP_NAME,
    short_name: APP_SHORT_NAME,
    description: SITE_DESCRIPTION,
    lang: "ru-RU",
    start_url: "/",
    display: "standalone",
    background_color: "#f3f5ef",
    theme_color: "#2d6a4f",
    icons: [
      {
        src: "/icon-192x192.png",
        sizes: "192x192",
        type: "image/png",
      },
      {
        src: "/icon-512x512.png",
        sizes: "512x512",
        type: "image/png",
      },
      {
        src: "/icon-maskable-512x512.png",
        sizes: "512x512",
        type: "image/png",
        purpose: "maskable",
      },
    ],
  };
}
