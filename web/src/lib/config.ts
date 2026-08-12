export const APP_NAME = "\u042d\u043a\u043e\u0412\u044b\u0445\u0443\u0445\u043e\u043b\u044c";
export const APP_SHORT_NAME = "EcoDesman";

export const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? "/api/v1";

function normalizeSiteUrl(value: string | undefined): string {
  const fallback = "https://xn--b1apekb3anb5cpb.xn--p1ai";
  const localHostnames = new Set(["localhost", "127.0.0.1", "0.0.0.0", "::1"]);

  if (!value) {
    return fallback;
  }

  try {
    const parsed = new URL(value);
    parsed.hash = "";
    parsed.search = "";

    if (parsed.protocol === "http:" && !localHostnames.has(parsed.hostname)) {
      parsed.protocol = "https:";
    }

    return parsed.toString().replace(/\/$/, "");
  } catch {
    return fallback;
  }
}

export const SITE_URL = normalizeSiteUrl(process.env.NEXT_PUBLIC_SITE_URL);

export const MOBILE_APP_LINKS = {
  ios:
    process.env.NEXT_PUBLIC_IOS_APP_URL ??
    "https://github.com/Overl1te/EcoDesman-mobile",
  android:
    process.env.NEXT_PUBLIC_ANDROID_APP_URL ??
    "https://github.com/Overl1te/EcoDesman-mobile/releases",
  repository:
    process.env.NEXT_PUBLIC_MOBILE_APP_REPOSITORY_URL ??
    "https://github.com/Overl1te/EcoDesman-mobile",
} as const;
