import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/network/api_client.dart";
import "../../domain/models/eco_map_point_detail.dart";
import "../../domain/models/map_overview.dart";
import "../../domain/models/user_map_marker_detail.dart";
import "../../domain/models/user_map_marker_input.dart";

final mapRemoteDataSourceProvider = Provider<MapRemoteDataSource>((ref) {
  return MapRemoteDataSource(ref.watch(apiClientProvider));
});

class MapRemoteDataSource {
  MapRemoteDataSource(this._dio);

  final Dio _dio;

  Future<MapOverview> fetchOverview() async {
    final response = await _dio.get("/map/overview");
    return MapOverview.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<EcoMapPointDetail> fetchPointDetail(int pointId) async {
    final response = await _dio.get("/map/points/$pointId");
    return EcoMapPointDetail.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> createReview({
    required int pointId,
    required int rating,
    required String body,
  }) async {
    await _dio.post(
      "/map/points/$pointId/reviews",
      data: {"rating": rating, "body": body},
    );
  }

  Future<UserMapMarkerDetail> fetchUserMarkerDetail(int markerId) async {
    final response = await _dio.get("/map/user-markers/$markerId");
    return UserMapMarkerDetail.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<UserMapMarkerDetail> createUserMarker(UserMapMarkerInput input) async {
    final response = await _dio.post("/map/user-markers", data: input.toJson());
    return UserMapMarkerDetail.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> createUserMarkerComment({
    required int markerId,
    required String body,
  }) async {
    await _dio.post(
      "/map/user-markers/$markerId/comments",
      data: {"body": body},
    );
  }
}
