"use client";

import type React from "react";
import Link from "next/link";
import {
  Check,
  ChevronDown,
  ChevronRight,
  Eye,
  EyeOff,
  FileText,
  MapPinned,
  MoreHorizontal,
  Newspaper,
  Plus,
  UsersRound,
} from "lucide-react";
import { useEffect, useRef, useState } from "react";

import { AppShell } from "@/components/layout/app-shell";
import { useAuth } from "@/components/providers/auth-provider";
import { EmptyState } from "@/components/ui/empty-state";
import { LoadingBlock } from "@/components/ui/loading-block";
import {
  banUser,
  bulkAdminPosts,
  createAdminMapCategory,
  createAdminMapPoint,
  deleteAdminMapCategory,
  deleteAdminMapPoint,
  deleteAdminUserMapMarker,
  deletePost,
  getAdminOverview,
  listAdminMapCategories,
  listAdminMapPoints,
  listAdminUserMapMarkers,
  listAdminPosts,
  listAdminUsers,
  unbanUser,
  updateAdminMapCategory,
  updateAdminMapPoint,
  updateAdminUserMapMarker,
  updatePost,
  updateUserRole,
  warnUser,
} from "@/lib/api";
import { compactCount, formatDateTime } from "@/lib/format";
import { buildPostEditPath, buildPostPath } from "@/lib/paths";
import type {
  AdminMapPoint,
  AdminMapPointWritePayload,
  AdminOverview,
  AdminUserMapMarker,
  AdminUser,
  MapPointCategory,
  PaginatedResponse,
  PostListItem,
  UserRole,
} from "@/lib/types";

type AdminTab = "posts" | "map" | "users";
type PublicationStatus = "all" | "published" | "draft";
type UserStatusFilter = "all" | "active" | "banned" | "admin";
type PointStatusFilter = "all" | "active" | "hidden";
type PointCategoryFilter = "all" | number;
type MapMode = "list" | "create";
type PostOrdering = "recent" | "popular" | "recommended";

interface MapPointFormState {
  slug: string;
  title: string;
  short_description: string;
  description: string;
  address: string;
  working_hours: string;
  latitude: string;
  longitude: string;
  marker_color: string;
  is_active: boolean;
  sort_order: string;
  category_ids: number[];
  image_urls_text: string;
}

interface MapCategoryFormState {
  slug: string;
  title: string;
  sort_order: string;
  color: string;
}

const POST_PAGE_SIZE = 20;
const USER_PAGE_SIZE = 20;
const DEFAULT_MARKER_COLOR = "#56616F";
const HEX_COLOR_PATTERN = /^#[0-9A-F]{6}$/i;

function normalizeHexColor(value: string, fallback = DEFAULT_MARKER_COLOR) {
  const normalized = value.trim().toUpperCase();
  return HEX_COLOR_PATTERN.test(normalized) ? normalized : fallback;
}

function createEmptyPointForm(): MapPointFormState {
  return {
    slug: "", title: "", short_description: "", description: "",
    address: "", working_hours: "", latitude: "", longitude: "",
    marker_color: DEFAULT_MARKER_COLOR, is_active: true, sort_order: "0",
    category_ids: [], image_urls_text: "",
  };
}

function createEmptyCategoryForm(): MapCategoryFormState {
  return { slug: "", title: "", sort_order: "0", color: DEFAULT_MARKER_COLOR };
}

function mapPointToForm(point: AdminMapPoint): MapPointFormState {
  return {
    slug: point.slug, title: point.title,
    short_description: point.short_description, description: point.description,
    address: point.address, working_hours: point.working_hours,
    latitude: String(point.latitude), longitude: String(point.longitude),
    marker_color: normalizeHexColor(point.marker_color), is_active: point.is_active,
    sort_order: String(point.sort_order),
    category_ids: point.categories.map((c) => c.id),
    image_urls_text: point.images.map((i) => i.image_url).join("\n"),
  };
}

function categoryToForm(cat: MapPointCategory): MapCategoryFormState {
  return { slug: cat.slug, title: cat.title, sort_order: String(cat.sort_order), color: normalizeHexColor(cat.color) };
}

function buildMapPointPayload(form: MapPointFormState): AdminMapPointWritePayload {
  return {
    slug: form.slug.trim(), title: form.title.trim(),
    short_description: form.short_description.trim(), description: form.description.trim(),
    address: form.address.trim(), working_hours: form.working_hours.trim(),
    latitude: Number(form.latitude), longitude: Number(form.longitude),
    marker_color: normalizeHexColor(form.marker_color), is_active: form.is_active,
    sort_order: Number(form.sort_order) || 0, category_ids: form.category_ids,
    image_urls: form.image_urls_text.split("\n").map((v) => v.trim()).filter(Boolean),
  };
}

function getErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : "Не удалось выполнить действие";
}

function getRoleLabel(role: UserRole): string {
  const map: Record<UserRole, string> = {
    admin: "Админ", support: "Техподдержка", moderator: "Модератор", user: "Пользователь",
  };
  return map[role] ?? "Пользователь";
}

function getKindLabel(kind: PostListItem["kind"]): string {
  if (kind === "event") return "Событие";
  if (kind === "story") return "История";
  return "Новость";
}

function buildPageNumbers(current: number, total: number): (number | "...")[] {
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1);
  const pages: (number | "...")[] = [1];
  if (current > 3) pages.push("...");
  for (let p = Math.max(2, current - 1); p <= Math.min(total - 1, current + 1); p++) {
    pages.push(p);
  }
  if (current < total - 2) pages.push("...");
  pages.push(total);
  return pages;
}

// ─── Collapsible section helper ─────────────────────────────────────────────
function PointSection({ title, children, defaultOpen = true }: {
  title: string; children: React.ReactNode; defaultOpen?: boolean;
}) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <div className="admin-point-section">
      <button type="button" className="admin-point-section-head" onClick={() => setOpen((o) => !o)}>
        <span>{title}</span>
        {open ? <ChevronDown size={14} /> : <ChevronRight size={14} />}
      </button>
      {open ? <div className="admin-point-section-body">{children}</div> : null}
    </div>
  );
}

