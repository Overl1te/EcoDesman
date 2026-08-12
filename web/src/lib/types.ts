export type UserRole = "admin" | "support" | "moderator" | "user";

export interface UserStats {
  posts_count: number;
  likes_given_count?: number;
  likes_received_count: number;
  comments_count: number;
  views_received_count: number;
}

export interface UserSummary {
  id: number;
  name: string;
  username: string;
  role: UserRole;
  status_text: string;
  avatar_url: string;
  warning_count: number;
  is_banned: boolean;
}

export interface CurrentUser extends UserSummary {
  email: string;
  phone: string | null;
  bio: string;
  city: string;
  website_url: string;
  telegram_url: string;
  vk_url: string;
  instagram_url: string;
  can_access_admin: boolean;
  can_access_support: boolean;
  stats: UserStats;
}

export interface PostAuthor {
  id: number;
  name: string;
  username: string;
  avatar_url: string;
  role: UserRole;
  status_text: string;
}

export interface PostImage {
  id: number;
  image_url: string;
  position: number;
}

export interface PostComment {
  id: number;
  body: string;
  author: PostAuthor;
  created_at: string;
  updated_at: string;
  is_owner: boolean;
  can_edit: boolean;
}

export interface PostListItem {
  id: number;
  slug: string;
  title: string;
  body: string;
  preview_text: string;
  kind: "news" | "event" | "story";
  created_at: string;
  updated_at: string;
  published_at: string;
  is_published: boolean;
  author: PostAuthor;
  preview_image_url: string | null;
  likes_count: number;
  comments_count: number;
  favorites_count: number;
  view_count: number;
  is_liked: boolean;
  is_favorited: boolean;
  has_images: boolean;
  is_owner: boolean;
  can_edit: boolean;
  event_date: string | null;
  event_starts_at: string | null;
  event_ends_at: string | null;
  event_location: string;
  is_event_cancelled: boolean;
  event_cancelled_at: string | null;
}

export interface PostDetail extends Omit<PostListItem, "preview_text" | "preview_image_url"> {
  images: PostImage[];
  comments: PostComment[];
  is_published: boolean;
}

export interface NotificationItem {
  id: number;
  kind: string;
  title: string;
  body: string;
  is_read: boolean;
  created_at: string;
  actor: {
    id: number;
    name: string;
    avatar_url: string;
    role: UserRole;
  };
  post_id: number | null;
  post_slug: string | null;
  post_author_username: string | null;
  comment_id: number | null;
  support_thread_id: number | null;
  report_id: number | null;
}

export interface NotificationResponse {
  unread_count: number;
  results: NotificationItem[];
}

export interface MapPointCategory {
  id: number;
  slug: string;
  title: string;
  sort_order: number;
  color: string;
}

export interface MapPointSummary {
  id: number;
  slug: string;
  title: string;
  short_description: string;
  latitude: number;
  longitude: number;
  marker_color: string;
  categories: MapPointCategory[];
  primary_category: MapPointCategory | null;
  cover_image_url: string;
}

export interface MapPointImage {
  id: number;
  image_url: string;
  caption: string;
  position: number;
}

export interface UserMapMarkerMedia {
  id: number;
  media_url: string;
  media_type: "image" | "video";
  caption: string;
  position: number;
}

export interface MapPointReview {
  id: number;
  author_name: string;
  rating: number;
  body: string;
  created_at: string;
  images: MapPointImage[];
  is_owner: boolean;
  can_edit: boolean;
}

export interface MapPointDetail extends MapPointSummary {
  description: string;
  address: string;
  working_hours: string;
  images: MapPointImage[];
  reviews: MapPointReview[];
}

export interface UserMapMarkerComment {
  id: number;
  author_name: string;
  author: UserSummary | null;
  body: string;
  created_at: string;
  updated_at: string;
  is_owner: boolean;
  can_edit: boolean;
}

export interface UserMapMarkerSummary {
  id: number;
  title: string;
  description: string;
  latitude: number;
  longitude: number;
  author: UserSummary | null;
  is_public: boolean;
  is_active: boolean;
  cover_media_url: string;
  cover_media_type: "image" | "video" | "";
  comments_count: number;
  is_owner: boolean;
  created_at: string;
  updated_at: string;
}

