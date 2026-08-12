import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../domain/models/eco_map_point_detail.dart";
import "../../domain/models/map_overview.dart";
import "../../domain/models/user_map_marker_detail.dart";
import "../../domain/models/user_map_marker_input.dart";
import "../../domain/repositories/map_repository.dart";
import "../datasources/map_remote_data_source.dart";

final mapRepositoryProvider = Provider<MapRepository>((ref) {
  return MapRepositoryImpl(
    remoteDataSource: ref.watch(mapRemoteDataSourceProvider),
  );
});

class MapRepositoryImpl implements MapRepository {
  MapRepositoryImpl({required MapRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final MapRemoteDataSource _remoteDataSource;

  @override
  Future<MapOverview> fetchOverview() {
    return _remoteDataSource.fetchOverview();
  }

  @override
  Future<EcoMapPointDetail> fetchPointDetail(int pointId) {
    return _remoteDataSource.fetchPointDetail(pointId);
  }

  @override
  Future<void> createReview({
    required int pointId,
    required int rating,
    required String body,
  }) {
    return _remoteDataSource.createReview(
      pointId: pointId,
      rating: rating,
      body: body,
    );
  }

  @override
  Future<UserMapMarkerDetail> fetchUserMarkerDetail(int markerId) {
    return _remoteDataSource.fetchUserMarkerDetail(markerId);
  }

  @override
  Future<UserMapMarkerDetail> createUserMarker(UserMapMarkerInput input) {
    return _remoteDataSource.createUserMarker(input);
  }

  @override
  Future<void> createUserMarkerComment({
    required int markerId,
    required String body,
  }) {
    return _remoteDataSource.createUserMarkerComment(
      markerId: markerId,
      body: body,
    );
  }
}
