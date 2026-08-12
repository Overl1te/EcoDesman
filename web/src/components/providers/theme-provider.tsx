"use client";

import {
  createContext,
  useContext,
  useEffect,
  useSyncExternalStore,
} from "react";

import {
  THEME_STORAGE_EVENT,
  THEME_STORAGE_KEY,
  type ThemeMode,
} from "@/lib/theme";

interface ThemeContextValue {
  mode: ThemeMode;
  toggleMode: () => void;
}

const ThemeContext = createContext<ThemeContextValue | null>(null);

function applyTheme(mode: ThemeMode) {
  if (typeof document === "undefined") {
    return;
  }

  document.documentElement.dataset.theme = mode;
  document.documentElement.style.colorScheme = mode;
}

function readStoredTheme(): ThemeMode | null {
  if (typeof window === "undefined") {
    return null;
  }

  const stored = window.localStorage.getItem(THEME_STORAGE_KEY);
  return stored === "light" || stored === "dark" ? stored : null;
}

function readSystemTheme(): ThemeMode {
  if (typeof window === "undefined") {
    return "dark";
  }

  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

function subscribeToStoredTheme(onStoreChange: () => void) {
  if (typeof window === "undefined") {
    return () => undefined;
  }

  const handleStorage = (event: Event) => {
    if (
      event instanceof StorageEvent &&
      event.key &&
      event.key !== THEME_STORAGE_KEY
    ) {
      return;
    }

    onStoreChange();
  };

  window.addEventListener("storage", handleStorage);
  window.addEventListener(THEME_STORAGE_EVENT, handleStorage);

  return () => {
    window.removeEventListener("storage", handleStorage);
    window.removeEventListener(THEME_STORAGE_EVENT, handleStorage);
  };
}

function subscribeToSystemTheme(onStoreChange: () => void) {
  if (typeof window === "undefined") {
    return () => undefined;
  }

  const media = window.matchMedia("(prefers-color-scheme: dark)");
  media.addEventListener("change", onStoreChange);
  return () => media.removeEventListener("change", onStoreChange);
}

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const storedMode = useSyncExternalStore<ThemeMode | null>(
    subscribeToStoredTheme,
    readStoredTheme,
    () => null,
  );
  const systemMode = useSyncExternalStore<ThemeMode>(
    subscribeToSystemTheme,
    readSystemTheme,
    () => "dark",
  );
  const mode: ThemeMode = storedMode ?? systemMode;

  useEffect(() => {
    applyTheme(mode);
  }, [mode]);

  const toggleMode = () => {
    if (typeof window === "undefined") {
      return;
    }

    const nextMode = mode === "dark" ? "light" : "dark";
    applyTheme(nextMode);
    window.localStorage.setItem(THEME_STORAGE_KEY, nextMode);
    window.dispatchEvent(new Event(THEME_STORAGE_EVENT));
  };

  return (
    <ThemeContext.Provider value={{ mode, toggleMode }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useThemeMode(): ThemeContextValue {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error("useThemeMode must be used inside ThemeProvider");
  }
  return context;
}
