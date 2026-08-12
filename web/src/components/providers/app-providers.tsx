"use client";

import { AuthDialog } from "@/components/auth/auth-page";
import { CookieNotice } from "@/components/layout/cookie-notice";
import { AuthProvider } from "@/components/providers/auth-provider";
import { ThemeProvider } from "@/components/providers/theme-provider";

export function AppProviders({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider>
      <AuthProvider>
        {children}
        <CookieNotice />
        <AuthDialog />
      </AuthProvider>
    </ThemeProvider>
  );
}