// ─── Overflow menu ───────────────────────────────────────────────────────────
function OverflowMenu({ items }: { items: { label: string; danger?: boolean; disabled?: boolean; onClick: () => void }[] }) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handle(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener("mousedown", handle);
    return () => document.removeEventListener("mousedown", handle);
  }, []);

  return (
    <div className="admin-overflow" ref={ref}>
      <button
        type="button"
        className="button button-ghost button-inline admin-overflow-btn"
        onClick={() => setOpen((o) => !o)}
        aria-label="Ещё действия"
      >
        <MoreHorizontal size={16} />
      </button>
      {open ? (
        <div className="admin-overflow-menu">
          {items.map((item) => (
            <button
              key={item.label}
              type="button"
              className={`admin-overflow-item${item.danger ? " is-danger" : ""}`}
              disabled={item.disabled}
              onClick={() => { setOpen(false); item.onClick(); }}
            >
              {item.label}
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}

// ─── Numbered pagination ─────────────────────────────────────────────────────
function Pagination({ page, total, pageSize, loading, onPage }: {
  page: number; total: number; pageSize: number; loading: boolean; onPage: (p: number) => void;
}) {
  const totalPages = Math.ceil(total / pageSize);
  if (totalPages <= 1) return null;
  const pages = buildPageNumbers(page, totalPages);

  return (
    <div className="admin-pagination">
      {pages.map((p, i) =>
        p === "..." ? (
          <span key={`ellipsis-${i}`} className="admin-pagination-ellipsis">…</span>
        ) : (
          <button
            key={p}
            type="button"
            className={`admin-pagination-btn${p === page ? " is-active" : ""}`}
            disabled={loading || p === page}
            onClick={() => onPage(p as number)}
          >
            {p}
          </button>
        ),
      )}
    </div>
  );
}

// ─── Status badge ────────────────────────────────────────────────────────────
function StatusBadge({ label, color }: { label: string; color: "green" | "grey" | "yellow" | "red" }) {
  return <span className={`admin-status-badge is-${color}`}>{label}</span>;
}

function PostStatusBadge({ post }: { post: PostListItem }) {
  return post.is_published
    ? <StatusBadge label="Опубликован" color="green" />
    : <StatusBadge label="Черновик" color="grey" />;
}

// ─── Main component ──────────────────────────────────────────────────────────
export function AdminPage() {
  const { user, isAuthenticated, refreshUser, openAuthModal } = useAuth();
  const canAccessAdmin = Boolean(user?.can_access_admin);

  const [activeTab, setActiveTab] = useState<AdminTab>("posts");
  const [overview, setOverview] = useState<AdminOverview | null>(null);
  const [overviewLoading, setOverviewLoading] = useState(false);
  const [mutationKey, setMutationKey] = useState<string | null>(null);
  const [globalError, setGlobalError] = useState<string | null>(null);

  // Posts
  const [posts, setPosts] = useState<PaginatedResponse<PostListItem> | null>(null);
  const [postsLoading, setPostsLoading] = useState(false);
  const [postsError, setPostsError] = useState<string | null>(null);
  const [postSearch, setPostSearch] = useState("");
  const [postKind, setPostKind] = useState<"all" | PostListItem["kind"]>("all");
  const [postPublicationStatus, setPostPublicationStatus] = useState<PublicationStatus>("all");
  const [postOrdering, setPostOrdering] = useState<PostOrdering>("recent");
  const [postsPage, setPostsPage] = useState(1);
  const [selectedPostIds, setSelectedPostIds] = useState<Set<number>>(new Set());
  const postsBootstrapped = useRef(false);

  // Users
  const [users, setUsers] = useState<PaginatedResponse<AdminUser> | null>(null);
  const [usersLoading, setUsersLoading] = useState(false);
  const [usersError, setUsersError] = useState<string | null>(null);
  const [userSearch, setUserSearch] = useState("");
  const [userRole, setUserRole] = useState<"all" | UserRole>("all");
  const [userStatus, setUserStatus] = useState<UserStatusFilter>("all");
  const [usersPage, setUsersPage] = useState(1);
  const usersBootstrapped = useRef(false);

  // Map
  const [categories, setCategories] = useState<MapPointCategory[]>([]);
  const [points, setPoints] = useState<PaginatedResponse<AdminMapPoint> | null>(null);
  const [pointsLoading, setPointsLoading] = useState(false);
  const [pointsError, setPointsError] = useState<string | null>(null);
  const [pointSearch, setPointSearch] = useState("");
  const [pointStatus, setPointStatus] = useState<PointStatusFilter>("all");
  const [pointCategoryFilter, setPointCategoryFilter] = useState<PointCategoryFilter>("all");
  const [selectedPointId, setSelectedPointId] = useState<number | "new">("new");
  const [pointForm, setPointForm] = useState<MapPointFormState>(createEmptyPointForm());
  const [selectedCategoryId, setSelectedCategoryId] = useState<number | "new">("new");
  const [categoryForm, setCategoryForm] = useState<MapCategoryFormState>(createEmptyCategoryForm());
  const [mapMode, setMapMode] = useState<MapMode>("list");
  const [userMarkers, setUserMarkers] = useState<PaginatedResponse<AdminUserMapMarker> | null>(null);
  const [userMarkersLoading, setUserMarkersLoading] = useState(false);
  const [userMarkersError, setUserMarkersError] = useState<string | null>(null);

  // ── Loaders ──────────────────────────────────────────────────────────────
  async function loadOverview() {
    setOverviewLoading(true);
    try { setOverview(await getAdminOverview()); }
    catch { /* best-effort */ }
    finally { setOverviewLoading(false); }
  }

  async function loadPosts(page = 1) {
    setPostsLoading(true);
    setPostsError(null);
    setPostsPage(page);
    try {
      setPosts(await listAdminPosts({
        page,
        search: postSearch.trim() || undefined,
        kind: postKind === "all" ? undefined : postKind,
        is_published: postPublicationStatus === "all" ? undefined : postPublicationStatus === "published",
        ordering: postOrdering,
      }));
    } catch (error) {
      setPostsError(getErrorMessage(error));
    } finally {
      setPostsLoading(false);
    }
  }

  async function loadUsers(page = 1) {
    setUsersLoading(true);
    setUsersError(null);
    setUsersPage(page);
    try {
      setUsers(await listAdminUsers({
        page,
        search: userSearch.trim() || undefined,
        role: userRole === "all" ? undefined : userRole,
        status: userStatus === "all" ? undefined : userStatus,
      }));
    } catch (error) {
      setUsersError(getErrorMessage(error));
    } finally {
      setUsersLoading(false);
    }
  }

  async function loadCategories() {
    try { setCategories(await listAdminMapCategories()); }
    catch (error) { setGlobalError(getErrorMessage(error)); }
  }

  async function loadPoints() {
    setPointsLoading(true);
    setPointsError(null);
    try {
      setPoints(await listAdminMapPoints({
        page_size: 100,
        search: pointSearch.trim() || undefined,
        is_active: pointStatus === "all" ? undefined : pointStatus === "active",
        category_id: pointCategoryFilter === "all" ? undefined : pointCategoryFilter,
      }));
    } catch (error) {
      setPointsError(getErrorMessage(error));
    } finally {
      setPointsLoading(false);
    }
  }

  async function loadUserMarkers() {
    setUserMarkersLoading(true);
    setUserMarkersError(null);
    try {
      setUserMarkers(await listAdminUserMapMarkers({
        page_size: 100,
        search: pointSearch.trim() || undefined,
        is_active: pointStatus === "all" ? undefined : pointStatus === "active",
      }));
    } catch (error) {
      setUserMarkersError(getErrorMessage(error));
    } finally {
      setUserMarkersLoading(false);
    }
  }

  // ── Bootstrap ─────────────────────────────────────────────────────────────
  useEffect(() => {
    if (!canAccessAdmin) return;
    void Promise.all([loadOverview(), loadPosts(1), loadUsers(1), loadCategories(), loadPoints(), loadUserMarkers()]);
    postsBootstrapped.current = true;
    usersBootstrapped.current = true;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [canAccessAdmin]);

  // ── Auto-apply posts filters ──────────────────────────────────────────────
  useEffect(() => {
    if (!postsBootstrapped.current) return;
    const timer = setTimeout(() => void loadPosts(1), postSearch ? 400 : 0);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [postSearch, postKind, postPublicationStatus, postOrdering]);

  // ── Auto-apply users filters ──────────────────────────────────────────────
  useEffect(() => {
    if (!usersBootstrapped.current) return;
    const timer = setTimeout(() => void loadUsers(1), userSearch ? 400 : 0);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userSearch, userRole, userStatus]);

  // ── Sync point form when selection changes ────────────────────────────────
  useEffect(() => {
    if (selectedPointId === "new") return;
    const next = points?.results.find((p) => p.id === selectedPointId);
    if (!next) { setSelectedPointId("new"); setPointForm(createEmptyPointForm()); }
  }, [points, selectedPointId]);

  useEffect(() => {
    if (selectedCategoryId === "new") return;
    if (!categories.some((c) => c.id === selectedCategoryId)) {
      setSelectedCategoryId("new"); setCategoryForm(createEmptyCategoryForm());
    }
  }, [categories, selectedCategoryId]);

  useEffect(() => {
    if (pointCategoryFilter !== "all" && !categories.some((c) => c.id === pointCategoryFilter)) {
      setPointCategoryFilter("all");
    }
  }, [categories, pointCategoryFilter]);

  // ── Mutation helper ────────────────────────────────────────────────────────
  async function runMutation<T>(key: string, action: () => Promise<T>, onSuccess?: (r: T) => Promise<void> | void) {
    setMutationKey(key);
    setGlobalError(null);
    try {
      const result = await action();
      await onSuccess?.(result);
    } catch (error) {
      setGlobalError(getErrorMessage(error));
    } finally {
      setMutationKey(null);
    }
  }

  // ── Post actions ──────────────────────────────────────────────────────────
  async function handleTogglePublished(post: PostListItem) {
    await runMutation(`post-publish-${post.id}`, async () => {
      await updatePost(post.id, { is_published: !post.is_published });
    }, async () => { await Promise.all([loadPosts(postsPage), loadOverview()]); });
  }

  async function handleDeletePost(postId: number) {
    if (!window.confirm("Удалить пост без возможности восстановления?")) return;
    await runMutation(`post-delete-${postId}`, async () => {
      await deletePost(postId);
    }, async () => { await Promise.all([loadPosts(postsPage), loadOverview()]); setSelectedPostIds(new Set()); });
  }

  async function handleBulkAction(action: "publish" | "unpublish" | "delete") {
    if (action === "delete" && !window.confirm(`Удалить ${selectedPostIds.size} постов?`)) return;
    const ids = Array.from(selectedPostIds);
    await runMutation(`bulk-${action}`, async () => {
      await bulkAdminPosts({ action, ids });
    }, async () => { setSelectedPostIds(new Set()); await Promise.all([loadPosts(postsPage), loadOverview()]); });
  }

  function togglePostSelection(id: number) {
    setSelectedPostIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) { next.delete(id); } else { next.add(id); }
      return next;
    });
  }

  function toggleAllPosts() {
    const allIds = posts?.results.map((p) => p.id) ?? [];
    const allSelected = allIds.every((id) => selectedPostIds.has(id));
    setSelectedPostIds(allSelected ? new Set() : new Set(allIds));
  }

  // ── User actions ──────────────────────────────────────────────────────────
  async function handleUserRoleChange(adminUser: AdminUser, role: UserRole) {
    await runMutation(`user-role-${adminUser.id}`, async () => {
      await updateUserRole(adminUser.id, role);
    }, async () => {
      await loadUsers(usersPage);
      if (user?.id === adminUser.id) await refreshUser();
    });
  }

  async function handleUserModeration(adminUser: AdminUser, action: "warn" | "ban" | "unban") {
    await runMutation(`user-${action}-${adminUser.id}`, async () => {
      if (action === "warn") { await warnUser(adminUser.id); return; }
      if (action === "ban") { await banUser(adminUser.id); return; }
      await unbanUser(adminUser.id);
    }, async () => {
      await Promise.all([loadUsers(usersPage), loadOverview()]);
      if (user?.id === adminUser.id) await refreshUser();
    });
  }

  // ── Point / category actions ──────────────────────────────────────────────
  function handlePointSelection(point: AdminMapPoint) {
    setSelectedPointId(point.id);
    setPointForm(mapPointToForm(point));
    setMapMode("create");
  }

  function resetPointEditor() {
    setSelectedPointId("new");
    setPointForm(createEmptyPointForm());
  }

  function setPointCategories(categoryIds: number[]) {
    setPointForm((c) => ({ ...c, category_ids: Array.from(new Set(categoryIds)) }));
  }

  async function handleSavePoint() {
    const payload = buildMapPointPayload(pointForm);
    if (!payload.slug || !payload.title) { setGlobalError("Для точки нужны slug и название."); return; }
    if (Number.isNaN(payload.latitude) || Number.isNaN(payload.longitude)) { setGlobalError("Координаты должны быть числами."); return; }

    await runMutation(
      selectedPointId === "new" ? "point-create" : `point-save-${selectedPointId}`,
      async () => selectedPointId === "new" ? createAdminMapPoint(payload) : updateAdminMapPoint(selectedPointId, payload),
      async (savedPoint) => {
        setSelectedPointId(savedPoint.id);
        setPointForm(mapPointToForm(savedPoint));
        await Promise.all([loadPoints(), loadOverview()]);
      },
    );
  }

  async function handleDeletePoint() {
    if (selectedPointId === "new" || !window.confirm("Удалить точку карты?")) return;
    await runMutation(`point-delete-${selectedPointId}`, async () => {
      await deleteAdminMapPoint(selectedPointId);
    }, async () => { resetPointEditor(); setMapMode("list"); await Promise.all([loadPoints(), loadOverview()]); });
  }

  async function handleSaveCategory() {
    const payload = {
      slug: categoryForm.slug.trim(), title: categoryForm.title.trim(),
      sort_order: Number(categoryForm.sort_order) || 0, color: normalizeHexColor(categoryForm.color),
    };
    if (!payload.slug || !payload.title) { setGlobalError("Для категории нужны slug и название."); return; }

    await runMutation(
      selectedCategoryId === "new" ? "category-create" : `category-save-${selectedCategoryId}`,
      async () => selectedCategoryId === "new" ? createAdminMapCategory(payload) : updateAdminMapCategory(selectedCategoryId, payload),
      async (saved) => {
        setSelectedCategoryId(saved.id);
        setCategoryForm(categoryToForm(saved));
        await Promise.all([loadCategories(), loadPoints()]);
      },
    );
  }

  async function handleDeleteCategory() {
    if (selectedCategoryId === "new" || !window.confirm("Удалить категорию карты?")) return;
    await runMutation(`category-delete-${selectedCategoryId}`, async () => {
      await deleteAdminMapCategory(selectedCategoryId);
    }, async () => {
      setSelectedCategoryId("new"); setCategoryForm(createEmptyCategoryForm());
      if (typeof pointCategoryFilter === "number" && pointCategoryFilter === selectedCategoryId) setPointCategoryFilter("all");
      await Promise.all([loadCategories(), loadPoints()]);
    });
  }

  async function handleToggleUserMarker(marker: AdminUserMapMarker) {
    await runMutation(`user-marker-toggle-${marker.id}`, async () => {
      await updateAdminUserMapMarker(marker.id, { is_active: !marker.is_active });
    }, async () => { await Promise.all([loadUserMarkers(), loadOverview()]); });
  }

  async function handleDeleteUserMarker(marker: AdminUserMapMarker) {
    if (!window.confirm("Удалить пользовательскую метку?")) return;
    await runMutation(`user-marker-delete-${marker.id}`, async () => {
      await deleteAdminUserMapMarker(marker.id);
    }, async () => { await Promise.all([loadUserMarkers(), loadOverview()]); });
  }

  // ── Auth guards ───────────────────────────────────────────────────────────
  if (!isAuthenticated) {
    return (
      <AppShell title="Админка">
        <EmptyState
          title="Нужен вход"
          description="Админка доступна только после авторизации."
          action={
            <button type="button" className="button button-primary" onClick={() => openAuthModal({ returnTo: "/admin/" })}>
              Войти
            </button>
          }
        />
      </AppShell>
    );
  }

  if (!canAccessAdmin) {
    return (
      <AppShell title="Админка">
        <EmptyState title="Недостаточно прав" description="Этот раздел открыт только для админов." />
      </AppShell>
    );
  }

  const allPostsSelected = Boolean(posts?.results.length && posts.results.every((p) => selectedPostIds.has(p.id)));

  return (
    <AppShell
      title="Админка"
      actions={
        <div className="admin-quick-actions">
          <Link href="/posts/new" className="button button-muted button-inline">
            <Plus size={14} />
            <span>Новый пост</span>
          </Link>
          <button
            type="button"
            className="button button-muted button-inline"
            onClick={() => { setActiveTab("map"); setMapMode("create"); resetPointEditor(); }}
          >
            <Plus size={14} />
            <span>Новая точка</span>
          </button>
          <button
            type="button"
            className="button button-ghost button-inline"
            onClick={() => {
              void loadOverview();
              if (activeTab === "posts") void loadPosts(postsPage);
              if (activeTab === "map") { void loadCategories(); void loadPoints(); void loadUserMarkers(); }
              if (activeTab === "users") void loadUsers(usersPage);
            }}
          >
            Обновить
          </button>
        </div>
      }
    >
      {/* ── Stats bar ─────────────────────────────────────────────────────── */}
      {overview ? (
        <div className="admin-stats-bar">
          <span className="admin-stats-item">
            <Newspaper size={13} />
            <span>Посты: <strong>{overview.posts_count}</strong></span>
            <span className="admin-stats-sub">{overview.published_posts_count} опубл · {overview.draft_posts_count} черн</span>
          </span>
          <span className="admin-stats-sep">|</span>
          <span className="admin-stats-item">
            <MapPinned size={13} />
            <span>Точки: <strong>{overview.map_points_count}</strong></span>
            <span className="admin-stats-sub">{overview.active_map_points_count} акт · {overview.hidden_map_points_count} скрыты</span>
          </span>
          <span className="admin-stats-sep">|</span>
          <span className="admin-stats-item">
            <UsersRound size={13} />
            <span>Пользователи: <strong>{overview.users_count}</strong></span>
            <span className="admin-stats-sub">{overview.admins_count} адм · {overview.banned_users_count} бан</span>
          </span>
        </div>
      ) : overviewLoading ? (
        <div className="admin-stats-bar is-loading"><LoadingBlock label="" /></div>
      ) : null}

      {globalError ? (
        <div className="form-banner is-error">
          <strong>Ошибка:</strong> {globalError}
        </div>
      ) : null}

      <section className="panel profile-panel">
        {/* ── Tabs ────────────────────────────────────────────────────────── */}
        <div className="admin-tabs">
          {(["posts", "map", "users"] as AdminTab[]).map((tab) => {
            const icons = { posts: <FileText size={14} />, map: <MapPinned size={14} />, users: <UsersRound size={14} /> };
            const labels = { posts: "Посты", map: "Точки карты", users: "Пользователи" };
            return (
              <button
                key={tab}
                type="button"
                className={`chip admin-tab-button ${activeTab === tab ? "is-active" : ""}`}
                onClick={() => setActiveTab(tab)}
              >
                {icons[tab]}
                <span>{labels[tab]}</span>
              </button>
            );
          })}
        </div>

        {/* ══════════ POSTS TAB ══════════ */}
        {activeTab === "posts" ? (
          <div className="profile-panel">
            {/* Inline filters */}
            <div className="admin-filters-row">
              <input
                className="admin-filter-search"
                value={postSearch}
                onChange={(e) => setPostSearch(e.target.value)}
                placeholder="Поиск по заголовку, тексту, автору"
              />
              <select
                className="admin-filter-select"
                value={postKind}
                onChange={(e) => setPostKind(e.target.value as "all" | PostListItem["kind"])}
              >
                <option value="all">Все типы</option>
                <option value="news">Новости</option>
                <option value="story">Истории</option>
                <option value="event">События</option>
              </select>
              <select
                className="admin-filter-select"
                value={postPublicationStatus}
                onChange={(e) => setPostPublicationStatus(e.target.value as PublicationStatus)}
              >
                <option value="all">Все статусы</option>
                <option value="published">Опубликованные</option>
                <option value="draft">Черновики</option>
              </select>
              <select
                className="admin-filter-select"
                value={postOrdering}
                onChange={(e) => setPostOrdering(e.target.value as PostOrdering)}
              >
                <option value="recent">По дате</option>
                <option value="popular">По популярности</option>
                <option value="recommended">По рекомендациям</option>
              </select>
              {posts ? <span className="admin-filter-count">{posts.count} постов</span> : null}
            </div>

            {/* Bulk action bar */}
            {selectedPostIds.size > 0 ? (
              <div className="admin-bulk-bar">
                <span className="admin-bulk-count">Выбрано: {selectedPostIds.size}</span>
                <button type="button" className="button button-sm button-muted" disabled={!!mutationKey} onClick={() => void handleBulkAction("publish")}>Опубликовать</button>
                <button type="button" className="button button-sm button-muted" disabled={!!mutationKey} onClick={() => void handleBulkAction("unpublish")}>В черновик</button>
                <button type="button" className="button button-sm button-danger" disabled={!!mutationKey} onClick={() => void handleBulkAction("delete")}>Удалить</button>
                <button type="button" className="button button-sm button-ghost" onClick={() => setSelectedPostIds(new Set())}>Снять выделение</button>
              </div>
            ) : null}

            {postsLoading && !posts ? <LoadingBlock label="Загружаю посты..." /> : null}
            {postsError ? (
              <EmptyState title="Не удалось загрузить посты" description={postsError}
                action={<button type="button" className="button button-primary" onClick={() => void loadPosts(1)}>Повторить</button>}
              />
            ) : null}

            {posts?.results.length ? (
              <>
                {/* Select all */}
                <label className="admin-select-all">
                  <input type="checkbox" checked={allPostsSelected} onChange={toggleAllPosts} />
                  <span>Выбрать все на странице</span>
                </label>

                <div className="admin-stack">
                  {posts.results.map((post) => (
                    <article key={post.id} className="admin-post-card">
                      <label className="admin-post-checkbox">
                        <input
                          type="checkbox"
                          checked={selectedPostIds.has(post.id)}
                          onChange={() => togglePostSelection(post.id)}
                        />
                      </label>
                      <div className="admin-post-body">
                        <div className="admin-post-head">
                          <PostStatusBadge post={post} />
                          <span className="chip admin-kind-chip">{getKindLabel(post.kind)}</span>
                          <span className="admin-post-title">{post.title || "Без заголовка"}</span>
                        </div>
                        <div className="admin-post-meta">
                          {post.author.name} · {formatDateTime(post.published_at)}
                        </div>
                        <div className="admin-post-metrics">
                          <span>👁 {compactCount(post.view_count)}</span>
                          <span>❤️ {compactCount(post.likes_count)}</span>
                          <span>💬 {compactCount(post.comments_count)}</span>
                        </div>
                      </div>
                      <div className="admin-post-actions">
                        <Link href={buildPostPath(post)} className="button button-muted button-inline button-sm">Открыть</Link>
                        <Link href={buildPostEditPath(post.id)} className="button button-muted button-inline button-sm">Изменить</Link>
                        <OverflowMenu
                          items={[
                            {
                              label: post.is_published ? "В черновик" : "Опубликовать",
                              disabled: mutationKey === `post-publish-${post.id}`,
                              onClick: () => void handleTogglePublished(post),
                            },
                            {
                              label: "Удалить",
                              danger: true,
                              disabled: mutationKey === `post-delete-${post.id}`,
                              onClick: () => void handleDeletePost(post.id),
                            },
                          ]}
                        />
                      </div>
                    </article>
                  ))}
                </div>

                <Pagination page={postsPage} total={posts.count} pageSize={POST_PAGE_SIZE} loading={postsLoading} onPage={(p) => void loadPosts(p)} />
              </>
            ) : (!postsLoading && !postsError) ? (
              <EmptyState title="Посты не найдены" description="Попробуйте изменить фильтры." />
            ) : null}
          </div>
        ) : null}

        {/* ══════════ USERS TAB ══════════ */}
        {activeTab === "users" ? (
          <div className="profile-panel">
            <div className="admin-filters-row">
              <input
                className="admin-filter-search"
                value={userSearch}
                onChange={(e) => setUserSearch(e.target.value)}
                placeholder="Имя, логин, email"
              />
              <select
                className="admin-filter-select"
                value={userRole}
                onChange={(e) => setUserRole(e.target.value as "all" | UserRole)}
              >
                <option value="all">Все роли</option>
                <option value="admin">Админы</option>
                <option value="support">Техподдержка</option>
                <option value="moderator">Модераторы</option>
                <option value="user">Пользователи</option>
              </select>
              <select
                className="admin-filter-select"
                value={userStatus}
                onChange={(e) => setUserStatus(e.target.value as UserStatusFilter)}
              >
                <option value="all">Все статусы</option>
                <option value="active">Активные</option>
                <option value="banned">Заблокированные</option>
                <option value="admin">С доступом к админке</option>
              </select>
              {users ? <span className="admin-filter-count">{users.count} аккаунтов</span> : null}
            </div>

            {usersLoading && !users ? <LoadingBlock label="Загружаю пользователей..." /> : null}
            {usersError ? (
              <EmptyState title="Не удалось загрузить пользователей" description={usersError}
                action={<button type="button" className="button button-primary" onClick={() => void loadUsers(1)}>Повторить</button>}
              />
            ) : null}

            {users?.results.length ? (
              <>
                <div className="admin-users-table-wrap">
                  <table className="admin-users-table">
                    <thead>
                      <tr>
                        <th>Пользователь</th>
                        <th>Роль</th>
                        <th>Статус</th>
                        <th>Зарегистрирован</th>
                        <th>Действия</th>
                      </tr>
                    </thead>
                    <tbody>
                      {users.results.map((adminUser) => (
                        <tr key={adminUser.id}>
                          <td>
                            <div className="admin-user-name">{adminUser.name || adminUser.username}</div>
                            <div className="admin-user-sub">@{adminUser.username} · {adminUser.email}</div>
                            {adminUser.warning_count > 0 ? (
                              <div className="admin-user-sub">⚠️ {adminUser.warning_count} предупреждений</div>
                            ) : null}
                          </td>
                          <td>
                            <select
                              className="admin-role-select"
                              value={adminUser.role}
                              disabled={mutationKey === `user-role-${adminUser.id}`}
                              onChange={(e) => void handleUserRoleChange(adminUser, e.target.value as UserRole)}
                            >
                              <option value="admin">Админ</option>
                              <option value="support">Техподдержка</option>
                              <option value="moderator">Модератор</option>
                              <option value="user">Пользователь</option>
                            </select>
                          </td>
                          <td>
                            {adminUser.is_banned ? (
                              <StatusBadge label="Забанен" color="red" />
                            ) : (
                              <StatusBadge label="Активен" color="green" />
                            )}
                          </td>
                          <td className="admin-user-date">{formatDateTime(adminUser.date_joined)}</td>
                          <td>
                            <div className="admin-user-mod-actions">
                              <button
                                type="button"
                                className="button button-ghost button-inline button-sm"
                                title="Предупредить"
                                disabled={mutationKey === `user-warn-${adminUser.id}`}
                                onClick={() => void handleUserModeration(adminUser, "warn")}
                              >
                                ⚠️
                              </button>
                              {adminUser.is_banned ? (
                                <button
                                  type="button"
                                  className="button button-ghost button-inline button-sm"
                                  title="Разблокировать"
                                  disabled={mutationKey === `user-unban-${adminUser.id}`}
                                  onClick={() => void handleUserModeration(adminUser, "unban")}
                                >
                                  🔓
                                </button>
                              ) : (
                                <button
                                  type="button"
                                  className="button button-danger button-inline button-sm"
                                  title="Заблокировать"
                                  disabled={mutationKey === `user-ban-${adminUser.id}`}
                                  onClick={() => void handleUserModeration(adminUser, "ban")}
                                >
                                  🚫
                                </button>
                              )}
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                <Pagination page={usersPage} total={users.count} pageSize={USER_PAGE_SIZE} loading={usersLoading} onPage={(p) => void loadUsers(p)} />
              </>
            ) : (!usersLoading && !usersError) ? (
              <EmptyState title="Пользователи не найдены" description="Проверьте фильтры." />
            ) : null}
          </div>
        ) : null}

        {/* ══════════ MAP TAB ══════════ */}
        {activeTab === "map" ? (
          <div className="profile-panel">
            {/* Mode switcher */}
            <div className="admin-map-mode-bar">
              <button
                type="button"
                className={`chip admin-map-mode-btn ${mapMode === "list" ? "is-active" : ""}`}
                onClick={() => setMapMode("list")}
              >
                Список точек
              </button>
              <button
                type="button"
                className={`chip admin-map-mode-btn ${mapMode === "create" ? "is-active" : ""}`}
                onClick={() => { setMapMode("create"); if (selectedPointId !== "new") return; resetPointEditor(); }}
              >
                {selectedPointId === "new" ? "Новая точка" : "Редактор точки"}
              </button>
            </div>

            {/* LIST MODE */}
            {mapMode === "list" ? (
              <>
                <div className="admin-filters-row">
                  <input
                    className="admin-filter-search"
                    value={pointSearch}
                    onChange={(e) => setPointSearch(e.target.value)}
                    placeholder="Slug, название, адрес"
                    onBlur={() => void Promise.all([loadPoints(), loadUserMarkers()])}
                  />
                  <select
                    className="admin-filter-select"
                    value={pointStatus}
                    onChange={(e) => { setPointStatus(e.target.value as PointStatusFilter); void Promise.all([loadPoints(), loadUserMarkers()]); }}
                  >
                    <option value="all">Все точки</option>
                    <option value="active">Активные</option>
                    <option value="hidden">Скрытые</option>
                  </select>
                  <select
                    className="admin-filter-select"
                    value={pointCategoryFilter === "all" ? "all" : String(pointCategoryFilter)}
                    onChange={(e) => { setPointCategoryFilter(e.target.value === "all" ? "all" : Number(e.target.value)); void loadPoints(); }}
                  >
                    <option value="all">Все категории</option>
                    {categories.map((c) => <option key={c.id} value={c.id}>{c.title}</option>)}
                  </select>
                  <button
                    type="button"
                    className="button button-muted button-sm"
                    onClick={() => { resetPointEditor(); setMapMode("create"); }}
                  >
                    <Plus size={13} /> Новая точка
                  </button>
                </div>

                {pointsLoading && !points ? <LoadingBlock label="Загружаю точки..." /> : null}
                {pointsError ? (
                  <EmptyState title="Не удалось загрузить точки" description={pointsError}
                    action={<button type="button" className="button button-primary" onClick={() => void loadPoints()}>Повторить</button>}
                  />
                ) : null}

                <div className="admin-point-list">
                  {points?.results.map((point) => (
                    <button
                      key={point.id}
                      type="button"
                      className="point-row admin-point-row"
                      onClick={() => handlePointSelection(point)}
                    >
                      <div className="admin-point-row-head">
                        <strong>{point.title}</strong>
                        {point.is_active
                          ? <StatusBadge label="Активна" color="green" />
                          : <StatusBadge label="Скрыта" color="yellow" />}
                      </div>
                      <p className="muted">{point.address || point.slug}</p>
                      <div className="map-category-row">
                        {point.categories.map((cat) => (
                          <span key={cat.id} className="map-category-chip">
                            <span className="map-category-chip-dot" style={{ backgroundColor: cat.color }} />
                            <span>{cat.title}</span>
                          </span>
                        ))}
                      </div>
                    </button>
                  ))}
                </div>

                {/* User markers section */}
                <div className="admin-subsection-head">
                  <h3>Метки пользователей</h3>
                  <span className="admin-filter-count">{userMarkers?.count ?? 0}</span>
                </div>

                {userMarkersLoading && !userMarkers ? <LoadingBlock label="Загружаю метки..." /> : null}
                {userMarkersError ? (
                  <EmptyState title="Не удалось загрузить метки" description={userMarkersError}
                    action={<button type="button" className="button button-primary" onClick={() => void loadUserMarkers()}>Повторить</button>}
                  />
                ) : null}

                <div className="admin-point-list">
                  {userMarkers?.results.map((marker) => (
                    <article key={marker.id} className="point-row admin-user-marker-row">
                      <div className="admin-marker-row">
                        <div className="admin-marker-body">
                          <div className="admin-point-row-head">
                            <strong>{marker.title}</strong>
                            {marker.is_active && marker.is_public
                              ? <StatusBadge label="Видна" color="green" />
                              : <StatusBadge label="Скрыта" color="yellow" />}
                          </div>
                          <p className="muted">
                            {marker.author?.name || marker.author?.username || "—"} ·{" "}
                            {marker.latitude.toFixed(4)}, {marker.longitude.toFixed(4)}
                          </p>
                          <div className="admin-post-metrics">
                            <span>💬 {marker.comments_count}</span>
                            <span>🚨 {marker.reports_count}</span>
                            <span>🖼 {marker.media.length}</span>
                          </div>
                          <div className="admin-post-actions" style={{ marginTop: 6 }}>
                            <button
                              type="button"
                              className="button button-muted button-inline button-sm"
                              disabled={mutationKey === `user-marker-toggle-${marker.id}`}
                              onClick={() => void handleToggleUserMarker(marker)}
                            >
                              {marker.is_active ? "Скрыть" : "Показать"}
                            </button>
                            <button
                              type="button"
                              className="button button-danger button-inline button-sm"
                              disabled={mutationKey === `user-marker-delete-${marker.id}`}
                              onClick={() => void handleDeleteUserMarker(marker)}
                            >
                              Удалить
                            </button>
                          </div>
                        </div>
                      </div>
                    </article>
                  ))}
                </div>
              </>
            ) : null}

            {/* CREATE / EDIT MODE */}
            {mapMode === "create" ? (
              <div className="admin-point-editor">
                <div className="admin-point-editor-head">
                  <h3>{selectedPointId === "new" ? "Новая точка" : "Редактор точки"}</h3>
                  <div className="admin-post-actions">
                    {selectedPointId !== "new" ? (
                      <button
                        type="button"
                        className="button button-danger button-inline"
                        disabled={mutationKey === `point-delete-${selectedPointId}`}
                        onClick={() => void handleDeletePoint()}
                      >
                        Удалить
                      </button>
                    ) : null}
                    <button
                      type="button"
                      className="button button-primary button-inline"
                      disabled={mutationKey === "point-create" || (selectedPointId !== "new" && mutationKey === `point-save-${selectedPointId}`)}
                      onClick={() => void handleSavePoint()}
                    >
                      {selectedPointId === "new" ? "Создать" : "Сохранить"}
                    </button>
                  </div>
                </div>

                <PointSection title="Основное">
                  <div className="two-columns">
                    <label className="field">
                      <span>Название</span>
                      <input value={pointForm.title} onChange={(e) => setPointForm((c) => ({ ...c, title: e.target.value }))} placeholder="Экопункт на Покровке" />
                    </label>
                    <label className="field">
                      <span>Slug</span>
                      <input value={pointForm.slug} onChange={(e) => setPointForm((c) => ({ ...c, slug: e.target.value }))} placeholder="pokrovka-ecopoint" />
                    </label>
                  </div>
                  <label className="field">
                    <span>Краткое описание</span>
                    <input value={pointForm.short_description} onChange={(e) => setPointForm((c) => ({ ...c, short_description: e.target.value }))} placeholder="Что принимает точка" />
                  </label>
                  <label className="field">
                    <span>Описание</span>
                    <textarea value={pointForm.description} onChange={(e) => setPointForm((c) => ({ ...c, description: e.target.value }))} placeholder="Подробности для пользователей" />
                  </label>
                  <div className="two-columns">
                    <label className="field">
                      <span>Адрес</span>
                      <input value={pointForm.address} onChange={(e) => setPointForm((c) => ({ ...c, address: e.target.value }))} placeholder="Большая Покровская, 12" />
                    </label>
                    <label className="field">
                      <span>Часы работы</span>
                      <input value={pointForm.working_hours} onChange={(e) => setPointForm((c) => ({ ...c, working_hours: e.target.value }))} placeholder="пн-пт 10:00–18:00" />
                    </label>
                  </div>
                  <div className="two-columns">
                    <label className="field">
                      <span>Статус</span>
                      <select value={pointForm.is_active ? "active" : "hidden"} onChange={(e) => setPointForm((c) => ({ ...c, is_active: e.target.value === "active" }))}>
                        <option value="active">Активна</option>
                        <option value="hidden">Скрыта</option>
                      </select>
                    </label>
                    <label className="field">
                      <span>Порядок сортировки</span>
                      <input value={pointForm.sort_order} onChange={(e) => setPointForm((c) => ({ ...c, sort_order: e.target.value }))} placeholder="0" />
                    </label>
                  </div>
                </PointSection>

                <PointSection title="Координаты">
                  <div className="two-columns">
                    <label className="field">
                      <span>Широта</span>
                      <input value={pointForm.latitude} onChange={(e) => setPointForm((c) => ({ ...c, latitude: e.target.value }))} placeholder="56.320123" />
                    </label>
                    <label className="field">
                      <span>Долгота</span>
                      <input value={pointForm.longitude} onChange={(e) => setPointForm((c) => ({ ...c, longitude: e.target.value }))} placeholder="44.012345" />
                    </label>
                  </div>
                </PointSection>

                <PointSection title="Категории">
                  <div className="admin-category-actions">
                    <button type="button" className="button button-ghost button-inline" disabled={!categories.length} onClick={() => setPointCategories(categories.map((c) => c.id))}>Выбрать все</button>
                    <button type="button" className="button button-ghost button-inline" disabled={!pointForm.category_ids.length} onClick={() => setPointCategories([])}>Очистить</button>
                  </div>
                  <div className="admin-category-grid">
                    {!categories.length ? <p className="muted admin-category-empty">Категорий пока нет.</p> : null}
                    {categories.map((cat) => {
                      const isSelected = pointForm.category_ids.includes(cat.id);
                      return (
                        <label key={cat.id} className={`map-category-chip admin-category-option ${isSelected ? "is-active" : ""}`}>
                          <input
                            className="visually-hidden"
                            type="checkbox"
                            checked={isSelected}
                            onChange={(e) => setPointCategories(e.target.checked ? [...pointForm.category_ids, cat.id] : pointForm.category_ids.filter((id) => id !== cat.id))}
                          />
                          <span className="map-category-chip-dot" style={{ backgroundColor: cat.color }} />
                          <span>{cat.title}</span>
                          {isSelected ? <Check className="admin-category-check" /> : null}
                        </label>
                      );
                    })}
                  </div>
                </PointSection>

                <PointSection title="Дополнительно" defaultOpen={false}>
                  <label className="field">
                    <span>Цвет метки</span>
                    <div className="admin-color-input-row">
                      <input className="admin-color-picker" type="color" value={normalizeHexColor(pointForm.marker_color)} onChange={(e) => setPointForm((c) => ({ ...c, marker_color: e.target.value.toUpperCase() }))} aria-label="Цвет точки" />
                      <input value={pointForm.marker_color} onChange={(e) => setPointForm((c) => ({ ...c, marker_color: e.target.value.toUpperCase() }))} placeholder="#2D6A4F" />
                    </div>
                  </label>
                  <label className="field">
                    <span>Изображения (одна ссылка на строку)</span>
                    <textarea value={pointForm.image_urls_text} onChange={(e) => setPointForm((c) => ({ ...c, image_urls_text: e.target.value }))} placeholder="https://..." />
                  </label>
                </PointSection>

                {/* Category editor */}
                <PointSection title="Управление категориями" defaultOpen={false}>
                  <div className="admin-category-editor">
                    <div className="admin-category-list">
                      <button type="button" className={`point-row admin-category-row ${selectedCategoryId === "new" ? "is-active" : ""}`} onClick={() => { setSelectedCategoryId("new"); setCategoryForm(createEmptyCategoryForm()); }}>
                        <strong>+ Новая категория</strong>
                      </button>
                      {categories.map((cat) => (
                        <button key={cat.id} type="button" className={`point-row admin-category-row ${selectedCategoryId === cat.id ? "is-active" : ""}`} onClick={() => { setSelectedCategoryId(cat.id); setCategoryForm(categoryToForm(cat)); }}>
                          <div className="admin-point-row-head">
                            <span className="map-category-chip-dot" style={{ backgroundColor: cat.color }} />
                            <strong>{cat.title}</strong>
                          </div>
                          <p className="muted">{cat.slug}</p>
                        </button>
                      ))}
                    </div>
                    <div className="admin-category-form">
                      <label className="field"><span>Название</span><input value={categoryForm.title} onChange={(e) => setCategoryForm((c) => ({ ...c, title: e.target.value }))} placeholder="Экоцентры" /></label>
                      <label className="field"><span>Slug</span><input value={categoryForm.slug} onChange={(e) => setCategoryForm((c) => ({ ...c, slug: e.target.value }))} placeholder="eco-center" /></label>
                      <label className="field"><span>Порядок</span><input value={categoryForm.sort_order} onChange={(e) => setCategoryForm((c) => ({ ...c, sort_order: e.target.value }))} placeholder="0" /></label>
                      <label className="field">
                        <span>Цвет</span>
                        <div className="admin-color-input-row">
                          <input className="admin-color-picker" type="color" value={normalizeHexColor(categoryForm.color)} onChange={(e) => setCategoryForm((c) => ({ ...c, color: e.target.value.toUpperCase() }))} aria-label="Цвет категории" />
                          <input value={categoryForm.color} onChange={(e) => setCategoryForm((c) => ({ ...c, color: e.target.value.toUpperCase() }))} placeholder="#2D6A4F" />
                        </div>
                      </label>
                      <div className="post-actions">
                        <button type="button" className="button button-muted" onClick={() => { setSelectedCategoryId("new"); setCategoryForm(createEmptyCategoryForm()); }}>Очистить</button>
                        {selectedCategoryId !== "new" ? (
                          <button type="button" className="button button-danger" disabled={mutationKey === `category-delete-${selectedCategoryId}`} onClick={() => void handleDeleteCategory()}>Удалить</button>
                        ) : null}
                        <button
                          type="button"
                          className="button button-primary"
                          disabled={mutationKey === "category-create" || (selectedCategoryId !== "new" && mutationKey === `category-save-${selectedCategoryId}`)}
                          onClick={() => void handleSaveCategory()}
                        >
                          {selectedCategoryId === "new" ? "Создать" : "Сохранить"}
                        </button>
                      </div>
                    </div>
                  </div>
                </PointSection>

                <button type="button" className="button button-ghost button-inline" onClick={() => { resetPointEditor(); setMapMode("list"); }}>
                  ← Вернуться к списку
                </button>
              </div>
            ) : null}
          </div>
        ) : null}
      </section>
    </AppShell>
  );
}
