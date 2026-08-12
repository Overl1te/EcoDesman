class ProfileRouteTarget {
  const ProfileRouteTarget._({this.userId, this.username});

  factory ProfileRouteTarget.byId(int userId) {
    return ProfileRouteTarget._(userId: userId);
  }

  factory ProfileRouteTarget.byUsername(String username) {
    return ProfileRouteTarget._(username: username.trim());
  }

  final int? userId;
  final String? username;

  bool get hasUserId => userId != null;

  bool get hasUsername => normalizedUsername.isNotEmpty;

  String get normalizedUsername => (username ?? "").trim();

  String get cacheKey => hasUsername
      ? "username:${normalizedUsername.toLowerCase()}"
      : "id:$userId";

  @override
  bool operator ==(Object other) {
    return other is ProfileRouteTarget && other.cacheKey == cacheKey;
  }

  @override
  int get hashCode => cacheKey.hashCode;
}

class PostRouteTarget {
  const PostRouteTarget._({
    this.postId,
    this.authorUsername,
    this.postSlug,
  });

  factory PostRouteTarget.byId(int postId) {
    return PostRouteTarget._(postId: postId);
  }

  factory PostRouteTarget.bySlug({
    required String authorUsername,
    required String postSlug,
  }) {
    return PostRouteTarget._(
      authorUsername: authorUsername.trim(),
      postSlug: postSlug.trim(),
    );
  }

  final int? postId;
  final String? authorUsername;
  final String? postSlug;

  bool get hasPostId => postId != null;

  bool get hasCanonicalLookup =>
      normalizedAuthorUsername.isNotEmpty && normalizedPostSlug.isNotEmpty;

  String get normalizedAuthorUsername => (authorUsername ?? "").trim();

  String get normalizedPostSlug => (postSlug ?? "").trim();

  String get cacheKey => hasCanonicalLookup
      ? "slug:${normalizedAuthorUsername.toLowerCase()}/${normalizedPostSlug.toLowerCase()}"
      : "id:$postId";

  @override
  bool operator ==(Object other) {
    return other is PostRouteTarget && other.cacheKey == cacheKey;
  }

  @override
  int get hashCode => cacheKey.hashCode;
}

class AppRoutes {
  static String postDetail({
    int? postId,
    String? authorUsername,
    String? postSlug,
  }) {
    final target = postTarget(
      postId: postId,
      authorUsername: authorUsername,
      postSlug: postSlug,
    );
    if (target.hasCanonicalLookup) {
      return "/${target.normalizedAuthorUsername}/posts/${target.normalizedPostSlug}";
    }
    if (postId == null) {
      throw ArgumentError("postId is required when canonical post lookup is absent");
    }
    return "/posts/$postId";
  }

  static String postEditor(int postId) => "/posts/$postId/edit";

  static String profile({int? userId, String? username}) {
    final target = profileTarget(userId: userId, username: username);
    if (target.hasUsername) {
      return "/${target.normalizedUsername}";
    }
    if (userId == null) {
      throw ArgumentError("userId is required when username is absent");
    }
    return "/profiles/$userId";
  }

  static ProfileRouteTarget profileTarget({
    int? userId,
    String? username,
  }) {
    final normalizedUsername = (username ?? "").trim();
    if (normalizedUsername.isNotEmpty) {
      return ProfileRouteTarget.byUsername(normalizedUsername);
    }
    if (userId == null) {
      throw ArgumentError("userId is required when username is absent");
    }
    return ProfileRouteTarget.byId(userId);
  }

  static List<ProfileRouteTarget> profileLookups({
    int? userId,
    String? username,
  }) {
    final lookups = <ProfileRouteTarget>[];
    if (userId != null) {
      lookups.add(ProfileRouteTarget.byId(userId));
    }
    final normalizedUsername = (username ?? "").trim();
    if (normalizedUsername.isNotEmpty) {
      lookups.add(ProfileRouteTarget.byUsername(normalizedUsername));
    }
    if (lookups.isEmpty) {
      throw ArgumentError("Either userId or username must be provided");
    }
    return lookups;
  }

  static PostRouteTarget postTarget({
    int? postId,
    String? authorUsername,
    String? postSlug,
  }) {
    final normalizedUsername = (authorUsername ?? "").trim();
    final normalizedSlug = (postSlug ?? "").trim();
    if (normalizedUsername.isNotEmpty && normalizedSlug.isNotEmpty) {
      return PostRouteTarget.bySlug(
        authorUsername: normalizedUsername,
        postSlug: normalizedSlug,
      );
    }
    if (postId == null) {
      throw ArgumentError(
        "postId is required when canonical post lookup is absent",
      );
    }
    return PostRouteTarget.byId(postId);
  }

  static List<PostRouteTarget> postLookups({
    int? postId,
    String? authorUsername,
    String? postSlug,
  }) {
    final lookups = <PostRouteTarget>[];
    if (postId != null) {
      lookups.add(PostRouteTarget.byId(postId));
    }
    final normalizedUsername = (authorUsername ?? "").trim();
    final normalizedSlug = (postSlug ?? "").trim();
    if (normalizedUsername.isNotEmpty && normalizedSlug.isNotEmpty) {
      lookups.add(
        PostRouteTarget.bySlug(
          authorUsername: normalizedUsername,
          postSlug: normalizedSlug,
        ),
      );
    }
    if (lookups.isEmpty) {
      throw ArgumentError(
        "Either postId or authorUsername with postSlug must be provided",
      );
    }
    return lookups;
  }
}
