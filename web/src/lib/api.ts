"use client";

import { API_BASE_URL } from "@/lib/config";
import type {
  AdminMapCategoryWritePayload,
  AdminMapPoint,
  AdminMapPointWritePayload,
  AdminOverview,
  AdminUserMapMarker,
  AdminUser,
  AuthSession,
  CurrentUser,
  EventCalendarResponse,
  FeedFilters,
  HelpDocument,
  HelpCenterResponse,
  MapPointDetail,
  MapPointCategory,
  MapOverviewResponse,
  NotificationResponse,
  PaginatedResponse,
  PostDetail,
  PostListItem,
  PostWritePayload,
  ProfileUpdatePayload,
  SupportBotReplyResponse,
  SupportKnowledgeResponse,
  SupportReport,
  SocialProvidersResponse,
  SupportThreadDetail,
  SupportThreadSummary,
  UserSummary,
  UserMapMarkerDetail,
  UserMapMarkerWritePayload,
} from "@/lib/types";

type RequestOptions = RequestInit & {
  auth?: boolean;
  retry?: boolean;
};

function buildUrl(path: string, searchParams?: URLSearchParams): string {
  const normalizedPath = path.startsWith("/") ? path : `/${path}`;
  const query = searchParams?.toString();
  return `${API_BASE_URL}${normalizedPath}${query ? `?${query}` : ""}`;
}

export class ApiError extends Error {
  status: number;
  data: unknown;

  constructor(message: string, status: number, data: unknown) {
    super(message);
    this.status = status;
    this.data = data;
  }
}

async function parseResponse<T>(response: Response): Promise<T> {
  const contentType = response.headers.get("content-type") ?? "";
  const data = contentType.includes("application/json")
    ? await response.json()
    : await response.text();

  if (!response.ok) {
    const detail =
      typeof data === "object" && data && "detail" in data
        ? String((data as { detail: unknown }).detail)
        : response.statusText || "Request failed";
    throw new ApiError(detail, response.status, data);
  }

  return data as T;
}

async function refreshAccessToken(): Promise<boolean> {
  const response = await fetch(buildUrl("/auth/refresh"), {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({}),
    credentials: "include",
  });

  if (!response.ok) {
    return false;
  }

  return true;
}

async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const headers = new Headers(options.headers ?? {});

  headers.set("Accept", "application/json");
  if (!(options.body instanceof FormData)) {
    headers.set("Content-Type", "application/json");
  }

  const response = await fetch(buildUrl(path), {
    ...options,
    headers,
    credentials: "include",
  });

  if (response.status === 401 && options.auth && options.retry !== false) {
    const refreshed = await refreshAccessToken();
    if (refreshed) {
      return request<T>(path, { ...options, retry: false });
    }
  }

  return parseResponse<T>(response);
}

export async function fetchMe(): Promise<CurrentUser> {
  return request<CurrentUser>("/auth/me", { auth: true });
}

