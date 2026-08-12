import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/network/api_client.dart";
import "../../../auth/domain/models/app_user.dart";
import "../../../feed/domain/models/feed_post.dart";
import "../../../map/domain/models/eco_map_category.dart";
import "../../domain/models/admin_map_point.dart";
import "../../domain/models/admin_map_point_input.dart";
import "../../domain/models/admin_overview.dart";

final adminRemoteDataSourceProvider = Provider<AdminRemoteDataSource>((ref) {
  return AdminRemoteDataSource(ref.watch(apiClientProvider));
});

class AdminRemoteDataSource {
  AdminRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AdminOverview> fetchOverview() async {
    final response = await _dio.get("/admin/overview");
    return AdminOverview.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<FeedPost>> fetchPosts({
    String search = "",
    String kind = "all",
    String publicationStatus = "all",
  }) async {
    final response = await _dio.get(
      "/admin/posts",
      queryParameters: {
        "page_size": 100,
        if (search.trim().isNotEmpty) "search": search.trim(),
        if (kind != "all") "kind": kind,
        if (publicationStatus == "published") "is_published": true,
        if (publicationStatus == "draft") "is_published": false,
      },
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    return (data["results"] as List<dynamic>? ?? const [])
        .map((item) => FeedPost.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> togglePostPublished({
    required int postId,
    required bool isPublished,
  }) {
    return _dio.patch("/posts/$postId", data: {"is_published": isPublished});
  }

  Future<void> deletePost(int postId) {
    return _dio.delete("/posts/$postId");
  }

  Future<List<AppUser>> fetchUsers({
    String search = "",
    String role = "all",
    String status = "all",
  }) async {
    final response = await _dio.get(
      "/admin/users",
      queryParameters: {
        "page_size": 100,
        if (search.trim().isNotEmpty) "search": search.trim(),
        if (role != "all") "role": role,
        if (status != "all") "status": status,
      },
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    return (data["results"] as List<dynamic>? ?? const [])
        .map((item) => AppUser.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<EcoMapCategory>> fetchMapCategories() async {
    final response = await _dio.get("/admin/map/categories");
    return (response.data as List<dynamic>? ?? const [])
        .map(
          (item) =>
              EcoMapCategory.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<List<AdminMapPoint>> fetchMapPoints({
    String search = "",
    bool? isActive,
  }) async {
    final queryParameters = <String, dynamic>{"page_size": 100};
    if (search.trim().isNotEmpty) {
      queryParameters["search"] = search.trim();
    }
    if (isActive != null) {
      queryParameters["is_active"] = isActive;
    }

    final response = await _dio.get(
      "/admin/map/points",
      queryParameters: queryParameters,
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    return (data["results"] as List<dynamic>? ?? const [])
        .map(
          (item) => AdminMapPoint.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<AdminMapPoint> createMapPoint(AdminMapPointInput input) async {
    final response = await _dio.post("/admin/map/points", data: input.toJson());
    return AdminMapPoint.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<AdminMapPoint> updateMapPoint({
    required int pointId,
    required AdminMapPointInput input,
  }) async {
    final response = await _dio.patch(
      "/admin/map/points/$pointId",
      data: input.toJson(),
    );
    return AdminMapPoint.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> deleteMapPoint(int pointId) {
    return _dio.delete("/admin/map/points/$pointId");
  }
}
