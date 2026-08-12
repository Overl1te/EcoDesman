class MapBounds {
  const MapBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  factory MapBounds.fromJson(Map<String, dynamic> json) {
    return MapBounds(
      south: (json["south"] as num?)?.toDouble() ?? 0,
      west: (json["west"] as num?)?.toDouble() ?? 0,
      north: (json["north"] as num?)?.toDouble() ?? 0,
      east: (json["east"] as num?)?.toDouble() ?? 0,
    );
  }
}
