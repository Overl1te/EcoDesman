import "eco_map_category.dart";
import "eco_map_point.dart";
import "map_bounds.dart";
import "user_map_marker.dart";

class MapOverview {
  const MapOverview({
    required this.bounds,
    required this.categories,
    required this.points,
    required this.userMarkers,
  });

  final MapBounds bounds;
  final List<EcoMapCategory> categories;
  final List<EcoMapPoint> points;
  final List<UserMapMarker> userMarkers;

  factory MapOverview.fromJson(Map<String, dynamic> json) {
    final rawCategories = (json["categories"] as List<dynamic>? ?? const []);
    final rawPoints = (json["points"] as List<dynamic>? ?? const []);
    final rawUserMarkers = (json["user_markers"] as List<dynamic>? ?? const []);

    return MapOverview(
      bounds: MapBounds.fromJson(
        Map<String, dynamic>.from(json["bounds"] as Map? ?? const {}),
      ),
      categories: rawCategories
          .map(
            (item) =>
                EcoMapCategory.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      points: rawPoints
          .map(
            (item) =>
                EcoMapPoint.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      userMarkers: rawUserMarkers
          .map(
            (item) =>
                UserMapMarker.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}
