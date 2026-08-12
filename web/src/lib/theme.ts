export type ThemeMode = "light" | "dark";

export const THEME_STORAGE_KEY = "eco-desman-web-theme";
export const THEME_STORAGE_EVENT = "eco-desman-web-theme-change";

export function getThemeInitScript() {
  return `(() => {
    try {
      const storageKey = ${JSON.stringify(THEME_STORAGE_KEY)};
      const stored = window.localStorage.getItem(storageKey);
      const mode =
        stored === "light" || stored === "dark"
          ? stored
          : window.matchMedia("(prefers-color-scheme: dark)").matches
            ? "dark"
            : "light";
      const root = document.documentElement;
      root.dataset.theme = mode;
      root.style.colorScheme = mode;
    } catch (_error) {
      // Ignore storage and media-query failures during bootstrap.
    }
  })();`;
}