export async function login(payload: { identifier: string; password: string }): Promise<AuthSession> {
  return request<AuthSession>("/auth/login", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function register(payload: {
  username: string;
  email: string;
  display_name?: string;
  phone?: string;
  password: string;
  password_confirmation: string;
  accept_terms: boolean;
  accept_privacy_policy: boolean;
  accept_personal_data: boolean;
  accept_public_personal_data_distribution?: boolean;
}): Promise<AuthSession> {
  return request<AuthSession>("/auth/register", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function logout(): Promise<void> {
  try {
    await request<void>("/auth/logout", {
      method: "POST",
      body: JSON.stringify({}),
    });
  } catch {
    // ignore server logout errors, UI state is still cleared locally
  }
}

export async function requestPasswordReset(identifier: string): Promise<{ detail: string }> {
  return request("/auth/password-reset/request", {
    method: "POST",
    body: JSON.stringify({ identifier }),
  });
}

export async function changePassword(payload: {
  current_password: string;
  new_password: string;
  new_password_confirmation: string;
}): Promise<AuthSession> {
  return request<AuthSession>("/auth/change-password", {
    method: "POST",
    auth: true,
    body: JSON.stringify(payload),
  });
}

function buildFeedApiSearchParams(filters: FeedFilters = {}): URLSearchParams {
  const params = new URLSearchParams();
  if (filters.search) params.set("search", filters.search);
  if (filters.ordering) params.set("ordering", filters.ordering);
  if (filters.kind) params.set("kind", filters.kind);
  if (typeof filters.author_id === "number") params.set("author_id", String(filters.author_id));
  if (filters.favorites_only) params.set("favorites_only", "true");
  if (filters.has_images) params.set("has_images", "true");
  if (filters.event_scope) params.set("event_scope", filters.event_scope);
  if (filters.page) params.set("page", String(filters.page));
  return params;
}

export async function listPosts(filters: FeedFilters = {}, auth = false): Promise<PaginatedResponse<PostListItem>> {
  const params = buildFeedApiSearchParams(filters);
  const url = `/posts${params.size ? `?${params.toString()}` : ""}`;
  return request<PaginatedResponse<PostListItem>>(url, { auth });
}

export async function getPost(postId: number, auth = false): Promise<PostDetail> {
  return request<PostDetail>(`/posts/${postId}`, { auth });
}

export async function getEventCalendar(
  year: number,
  month: number,
  auth = false,
): Promise<EventCalendarResponse> {
  const params = new URLSearchParams({
    year: String(year),
    month: String(month),
  });
  return request<EventCalendarResponse>(`/posts/calendar?${params.toString()}`, { auth });
}

export async function toggleLike(postId: number, isLiked: boolean): Promise<void> {
  await request(`/posts/${postId}/like`, {
    method: isLiked ? "DELETE" : "POST",
    auth: true,
  });
}

export async function toggleFavorite(postId: number, isFavorited: boolean): Promise<void> {
  await request(`/posts/${postId}/favorite`, {
    method: isFavorited ? "DELETE" : "POST",
    auth: true,
  });
}

export async function createComment(postId: number, body: string): Promise<void> {
  await request(`/posts/${postId}/comments`, {
    method: "POST",
    auth: true,
    body: JSON.stringify({ body }),
  });
}

export async function updateComment(
  postId: number,
  commentId: number,
  body: string,
): Promise<void> {
  await request(`/posts/${postId}/comments/${commentId}`, {
    method: "PATCH",
    auth: true,
    body: JSON.stringify({ body }),
  });
}

export async function deleteComment(postId: number, commentId: number): Promise<void> {
  await request(`/posts/${postId}/comments/${commentId}`, {
    method: "DELETE",
    auth: true,
  });
}

export async function createPost(payload: PostWritePayload): Promise<PostDetail> {
  return request<PostDetail>("/posts", {
    method: "POST",
    auth: true,
    body: JSON.stringify(payload),
  });
}

export async function updatePost(postId: number, payload: PostWritePayload): Promise<PostDetail> {
  return request<PostDetail>(`/posts/${postId}`, {
    method: "PATCH",
    auth: true,
    body: JSON.stringify(payload),
  });
}

export async function setEventCancelled(
  postId: number,
  isCancelled: boolean,
): Promise<PostDetail> {
  return request<PostDetail>(`/posts/${postId}/cancel`, {
    method: isCancelled ? "POST" : "DELETE",
    auth: true,
  });
}

export async function deletePost(postId: number): Promise<void> {
  await request(`/posts/${postId}`, {
    method: "DELETE",
    auth: true,
  });
}

export async function getAdminOverview(): Promise<AdminOverview> {
  return request<AdminOverview>("/admin/overview", { auth: true });
}

export async function listAdminPosts(filters: {
  search?: string;
  kind?: "news" | "event" | "story";
  is_published?: boolean;
  ordering?: "recent" | "popular" | "recommended";
  page?: number;
}): Promise<PaginatedResponse<PostListItem>> {
  const params = new URLSearchParams();
  if (filters.search) params.set("search", filters.search);
  if (filters.kind) params.set("kind", filters.kind);
  if (typeof filters.is_published === "boolean") {
    params.set("is_published", String(filters.is_published));
  }
  if (filters.ordering) params.set("ordering", filters.ordering);
  if (filters.page) params.set("page", String(filters.page));

  const url = `/admin/posts${params.size ? `?${params.toString()}` : ""}`;
  return request<PaginatedResponse<PostListItem>>(url, { auth: true });
}

export async function bulkAdminPosts(payload: {
  action: "publish" | "unpublish" | "delete";
  ids: number[];
}): Promise<{ affected: number }> {
  return request<{ affected: number }>("/admin/posts/bulk", {
    auth: true,
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function listAdminUsers(filters: {
  search?: string;
  role?: UserSummary["role"];
  status?: "active" | "banned" | "admin";
  page?: number;
}): Promise<PaginatedResponse<AdminUser>> {
  const params = new URLSearchParams();
  if (filters.search) params.set("search", filters.search);
  if (filters.role) params.set("role", filters.role);
  if (filters.status) params.set("status", filters.status);
  if (filters.page) params.set("page", String(filters.page));

  const url = `/admin/users${params.size ? `?${params.toString()}` : ""}`;
  return request<PaginatedResponse<AdminUser>>(url, { auth: true });
}

export async function warnUser(userId: number): Promise<CurrentUser> {
  return request<CurrentUser>(`/users/${userId}/warn`, {
    method: "POST",
    auth: true,
  });
}

export async function banUser(userId: number): Promise<CurrentUser> {
  return request<CurrentUser>(`/users/${userId}/ban`, {
    method: "POST",
    auth: true,
  });
}

export async function unbanUser(userId: number): Promise<CurrentUser> {
  return request<CurrentUser>(`/users/${userId}/unban`, {
    method: "POST",
    auth: true,
  });
}

export async function updateUserRole(
  userId: number,
  role: UserSummary["role"],
): Promise<CurrentUser> {
  return request<CurrentUser>(`/users/${userId}/role`, {
    method: "PATCH",
    auth: true,
    body: JSON.stringify({ role }),
  });
}

export async function listNotifications(): Promise<NotificationResponse> {
  return request<NotificationResponse>("/notifications", { auth: true });
}

export async function readAllNotifications(): Promise<void> {
  await request("/notifications/read-all", {
    method: "POST",
    auth: true,
  });
}

export async function readNotification(notificationId: number): Promise<void> {
  await request(`/notifications/${notificationId}/read`, {
    method: "POST",
    auth: true,
  });
}

export async function getSupportKnowledge(): Promise<SupportKnowledgeResponse> {
  return request<SupportKnowledgeResponse>("/support/knowledge");
}

export async function getSocialProviders(payload?: {
  redirect_uri?: string;
  state?: string;
}): Promise<SocialProvidersResponse> {
  const params = new URLSearchParams();
  if (payload?.redirect_uri) params.set("redirect_uri", payload.redirect_uri);
  if (payload?.state) params.set("state", payload.state);
  const url = `/auth/social/providers${params.size ? `?${params.toString()}` : ""}`;
  return request<SocialProvidersResponse>(url);
}

export async function loginWithSocial(payload: {
  provider: string;
  code?: string;
  access_token?: string;
  redirect_uri?: string;
  email?: string;
  accept_terms?: boolean;
  accept_privacy_policy?: boolean;
  accept_personal_data?: boolean;
  accept_public_personal_data_distribution?: boolean;
}): Promise<AuthSession> {
  const { provider, ...body } = payload;
  return request<AuthSession>(`/auth/social/${provider}`, {
    method: "POST",
    body: JSON.stringify(body),
  });
}

export async function getHelpCenterContent(): Promise<HelpCenterResponse> {
  return request<HelpCenterResponse>("/support/help-center");
}

export async function getHelpDocument(slug: string): Promise<HelpDocument> {
  return request<HelpDocument>(`/support/help-center/${slug}`);
}

export async function askSupportBot(query: string): Promise<SupportBotReplyResponse> {
  return request<SupportBotReplyResponse>("/support/bot/reply", {
    method: "POST",
    body: JSON.stringify({ query }),
  });
}

export async function listSupportThreads(): Promise<SupportThreadSummary[]> {
  return request<SupportThreadSummary[]>("/support/threads", { auth: true });
}

export async function createSupportThread(payload: {
  subject: string;
  body: string;
  category?: "general" | "account" | "content" | "map" | "report";
}): Promise<SupportThreadDetail> {
  return request<SupportThreadDetail>("/support/threads", {
    method: "POST",
    auth: true,
    body: JSON.stringify(payload),
  });
}

export async function getSupportThread(threadId: number): Promise<SupportThreadDetail> {
  return request<SupportThreadDetail>(`/support/threads/${threadId}`, { auth: true });
}

export async function sendSupportMessage(
  threadId: number,
  body: string,
): Promise<void> {
  await request(`/support/threads/${threadId}/messages`, {
    method: "POST",
    auth: true,
    body: JSON.stringify({ body }),
  });
}

export async function listSupportTeamThreads(): Promise<SupportThreadSummary[]> {
  return request<SupportThreadSummary[]>("/support/team/threads", { auth: true });
}

export async function updateSupportTeamThread(
  threadId: number,
  payload: { status?: SupportThreadSummary["status"]; assigned_to_id?: number | null },
): Promise<SupportThreadDetail> {
  return request<SupportThreadDetail>(`/support/team/threads/${threadId}`, {
    method: "PATCH",
    auth: true,
    body: JSON.stringify(payload),
  });
}

export async function createContentReport(payload: {
  target_type: "post" | "comment" | "map_review" | "user_marker" | "user_marker_comment";
  target_id: number;
  reason: "spam" | "abuse" | "misinformation" | "dangerous" | "copyright" | "other";
  details?: string;
}): Promise<SupportReport> {
  return request<SupportReport>("/support/reports", {
    method: "POST",
    auth: true,
    body: JSON.stringify(payload),
  });
}

export async function createPostReport(
  postId: number,
  payload: { reason: "spam" | "abuse" | "misinformation" | "dangerous" | "copyright" | "other"; details?: string },
): Promise<SupportReport> {
  return request<SupportReport>(`/posts/${postId}/report`, {
    method: "POST",
    auth: true,
    body: JSON.stringify(payload),
  });
}

export async function createCommentReport(
  postId: number,
  commentId: number,
  payload: { reason: "spam" | "abuse" | "misinformation" | "dangerous" | "copyright" | "other"; details?: string },
): Promise<SupportReport> {
  return request<SupportReport>(`/posts/${postId}/comments/${commentId}/report`, {
    method: "POST",
    auth: true,
    body: JSON.stringify(payload),
  });
}

export async function createMapReviewReport(
  pointId: number,
  reviewId: number,
  payload: { reason: "spam" | "abuse" | "misinformation" | "dangerous" | "copyright" | "other"; details?: string },
): Promise<SupportReport> {
  return request<SupportReport>(`/map/points/${pointId}/reviews/${reviewId}/report`, {
    method: "POST",
    auth: true,
    body: JSON.stringify(payload),
  });
}

export async function createUserMapMarkerReport(
  markerId: number,
  payload: { reason: "spam" | "abuse" | "misinformation" | "dangerous" | "copyright" | "other"; details?: string },
): Promise<SupportReport> {
  return request<SupportReport>(`/map/user-markers/${markerId}/report`, {
    method: "POST",
    auth: true,
    body: JSON.stringify(payload),
  });
}

export async function createUserMapMarkerCommentReport(
  markerId: number,
  commentId: number,
  payload: { reason: "spam" | "abuse" | "misinformation" | "dangerous" | "copyright" | "other"; details?: string },
): Promise<SupportReport> {
  return request<SupportReport>(`/map/user-markers/${markerId}/comments/${commentId}/report`, {
    method: "POST",
    auth: true,
    body: JSON.stringify(payload),
  });
}

export async function listSupportTeamReports(): Promise<SupportReport[]> {
  return request<SupportReport[]>("/support/team/reports", { auth: true });
}

export async function updateSupportTeamReport(
  reportId: number,
  payload: {
    status: SupportReport["status"];
    resolution_note?: string;
    remove_target?: boolean;
  },
): Promise<SupportReport> {
  return request<SupportReport>(`/support/team/reports/${reportId}`, {
    method: "PATCH",
    auth: true,
    body: JSON.stringify(payload),
  });
}

export async function listUsers(search: string): Promise<UserSummary[]> {
  const params = new URLSearchParams();
  if (search) {
    params.set("search", search);
  }
  const url = `/users${params.size ? `?${params.toString()}` : ""}`;
  return request<UserSummary[]>(url);
}

export async function getPublicProfile(userId: number, auth = false): Promise<CurrentUser> {
  return request<CurrentUser>(`/profiles/${userId}`, { auth });
}

export async function updateProfile(payload: ProfileUpdatePayload): Promise<CurrentUser> {
  return request<CurrentUser>("/auth/me", {
    method: "PATCH",
    auth: true,
    body: JSON.stringify(payload),
  });
}

export async function uploadImages(files: File[]): Promise<string[]> {
  const uploaded: string[] = [];

  for (const file of files) {
    const formData = new FormData();
    formData.append("file", file);
    const result = await request<{ url: string }>("/uploads/images", {
      method: "POST",
      auth: true,
      body: formData,
    });
    uploaded.push(result.url);
  }

  return uploaded;
}

export async function getMapOverview(): Promise<MapOverviewResponse> {
  return request<MapOverviewResponse>("/map/overview");
}

export async function getMapPointDetail(pointId: number): Promise<MapPointDetail> {
  return request<MapPointDetail>(`/map/points/${pointId}`);
}

export async function createMapPointReview(
  pointId: number,
  payload: { rating: number; body: string; image_urls?: string[] },
): Promise<void> {
  await request(`/map/points/${pointId}/reviews`, {
    method: "POST",
    auth: true,
    body: JSON.stringify(payload),
  });
}

export async function deleteMapPointReview(pointId: number, reviewId: number): Promise<void> {
  await request(`/map/points/${pointId}/reviews/${reviewId}`, {
    method: "DELETE",
    auth: true,
  });
}

export async function getUserMapMarkerDetail(markerId: number): Promise<UserMapMarkerDetail> {
  return request<UserMapMarkerDetail>(`/map/user-markers/${markerId}`, { auth: true });
}

export async function createUserMapMarker(
  payload: UserMapMarkerWritePayload,
): Promise<UserMapMarkerDetail> {
  return request<UserMapMarkerDetail>("/map/user-markers", {
    method: "POST",
    auth: true,
    body: JSON.stringify(payload),
  });
}

export async function createUserMapMarkerComment(
  markerId: number,
  body: string,
): Promise<void> {
  await request(`/map/user-markers/${markerId}/comments`, {
    method: "POST",
    auth: true,
    body: JSON.stringify({ body }),
  });
}

export async function listAdminMapCategories(): Promise<MapPointCategory[]> {
  return request<MapPointCategory[]>("/admin/map/categories", { auth: true });
}

export async function createAdminMapCategory(
  payload: AdminMapCategoryWritePayload,
): Promise<MapPointCategory> {
  return request<MapPointCategory>("/admin/map/categories", {
    method: "POST",
    auth: true,
    body: JSON.stringify(payload),
  });
}

export async function updateAdminMapCategory(
  categoryId: number,
  payload: Partial<AdminMapCategoryWritePayload>,
): Promise<MapPointCategory> {
  return request<MapPointCategory>(`/admin/map/categories/${categoryId}`, {
    method: "PATCH",
    auth: true,
    body: JSON.stringify(payload),
  });
}

export async function deleteAdminMapCategory(categoryId: number): Promise<void> {
  await request(`/admin/map/categories/${categoryId}`, {
    method: "DELETE",
    auth: true,
  });
}

export async function listAdminMapPoints(filters: {
  search?: string;
  is_active?: boolean;
  category_id?: number;
  page_size?: number;
}): Promise<PaginatedResponse<AdminMapPoint>> {
  const params = new URLSearchParams();
  if (filters.search) params.set("search", filters.search);
  if (typeof filters.is_active === "boolean") {
    params.set("is_active", String(filters.is_active));
  }
  if (typeof filters.category_id === "number") {
    params.set("category_id", String(filters.category_id));
  }
  if (typeof filters.page_size === "number") {
    params.set("page_size", String(filters.page_size));
  }

  const url = `/admin/map/points${params.size ? `?${params.toString()}` : ""}`;
  return request<PaginatedResponse<AdminMapPoint>>(url, { auth: true });
}

export async function createAdminMapPoint(
  payload: AdminMapPointWritePayload,
): Promise<AdminMapPoint> {
  return request<AdminMapPoint>("/admin/map/points", {
    method: "POST",
    auth: true,
    body: JSON.stringify(payload),
  });
}

export async function updateAdminMapPoint(
  pointId: number,
  payload: AdminMapPointWritePayload,
): Promise<AdminMapPoint> {
  return request<AdminMapPoint>(`/admin/map/points/${pointId}`, {
    method: "PATCH",
    auth: true,
    body: JSON.stringify(payload),
  });
}

export async function deleteAdminMapPoint(pointId: number): Promise<void> {
  await request(`/admin/map/points/${pointId}`, {
    method: "DELETE",
    auth: true,
  });
}

export async function listAdminUserMapMarkers(filters: {
  search?: string;
  is_active?: boolean;
  page_size?: number;
}): Promise<PaginatedResponse<AdminUserMapMarker>> {
  const params = new URLSearchParams();
  if (filters.search) params.set("search", filters.search);
  if (typeof filters.is_active === "boolean") {
    params.set("is_active", String(filters.is_active));
  }
  if (typeof filters.page_size === "number") {
    params.set("page_size", String(filters.page_size));
  }

  const url = `/admin/map/user-markers${params.size ? `?${params.toString()}` : ""}`;
  return request<PaginatedResponse<AdminUserMapMarker>>(url, { auth: true });
}

export async function updateAdminUserMapMarker(
  markerId: number,
  payload: { is_active?: boolean; is_public?: boolean; moderation_note?: string },
): Promise<AdminUserMapMarker> {
  return request<AdminUserMapMarker>(`/admin/map/user-markers/${markerId}`, {
    method: "PATCH",
    auth: true,
    body: JSON.stringify(payload),
  });
}

export async function deleteAdminUserMapMarker(markerId: number): Promise<void> {
  await request(`/admin/map/user-markers/${markerId}`, {
    method: "DELETE",
    auth: true,
  });
}

export async function uploadMedia(files: File[]): Promise<UserMapMarkerWritePayload["media"]> {
  const uploaded: NonNullable<UserMapMarkerWritePayload["media"]> = [];

  for (const file of files) {
    const formData = new FormData();
    formData.append("file", file);
    const result = await request<{ url: string; media_type: "image" | "video" }>("/uploads/media", {
      method: "POST",
      auth: true,
      body: formData,
    });
    uploaded.push({
      media_url: result.url,
      media_type: result.media_type,
      caption: "",
    });
  }

  return uploaded;
}
