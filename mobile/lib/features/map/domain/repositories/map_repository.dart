import "../models/eco_map_point_detail.dart";
import "../models/map_overview.dart";
import "../models/user_map_marker_detail.dart";
import "../models/user_map_marker_input.dart";

abstract class MapRepository {
  Future<MapOverview> fetchOverview();

  Future<EcoMapPointDetail> fetchPointDetail(int pointId);

  Future<void> createReview({
    required int pointId,
    required int rating,
    required String body,
  });

  Future<UserMapMarkerDetail> fetchUserMarkerDetail(int markerId);

  Future<UserMapMarkerDetail> createUserMarker(UserMapMarkerInput input);

  Future<void> createUserMarkerComment({
    required int markerId,
    required String body,
  });
}
