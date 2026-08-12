import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";

import { AppProviders } from "@/components/providers/app-providers";
import { SiteStructuredData } from "@/components/seo/site-structured-data";
import { APP_NAME, SITE_URL } from "@/lib/config";
import {
  INDEXABLE_ROBOTS,
  OPEN_GRAPH_IMAGE,
  searchEngineVerification,
  SITE_DESCRIPTION,
  SITE_KEYWORDS,
} from "@/lib/seo";
import { getThemeInitScript } from "@/lib/theme";
import "./globals.css";

const manrope = localFont({
  src: [
    { path: "./fonts/Manrope-cyrillic-ext.woff2", weight: "200 800", style: "normal" },
    { path: "./fonts/Manrope-cyrillic.woff2", weight: "200 800", style: "normal" },
    { path: "./fonts/Manrope-greek.woff2", weight: "200 800", style: "normal" },
    { path: "./fonts/Manrope-vietnamese.woff2", weight: "200 800", style: "normal" },
    { path: "./fonts/Manrope-latin-ext.woff2", weight: "200 800", style: "normal" },
    { path: "./fonts/Manrope-latin.woff2", weight: "200 800", style: "normal" },
  ],
  variable: "--font-manrope",
});

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  applicationName: APP_NAME,
  authors: [{ name: APP_NAME, url: SITE_URL }],
  creator: APP_NAME,
  publisher: APP_NAME,
  title: {
    default: `${APP_NAME} — экологическая карта, события и сообщество`,
    template: "%s",
  },
  description: SITE_DESCRIPTION,
  keywords: SITE_KEYWORDS,
  verification: searchEngineVerification(),
  openGraph: {
    type: "website",
    locale: "ru_RU",
    url: "/",
    siteName: APP_NAME,
    title: `${APP_NAME} — экологическая карта, события и сообщество`,
    description: SITE_DESCRIPTION,
    images: [OPEN_GRAPH_IMAGE],
  },
  twitter: {
    card: "summary_large_image",
    title: `${APP_NAME} — экологическая карта, события и сообщество`,
    description: SITE_DESCRIPTION,
    images: [OPEN_GRAPH_IMAGE.url],
  },
  robots: INDEXABLE_ROBOTS,
  formatDetection: {
    telephone: false,
    address: false,
    email: false,
  },
  appleWebApp: {
    capable: true,
    title: APP_NAME,
    statusBarStyle: "default",
  },
  manifest: "/manifest.webmanifest",
  icons: {
    icon: [
      { url: "/favicon.ico", sizes: "any" },
      { url: "/icon-32x32.png", sizes: "32x32", type: "image/png" },
      { url: "/icon-192x192.png", sizes: "192x192", type: "image/png" },
      { url: "/icon-512x512.png", sizes: "512x512", type: "image/png" },
    ],
    shortcut: [{ url: "/favicon.ico" }],
    apple: [
      { url: "/apple-touch-icon.png", sizes: "180x180", type: "image/png" },
    ],
  },
  category: "экология",
};

export const viewport: Viewport = {
  colorScheme: "light dark",
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f3f5ef" },
    { media: "(prefers-color-scheme: dark)", color: "#090c10" },
  ],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ru" className={manrope.variable} suppressHydrationWarning>
      <head>
        <script
          dangerouslySetInnerHTML={{ __html: getThemeInitScript() }}
        />
      </head>
      <body>
        <SiteStructuredData />
        <AppProviders>{children}</AppProviders>
      </body>
    </html>
  );
}