export interface UserMapMarkerDetail extends UserMapMarkerSummary {
  media: UserMapMarkerMedia[];
  comments: UserMapMarkerComment[];
}

export interface MapOverviewResponse {
  bounds: {
    south: number;
    west: number;
    north: number;
    east: number;
  };
  categories: MapPointCategory[];
  points: MapPointSummary[];
  user_markers: UserMapMarkerSummary[];
}

export interface PaginatedResponse<T> {
  count: number;
  next: string | null;
  previous: string | null;
  results: T[];
}

export interface AdminOverview {
  posts_count: number;
  published_posts_count: number;
  draft_posts_count: number;
  map_points_count: number;
  active_map_points_count: number;
  hidden_map_points_count: number;
  user_markers_count: number;
  active_user_markers_count: number;
  hidden_user_markers_count: number;
  users_count: number;
  banned_users_count: number;
  admins_count: number;
}

export interface AdminUser extends UserSummary {
  email: string;
  phone: string | null;
  city: string;
  is_active: boolean;
  is_superuser: boolean;
  date_joined: string;
  last_login: string | null;
  can_access_admin: boolean;
  can_access_support: boolean;
}

export interface SupportKnowledgeEntry {
  id: string;
  category: string;
  title: string;
  answer: string;
  keywords: string[];
  is_featured: boolean;
}

export interface SupportKnowledgeResponse {
  featured: SupportKnowledgeEntry[];
  faq: SupportKnowledgeEntry[];
  suggested_prompts: string[];
}

export interface HelpCenterOverview {
  title: string;
  description: string;
  lead: string;
}

export interface HelpCenterServiceBlock {
  title: string;
  body: string;
}

export interface HelpDocumentApproval {
  status: string;
  revision: string;
  effective_date: string;
  approved_by: string;
  approved_role: string;
  approval_basis: string;
  contact: string;
  note: string;
}

export interface HelpDocumentSection {
  id: string;
  title: string;
  paragraphs: string[];
  bullets?: string[];
}

export interface HelpDocumentGroup {
  id: string;
  title: string;
  document_ids: string[];
}

export interface HelpDocumentQuickFact {
  label: string;
  value: string;
}

export interface HelpDocumentTocItem {
  id: string;
  title: string;
}

export interface HelpOperatorDetails {
  name: string;
  inn: string;
  ogrn: string;
  address: string;
  email: string;
}

export interface HelpDocumentWithdrawal {
  title: string;
  items: string[];
}

export interface HelpDocument {
  id: string;
  slug: string;
  group: string;
  label: string;
  title: string;
  summary: string;
  description: string;
  updated_at: string;
  status: string;
  revision: string;
  operator: string;
  pdf_file_name: string;
  pdf_download_url: string;
  approval: HelpDocumentApproval;
  quick_facts?: HelpDocumentQuickFact[];
  table_of_contents?: HelpDocumentTocItem[];
  sections: HelpDocumentSection[];
  operator_details?: HelpOperatorDetails;
  withdrawal?: HelpDocumentWithdrawal | null;
  archive_url?: string;
}

export interface HelpCenterResponse {
  overview: HelpCenterOverview;
  document_groups: HelpDocumentGroup[];
  service_blocks: HelpCenterServiceBlock[];
  documents: HelpDocument[];
  contact_block: {
    title: string;
    email: string;
    operator?: string;
    inn?: string;
    ogrn?: string;
    address?: string;
  };
}

export interface SocialProvider {
  id: "vk" | "google" | "yandex";
  label: string;
  enabled: boolean;
  authorization_url: string;
}

export interface SocialProvidersResponse {
  providers: SocialProvider[];
}

export interface SupportParticipant {
  id: number;
  name: string;
  username: string;
  avatar_url: string;
  role: UserRole;
}

export interface SupportMessage {
  id: number;
  sender_type: "user" | "support" | "bot" | "system";
  sender_name: string;
  body: string;
  created_at: string;
  author: SupportParticipant | null;
}

export interface SupportReportBadge {
  id: number;
  target_type: "post" | "comment" | "map_review" | "user_marker" | "user_marker_comment";
  reason: string;
  status: "new" | "in_review" | "resolved" | "rejected";
  created_at: string;
}

