import type { MetadataRoute } from "next";

import { SITE_URL } from "@/lib/config";

const PRIVATE_ROUTES = [
  "/api/",
  "/django-admin/",
  "/admin$",
  "/admin/",
  "/auth$",
  "/auth/",
  "/favorites$",
  "/favorites/",
  "/notifications$",
  "/notifications/",
  "/profile$",
  "/profile/",
  "/settings/",
  "/support$",
  "/support/",
  "/posts/new$",
  "/posts/new/",
  "/posts/*/edit$",
  "/posts/*/edit/",
  "/*?utm_*",
  "/*?fbclid=*",
  "/*?gclid=*",
  "/*?yclid=*",
] as const;

function getRobotsHost(): string {
  try {
    return new URL(SITE_URL).host;
  } catch {
    return SITE_URL.replace(/^https?:\/\//, "");
  }
}

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: "*",
        allow: ["/"],
        disallow: [...PRIVATE_ROUTES],
      },
    ],
    sitemap: `${SITE_URL}/sitemap.xml`,
    host: getRobotsHost(),
  };
}
