"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import type { LucideIcon } from "lucide-react";
import {
  Bell,
  BookOpenText,
  CalendarDays,
  ChevronRight,
  Download,
  LifeBuoy,
  LogIn,
  LogOut,
  Menu,
  MapPinned,
  MoonStar,
  Newspaper,
  Shield,
  SquarePen,
  SunMedium,
  UserRound,
  X,
} from "lucide-react";
import { useEffect, useState } from "react";

import { AppDownloadDialog } from "@/components/layout/app-download-dialog";
import { useAuth } from "@/components/providers/auth-provider";
import { useThemeMode } from "@/components/providers/theme-provider";
import { Avatar } from "@/components/ui/avatar";
import { APP_NAME } from "@/lib/config";

const MOBILE_DOWNLOAD_PROMPT_SESSION_KEY = "eco-desman-mobile-download-prompt-v1";

const navItems: Array<{ href: string; label: string; icon: LucideIcon }> = [
  { href: "/", label: "Лента", icon: Newspaper },
  { href: "/events", label: "Мероприятия", icon: CalendarDays },
  { href: "/map", label: "Карта", icon: MapPinned },
];

const utilityItems: Array<{ href: string; label: string; icon: LucideIcon }> = [
  { href: "/help", label: "Справка", icon: BookOpenText },
  { href: "/support", label: "Помощь", icon: LifeBuoy },
];