export interface SupportThreadSummary {
  id: number;
  subject: string;
  category: "general" | "account" | "content" | "map" | "report";
  status: "open" | "waiting_support" | "waiting_user" | "closed";
  created_at: string;
  updated_at: string;
  last_message_at: string;
  last_message_preview: string;
  unread_count: number;
  created_by: SupportParticipant;
  assigned_to: SupportParticipant | null;
  report: SupportReportBadge | null;
}

export interface SupportThreadDetail extends SupportThreadSummary {
  messages: SupportMessage[];
}

export interface SupportBotReplyResponse {
  reply: string;
  matched_article: SupportKnowledgeEntry | null;
  suggestions: SupportKnowledgeEntry[];
}

export interface SupportReport {
  id: number;
  target_type: "post" | "comment" | "map_review" | "user_marker" | "user_marker_comment";
  target_id: number | null;
  target_label: string;
  reason: string;
  details: string;
  status: "new" | "in_review" | "resolved" | "rejected";
  resolution_note: string;
  created_at: string;
  updated_at: string;
  reporter: SupportParticipant;
  reviewed_by: SupportParticipant | null;
  thread_id: number | null;
  post_id: number | null;
  comment_id: number | null;
  review_id: number | null;
  user_marker_id: number | null;
  user_marker_comment_id: number | null;
}

export interface AdminMapPoint {
  id: number;
  slug: string;
  title: string;
  short_description: string;
  description: string;
  address: string;
  working_hours: string;
  latitude: number;
  longitude: number;
  marker_color: string;
  categories: MapPointCategory[];
  primary_category: MapPointCategory | null;
  images: MapPointImage[];
  is_active: boolean;
  sort_order: number;
  review_count: number;
  created_at: string;
  updated_at: string;
}

export interface AdminUserMapMarker {
  id: number;
  title: string;
  description: string;
  latitude: number;
  longitude: number;
  author: UserSummary | null;
  media: UserMapMarkerMedia[];
  is_public: boolean;
  is_active: boolean;
  moderation_note: string;
  comments_count: number;
  reports_count: number;
  created_at: string;
  updated_at: string;
}

export interface AuthSession {
  access: string;
  refresh: string;
  user: CurrentUser;
}

export interface FeedFilters {
  search?: string;
  ordering?: "recommended" | "recent" | "popular";
  kind?: "news" | "event" | "story";
  author_id?: number;
  favorites_only?: boolean;
  has_images?: boolean;
  event_scope?: "all" | "today" | "week" | "upcoming";
  page?: number;
}

export interface ProfileUpdatePayload {
  username?: string;
  email?: string;
  display_name?: string;
  avatar_url?: string;
  status_text?: string;
  bio?: string;
  city?: string;
  telegram_url?: string;
  vk_url?: string;
  instagram_url?: string;
}

export interface PostWritePayload {
  title?: string;
  body?: string;
  kind?: "news" | "event" | "story";
  is_published?: boolean;
  image_urls?: string[];
  event_date?: string | null;
  event_starts_at?: string | null;
  event_ends_at?: string | null;
  event_location?: string;
}

export interface CalendarEventEntry {
  id: number;
  slug: string;
  title: string;
  body: string;
  kind: "news" | "event" | "story";
  created_at: string;
  updated_at: string;
  author: PostAuthor;
  event_date: string | null;
  event_starts_at: string | null;
  event_ends_at: string | null;
  event_location: string;
  is_event_cancelled: boolean;
  event_cancelled_at: string | null;
  can_edit: boolean;
}

export interface EventCalendarResponse {
  year: number;
  month: number;
  starts_on: string;
  ends_on: string;
  events: CalendarEventEntry[];
}

export interface AdminMapCategoryWritePayload {
  slug: string;
  title: string;
  sort_order: number;
  color: string;
}

export interface AdminMapPointWritePayload {
  slug: string;
  title: string;
  short_description: string;
  description: string;
  address: string;
  working_hours: string;
  latitude: number;
  longitude: number;
  marker_color: string;
  is_active: boolean;
  sort_order: number;
  category_ids: number[];
  image_urls: string[];
}

export interface UserMapMarkerWritePayload {
  title: string;
  description: string;
  latitude: number;
  longitude: number;
  is_public: boolean;
  media?: Array<{
    media_url: string;
    media_type: "image" | "video";
    caption?: string;
  }>;
}