export function AppShell({
  title,
  children,
  actions,
  contentClassName,
  shellContentClassName,
  titleTag = "h1",
}: {
  title: string;
  children: React.ReactNode;
  actions?: React.ReactNode;
  contentClassName?: string;
  shellContentClassName?: string;
  titleTag?: "h1" | "p";
}) {
  const pathname = usePathname();
  const router = useRouter();
  const { user, isAuthenticated, logout, openAuthModal } = useAuth();
  const { mode, toggleMode } = useThemeMode();
  const [isDownloadDialogOpen, setDownloadDialogOpen] = useState(false);
  const [isMobileMenuOpen, setMobileMenuOpen] = useState(false);
  const profileActive = pathname.startsWith("/profile") || pathname.startsWith("/favorites");
  const adminActive = pathname.startsWith("/admin");
  const canAccessAdmin = Boolean(user?.can_access_admin);
  const ThemeIcon = mode === "dark" ? MoonStar : SunMedium;
  const MenuIcon = isMobileMenuOpen ? X : Menu;
  const themeLabel = mode === "dark" ? "Тёмная" : "Светлая";
  const resolvedNavItems = canAccessAdmin
    ? [...navItems, { href: "/admin", label: "Админка", icon: Shield }]
    : navItems;
  const isDownloadRoute = pathname.startsWith("/download");
  const isMapRoute = pathname.startsWith("/map");
  const isNewPostRoute = pathname === "/posts/new";
  const isSupportRoute = pathname.startsWith("/support");
  const isHelpRoute = pathname.startsWith("/help");
  const showMobileAppBanner =
    !isDownloadRoute &&
    !isMapRoute &&
    !isNewPostRoute &&
    !isSupportRoute &&
    !isHelpRoute;
  const showMobileComposer =
    isAuthenticated &&
    pathname !== "/posts/new" &&
    !pathname.startsWith("/map") &&
    !pathname.startsWith("/support") &&
    !pathname.startsWith("/help") &&
    !pathname.startsWith("/download") &&
    !pathname.startsWith("/admin");
  const TitleTag = titleTag;

  useEffect(() => {
    if (
      typeof window === "undefined" ||
      isDownloadRoute ||
      isMapRoute ||
      isNewPostRoute ||
      isSupportRoute ||
      isHelpRoute
    ) {
      return;
    }

    const isMobileViewport = window.matchMedia("(max-width: 760px)").matches;
    const isStandalone = window.matchMedia("(display-mode: standalone)").matches;
    if (!isMobileViewport || isStandalone) {
      return;
    }

    const alreadyShown = window.sessionStorage.getItem(MOBILE_DOWNLOAD_PROMPT_SESSION_KEY) === "1";
    if (alreadyShown) {
      return;
    }

    window.sessionStorage.setItem(MOBILE_DOWNLOAD_PROMPT_SESSION_KEY, "1");
    const timer = window.setTimeout(() => setDownloadDialogOpen(true), 180);
    return () => window.clearTimeout(timer);
  }, [isDownloadRoute, isHelpRoute, isMapRoute, isNewPostRoute, isSupportRoute, pathname]);

  useEffect(() => {
    const timer = window.setTimeout(() => setMobileMenuOpen(false), 0);
    return () => window.clearTimeout(timer);
  }, [pathname]);

  function openDownloadSurface() {
    setDownloadDialogOpen(true);
    setMobileMenuOpen(false);
  }

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand-block">
          <div className="brand-logo">
            <Image src="/icon.png" alt={APP_NAME} width={52} height={52} />
          </div>
          <div>
            <p className="eyebrow">Экосообщество</p>
            <strong>{APP_NAME}</strong>
          </div>
        </div>

        <nav className="nav-list">
          {resolvedNavItems.map((item) => {
            const Icon = item.icon;
            const href = item.href === "/admin" ? "/admin/" : item.href;
            const isActive = item.href === "/admin" ? adminActive : pathname === item.href;

            return (
              <Link
                key={item.href}
                href={href}
                className={`nav-link ${isActive ? "is-active" : ""}`}
              >
                <Icon className="nav-icon" />
                <span>{item.label}</span>
              </Link>
            );
          })}

          {isAuthenticated ? (
            <Link href="/profile" className={`nav-link ${profileActive ? "is-active" : ""}`}>
              <UserRound className="nav-icon" />
              <span>Профиль</span>
            </Link>
          ) : null}
        </nav>

        <div className="sidebar-footer">
          {isAuthenticated && user ? (
            <>
              <Link href="/profile" className="profile-chip profile-chip-link">
                <div className="profile-chip-head">
                  <Avatar user={user} />
                  <div className="profile-chip-copy">
                    <strong>{user.name || user.username}</strong>
                    <p>@{user.username}</p>
                  </div>
                  <ChevronRight className="profile-chip-arrow" />
                </div>
                {user.status_text ? (
                  <span className="profile-chip-status">{user.status_text}</span>
                ) : null}
              </Link>
              <br />
              <div className="sidebar-actions">
                <Link href="/posts/new" className="button button-primary">
                  <SquarePen className="button-icon" />
                  <span>Новый пост</span>
                </Link>
                <Link href="/notifications" className="button button-muted">
                  <Bell className="button-icon" />
                  <span>Уведомления</span>
                </Link>
                <button
                  type="button"
                  className="button button-ghost"
                  onClick={async () => {
                    await logout();
                    router.push("/");
                  }}
                >
                  <LogOut className="button-icon" />
                  <span>Выйти</span>
                </button>
              </div>
            </>
          ) : (
            <div className="guest-card">
              <h3>Войти в сообщество</h3>
              <p>
                Публикации, избранное, комментарии и ваш профиль будут доступны после
                входа.
              </p>
              <div className="sidebar-actions">
                <button
                  type="button"
                  className="button button-primary"
                  onClick={() => openAuthModal({ returnTo: pathname || "/" })}
                >
                  <LogIn className="button-icon" />
                  <span>Войти</span>
                </button>
              </div>
            </div>
          )}
        </div>

        <div className="sidebar-section">
          <p className="eyebrow sidebar-section-title">Сервис</p>
          <nav className="sidebar-subnav">
            {utilityItems.map((item) => {
              const Icon = item.icon;
              const isActive = pathname.startsWith(item.href);

              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`sidebar-subnav-link ${isActive ? "is-active" : ""}`}
                >
                  <Icon className="nav-icon" />
                  <span>{item.label}</span>
                </Link>
              );
            })}

            <button
              type="button"
              className={`sidebar-subnav-link ${pathname.startsWith("/download") ? "is-active" : ""}`}
              onClick={openDownloadSurface}
            >
              <Download className="nav-icon" />
              <span>Скачать приложение</span>
            </button>
          </nav>
        </div>
      </aside>

      <div className={`shell-content${shellContentClassName ? ` ${shellContentClassName}` : ""}`}>
        <header className={`topbar ${actions ? "topbar-with-primary" : "topbar-compact-only"}`}>
          <div className="topbar-heading">
            <TitleTag className="topbar-title">{title}</TitleTag>
          </div>
          <div className={`topbar-actions ${actions ? "has-primary-slot" : "is-compact-only"}`}>
            {actions ? <div className="topbar-primary-slot">{actions}</div> : null}
            <div className={`topbar-utility-actions ${actions ? "" : "is-compact"}`}>
              <button
                type="button"
                className="button button-muted topbar-theme-button"
                onClick={toggleMode}
              >
                <ThemeIcon className="button-icon" />
                <span>{themeLabel}</span>
              </button>
              <button
                type="button"
                className={`button button-muted topbar-menu-button ${
                  isMobileMenuOpen ? "is-active" : ""
                }`}
                aria-expanded={isMobileMenuOpen}
                aria-controls="mobile-utility-menu"
                onClick={() => setMobileMenuOpen((current) => !current)}
              >
                <MenuIcon className="button-icon" />
                <span>
                  {isMobileMenuOpen
                    ? "\u0417\u0430\u043a\u0440\u044b\u0442\u044c"
                    : "\u041c\u0435\u043d\u044e"}
                </span>
              </button>
            </div>
          </div>
        </header>

        {isMobileMenuOpen ? (
          <div id="mobile-utility-menu" className="mobile-utility-menu panel">
            <nav className="mobile-utility-menu-list">
              {utilityItems.map((item) => {
                const Icon = item.icon;
                const isActive = pathname.startsWith(item.href);

                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={`mobile-utility-menu-link ${isActive ? "is-active" : ""}`}
                  >
                    <Icon className="nav-icon" />
                    <span>{item.label}</span>
                  </Link>
                );
              })}

              {isAuthenticated ? (
                <Link
                  href="/notifications"
                  className={`mobile-utility-menu-link ${
                    pathname.startsWith("/notifications") ? "is-active" : ""
                  }`}
                >
                  <Bell className="nav-icon" />
                  <span>{"\u0423\u0432\u0435\u0434\u043e\u043c\u043b\u0435\u043d\u0438\u044f"}</span>
                </Link>
              ) : null}

              <button
                type="button"
                className={`mobile-utility-menu-link ${isDownloadRoute ? "is-active" : ""}`}
                onClick={openDownloadSurface}
              >
                <Download className="nav-icon" />
                <span>{"\u0421\u043a\u0430\u0447\u0430\u0442\u044c \u043f\u0440\u0438\u043b\u043e\u0436\u0435\u043d\u0438\u0435"}</span>
              </button>

              {isAuthenticated ? (
                <button
                  type="button"
                  className="mobile-utility-menu-link"
                  onClick={async () => {
                    setMobileMenuOpen(false);
                    await logout();
                    router.push("/");
                  }}
                >
                  <LogOut className="nav-icon" />
                  <span>{"\u0412\u044b\u0439\u0442\u0438"}</span>
                </button>
              ) : (
                <button
                  type="button"
                  className="mobile-utility-menu-link"
                  onClick={() => {
                    setMobileMenuOpen(false);
                    openAuthModal({ returnTo: pathname || "/" });
                  }}
                >
                  <LogIn className="nav-icon" />
                  <span>{"\u0412\u043e\u0439\u0442\u0438"}</span>
                </button>
              )}
            </nav>
          </div>
        ) : null}

        {showMobileAppBanner ? (
          <section
            className="mobile-app-banner panel"
            aria-label="Предложение установить приложение"
          >
            <div className="mobile-app-banner-copy">
              <p className="eyebrow">Мобильное приложение</p>
              <h2 className="mobile-app-banner-title">На телефоне лучше ставить приложение</h2>
              <p>
                Веб-версия на мобильном повторяет структуру приложения, но нативная сборка
                быстрее, стабильнее и удобнее для карты, уведомлений и публикаций.
              </p>
            </div>

            <button
              type="button"
              className="button button-primary mobile-app-banner-button"
              onClick={openDownloadSurface}
            >
              <Download className="button-icon" />
              <span>Скачать приложение</span>
            </button>
          </section>
        ) : null}

        <div className="utility-strip" aria-label="Сервисные разделы">
          {utilityItems.map((item) => {
            const Icon = item.icon;
            const isActive = pathname.startsWith(item.href);

            return (
              <Link
                key={item.href}
                href={item.href}
                className={`utility-strip-link ${isActive ? "is-active" : ""}`}
              >
                <Icon className="nav-icon" />
                <span>{item.label}</span>
              </Link>
            );
          })}

          <button
            type="button"
            className={`utility-strip-link ${pathname.startsWith("/download") ? "is-active" : ""}`}
            onClick={openDownloadSurface}
          >
            <Download className="nav-icon" />
            <span>Скачать</span>
          </button>
        </div>

        <main className={`page-content${contentClassName ? ` ${contentClassName}` : ""}`}>
          {children}
        </main>
      </div>

      {showMobileComposer ? (
        <Link href="/posts/new" className="app-mobile-fab">
          <SquarePen className="button-icon" />
          <span>Новый пост</span>
        </Link>
      ) : null}

      <nav
        className="mobile-nav"
        style={{ gridTemplateColumns: `repeat(${resolvedNavItems.length + 1}, 1fr)` }}
      >
        {resolvedNavItems.map((item) => {
          const Icon = item.icon;
          const href = item.href === "/admin" ? "/admin/" : item.href;
          const isActive = item.href === "/admin" ? adminActive : pathname === item.href;

          return (
            <Link
              key={item.href}
              href={href}
              className={`mobile-nav-link ${isActive ? "is-active" : ""}`}
            >
              <Icon className="nav-icon" />
              <span>{item.label}</span>
            </Link>
          );
        })}

        {isAuthenticated ? (
          <Link href="/profile" className={`mobile-nav-link ${profileActive ? "is-active" : ""}`}>
            <UserRound className="nav-icon" />
            <span>Профиль</span>
          </Link>
        ) : (
          <button
            type="button"
            className="mobile-nav-link mobile-nav-button"
            onClick={() => openAuthModal({ returnTo: pathname || "/" })}
          >
            <LogIn className="nav-icon" />
            <span>Войти</span>
          </button>
        )}
      </nav>

      <AppDownloadDialog open={isDownloadDialogOpen} onClose={() => setDownloadDialogOpen(false)} />
    </div>
  );
}
