import "dart:async";

import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:maplibre/maplibre.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../../core/network/error_message.dart";
import "../../../../core/network/image_upload_service.dart";
import "../../../../shared/widgets/app_empty_state.dart";
import "../../../../shared/widgets/app_error_state.dart";
import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../domain/models/eco_map_category.dart";
import "../../domain/models/eco_map_point.dart";
import "../../domain/models/map_bounds.dart";
import "../../domain/models/user_map_marker.dart";
import "../../domain/models/user_map_marker_input.dart";
import "../../data/repositories/map_repository_impl.dart";
import "../controllers/map_controller.dart" as map_feature;
import "../map_point_style.dart";
import "../widgets/map_point_details_sheet.dart";
import "../widgets/user_map_marker_details_sheet.dart";

class MapPlaceholderScreen extends ConsumerStatefulWidget {
  const MapPlaceholderScreen({super.key});

  @override
  ConsumerState<MapPlaceholderScreen> createState() =>
      _MapPlaceholderScreenState();
}

class _MapPlaceholderScreenState extends ConsumerState<MapPlaceholderScreen> {
  static const Geographic _nizhnyNovgorodCenter = Geographic(
    lon: 43.974881,
    lat: 56.315048,
  );
  static const String _osmRasterStyle = '''
{
  "version": 8,
  "name": "EcoDesman OSM raster",
  "sources": {
    "osm": {
      "type": "raster",
      "tiles": [
        "https://a.tile.openstreetmap.org/{z}/{x}/{y}.png",
        "https://b.tile.openstreetmap.org/{z}/{x}/{y}.png",
        "https://c.tile.openstreetmap.org/{z}/{x}/{y}.png"
      ],
      "tileSize": 256,
      "attribution": "(c) OpenStreetMap contributors"
    }
  },
  "layers": [
    {
      "id": "osm",
      "type": "raster",
      "source": "osm"
    }
  ]
}
''';
  static const double _initialZoom = 11.8;
  static const double _twoDimensionalPitch = 0;
  static const double _threeDimensionalPitch = 52;
  static const double _threeDimensionalBearing = -16;
  static const double _tapRadius = 34;
  static const Color _userMarkerColor = Color(0xFF2563EB);
  static const Color _userMarkerStrokeColor = Color(0xFFDCEBFF);
  static const Color _userMarkerHaloColor = Color(0x332563EB);
  static const Color _userMarkerSelectedColor = Color(0xFF1D4ED8);
  static const Color _draftMarkerColor = Color(0xFF0EA5E9);
  static const String _showUserMarkersPreferenceKey = "map_show_user_markers";

  MapController? _mapController;
  int? _selectedPointId;
  int? _selectedUserMarkerId;
  Geographic? _draftUserMarkerPoint;
  String _selectedCategorySlug = "all";
  bool _isThreeDimensional = false;
  bool _filtersExpanded = true;
  bool _showUserMarkers = true;
  bool _isAddingUserMarker = false;

  @override
  void initState() {
    super.initState();
    _restoreUserMarkersVisibility();
  }

  Future<void> _restoreUserMarkersVisibility() async {
    final preferences = await SharedPreferences.getInstance();
    final savedValue = preferences.getBool(_showUserMarkersPreferenceKey);
    if (!mounted || savedValue == null) {
      return;
    }

    setState(() {
      _showUserMarkers = savedValue;
    });
  }

  Future<void> _saveUserMarkersVisibility(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_showUserMarkersPreferenceKey, value);
  }

  LngLatBounds _toLngLatBounds(MapBounds bounds) {
    return LngLatBounds(
      longitudeWest: bounds.west,
      longitudeEast: bounds.east,
      latitudeSouth: bounds.south,
      latitudeNorth: bounds.north,
    );
  }

  Future<void> _focusPoint(EcoMapPoint point) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    setState(() {
      _selectedPointId = point.id;
      _selectedUserMarkerId = null;
      _draftUserMarkerPoint = null;
    });

    await controller.animateCamera(
      center: Geographic(lon: point.longitude, lat: point.latitude),
      zoom: 13.6,
      pitch: _isThreeDimensional
          ? _threeDimensionalPitch
          : _twoDimensionalPitch,
      bearing: _isThreeDimensional ? _threeDimensionalBearing : 0,
      nativeDuration: const Duration(milliseconds: 850),
      webMaxDuration: const Duration(milliseconds: 850),
    );

    if (!mounted) {
      return;
    }

    await showMapPointDetailsSheet(context, pointId: point.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedPointId = null;
    });
  }

  Future<void> _focusUserMarker(UserMapMarker marker) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    setState(() {
      _selectedUserMarkerId = marker.id;
      _selectedPointId = null;
      _draftUserMarkerPoint = null;
    });

    await controller.animateCamera(
      center: Geographic(lon: marker.longitude, lat: marker.latitude),
      zoom: 13.6,
      pitch: _isThreeDimensional
          ? _threeDimensionalPitch
          : _twoDimensionalPitch,
      bearing: _isThreeDimensional ? _threeDimensionalBearing : 0,
      nativeDuration: const Duration(milliseconds: 850),
      webMaxDuration: const Duration(milliseconds: 850),
    );

    if (!mounted) {
      return;
    }

    await showUserMapMarkerDetailsSheet(context, markerId: marker.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedUserMarkerId = null;
    });
  }

  Future<void> _openCreateUserMarkerSheet(Geographic point) async {
    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Войдите, чтобы добавить метку")),
      );
      return;
    }

    setState(() {
      _draftUserMarkerPoint = point;
      _selectedPointId = null;
      _selectedUserMarkerId = null;
    });

    await _mapController?.animateCamera(
      center: point,
      zoom: 14.2,
      pitch: _twoDimensionalPitch,
      bearing: 0,
      nativeDuration: const Duration(milliseconds: 520),
      webMaxDuration: const Duration(milliseconds: 520),
    );

    if (!mounted) {
      return;
    }

    final input = await showModalBottomSheet<UserMapMarkerInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          _CreateUserMarkerSheet(latitude: point.lat, longitude: point.lon),
    );

    if (!mounted || input == null) {
      if (mounted) {
        setState(() {
          _draftUserMarkerPoint = null;
        });
      }
      return;
    }

    try {
      final marker = await ref
          .read(mapRepositoryProvider)
          .createUserMarker(input);
      await ref.read(map_feature.mapControllerProvider.notifier).refresh();
      if (!mounted) {
        return;
      }
      setState(() {
        _isAddingUserMarker = false;
        _showUserMarkers = true;
        _draftUserMarkerPoint = null;
      });
      unawaited(_saveUserMarkersVisibility(true));
      await _focusUserMarker(marker);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _draftUserMarkerPoint = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            humanizeNetworkError(error, fallback: "Не удалось создать метку"),
          ),
        ),
      );
    }
  }

  Future<void> _togglePerspective() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    final nextIsThreeDimensional = !_isThreeDimensional;
    setState(() {
      _isThreeDimensional = nextIsThreeDimensional;
    });

    await controller.animateCamera(
      pitch: nextIsThreeDimensional
          ? _threeDimensionalPitch
          : _twoDimensionalPitch,
      bearing: nextIsThreeDimensional ? _threeDimensionalBearing : 0,
      nativeDuration: const Duration(milliseconds: 700),
      webMaxDuration: const Duration(milliseconds: 700),
    );
  }

  Future<void> _openExternalLink(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  bool _matchesCategory(EcoMapPoint point) {
    if (_selectedCategorySlug == "all") {
      return true;
    }

    return point.categories.any((item) => item.slug == _selectedCategorySlug);
  }

  String _selectedCategoryTitle(List<EcoMapCategory> categories) {
    if (_selectedCategorySlug == "all") {
      return "Все точки";
    }

    for (final category in categories) {
      if (category.slug == _selectedCategorySlug) {
        return category.title;
      }
    }

    return "Фильтры";
  }

  int _countForCategory(String slug, List<EcoMapPoint> points) {
    if (slug == "all") {
      return points.length;
    }

    return points
        .where((point) => point.categories.any((item) => item.slug == slug))
        .length;
  }

  EcoMapPoint? _selectedPoint(List<EcoMapPoint> points) {
    for (final point in points) {
      if (point.id == _selectedPointId) {
        return point;
      }
    }

    return null;
  }

  UserMapMarker? _selectedUserMarker(List<UserMapMarker> markers) {
    for (final marker in markers) {
      if (marker.id == _selectedUserMarkerId) {
        return marker;
      }
    }

    return null;
  }

  List<EcoMapCategory> _sortedCategories(List<EcoMapCategory> categories) {
    final sorted = [...categories];
    sorted.sort((left, right) {
      final priorityDiff =
          getCategoryPriority(right) - getCategoryPriority(left);
      if (priorityDiff != 0) {
        return priorityDiff;
      }
      return left.title.compareTo(right.title);
    });
    return sorted;
  }

  MapPointAppearance _appearanceForPoint(EcoMapPoint point) {
    return getMapPointAppearanceForPoint(
      markerColor: point.markerColor,
      category: getPrimaryMapCategory(
        point.categories,
        primaryCategory: point.primaryCategory,
      ),
    );
  }

  Feature<Point> _toFeature(EcoMapPoint point) {
    return Feature(
      id: point.id.toString(),
      geometry: Point(Geographic(lon: point.longitude, lat: point.latitude)),
      properties: {"title": point.title},
    );
  }

  Feature<Point> _toUserMarkerFeature(UserMapMarker marker) {
    return Feature(
      id: "user-${marker.id}",
      geometry: Point(Geographic(lon: marker.longitude, lat: marker.latitude)),
      properties: {"title": marker.title},
    );
  }

  Feature<Point> _toDraftUserMarkerFeature(Geographic point) {
    return Feature(
      id: "user-marker-draft",
      geometry: Point(point),
      properties: const {"title": "Новая метка"},
    );
  }

  List<_PointLayerGroup> _groupPointsByAppearance(List<EcoMapPoint> points) {
    final groupedFeatures = <String, List<Feature<Point>>>{};
    final groupedAppearances = <String, MapPointAppearance>{};

    for (final point in points) {
      final appearance = _appearanceForPoint(point);
      final key =
          "${appearance.color.toARGB32()}:${appearance.strokeColor.toARGB32()}:${appearance.selectedColor.toARGB32()}";
      groupedAppearances[key] = appearance;
      groupedFeatures.putIfAbsent(key, () => []).add(_toFeature(point));
    }

    return [
      for (final entry in groupedFeatures.entries)
        _PointLayerGroup(
          appearance: groupedAppearances[entry.key]!,
          points: entry.value,
        ),
    ];
  }

  Future<void> _handleMapTap(
    MapEvent event,
    List<EcoMapPoint> filteredPoints,
    List<UserMapMarker> filteredUserMarkers,
  ) async {
    if (event is! MapEventClick && event is! MapEventLongClick) {
      return;
    }
    final userInput = event as MapEventUserInput;

    final controller = _mapController;
    if (controller == null) {
      return;
    }

    if (_isAddingUserMarker) {
      await _openCreateUserMarkerSheet(userInput.point);
      return;
    }

    EcoMapPoint? tappedPoint;
    UserMapMarker? tappedUserMarker;
    var bestDistance = double.infinity;

    for (final point in filteredPoints) {
      final screenLocation = controller.toScreenLocation(
        Geographic(lon: point.longitude, lat: point.latitude),
      );
      final distance = (userInput.screenPoint - screenLocation).distance;
      if (distance <= _tapRadius && distance < bestDistance) {
        tappedPoint = point;
        bestDistance = distance;
      }
    }

    for (final marker in filteredUserMarkers) {
      final screenLocation = controller.toScreenLocation(
        Geographic(lon: marker.longitude, lat: marker.latitude),
      );
      final distance = (userInput.screenPoint - screenLocation).distance;
      if (distance <= _tapRadius && distance < bestDistance) {
        tappedPoint = null;
        tappedUserMarker = marker;
        bestDistance = distance;
      }
    }

    if (tappedPoint == null && tappedUserMarker == null) {
      if (_selectedPointId != null ||
          _selectedUserMarkerId != null ||
          _draftUserMarkerPoint != null) {
        setState(() {
          _selectedPointId = null;
          _selectedUserMarkerId = null;
          _draftUserMarkerPoint = null;
        });
      }
      return;
    }

    if (tappedUserMarker != null) {
      await _focusUserMarker(tappedUserMarker);
      return;
    }

    await _focusPoint(tappedPoint!);
  }

  IconData _categoryIcon(String slug) {
    switch (slug) {
      case "marketplace":
        return Icons.storefront_outlined;
      case "batteries":
        return Icons.battery_charging_full_outlined;
      case "paper":
        return Icons.description_outlined;
      case "eco-center":
        return Icons.eco_outlined;
      case "park":
        return Icons.park_outlined;
      case "metal":
      case "scrap":
        return Icons.precision_manufacturing_outlined;
      case "plastic":
        return Icons.recycling_outlined;
      case "glass":
        return Icons.wine_bar_outlined;
      case "electronics":
        return Icons.memory_outlined;
      case "clothes":
        return Icons.checkroom_outlined;
      case "viewpoint":
        return Icons.visibility_outlined;
      case "museum":
        return Icons.museum_outlined;
      case "nature":
        return Icons.forest_outlined;
      case "embankment":
        return Icons.water_outlined;
      case "sports":
        return Icons.directions_run_outlined;
      default:
        return Icons.place_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(map_feature.mapControllerProvider);

    return overviewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) {
        return AppErrorState(
          title: "Не удалось загрузить карту",
          message: ref
              .read(map_feature.mapControllerProvider.notifier)
              .toErrorMessage(error),
          onRetry: () =>
              ref.read(map_feature.mapControllerProvider.notifier).refresh(),
        );
      },
      data: (overview) {
        final sortedCategories = _sortedCategories(overview.categories);
        final filteredPoints = overview.points
            .where(_matchesCategory)
            .toList(growable: false);
        final filteredUserMarkers = _showUserMarkers
            ? overview.userMarkers
            : const <UserMapMarker>[];

        if (overview.points.isEmpty && overview.userMarkers.isEmpty) {
          return const AppEmptyState(
            title: "Точек пока нет",
            message: "Когда на сервере появятся точки, они отобразятся здесь.",
          );
        }

        final theme = Theme.of(context);
        final selectedCategoryTitle = _selectedCategoryTitle(sortedCategories);
        final selectedPoint = _selectedPoint(filteredPoints);
        final selectedUserMarker = _selectedUserMarker(filteredUserMarkers);
        final pointLayers = _groupPointsByAppearance([
          for (final point in filteredPoints)
            if (point.id != selectedPoint?.id) point,
        ]);
        final userMarkerFeatures = <Feature<Point>>[
          for (final marker in filteredUserMarkers)
            if (marker.id != selectedUserMarker?.id)
              _toUserMarkerFeature(marker),
        ];
        final selectedAppearance = selectedPoint == null
            ? null
            : _appearanceForPoint(selectedPoint);
        final selectedPointFeatures = selectedPoint == null
            ? const <Feature<Point>>[]
            : <Feature<Point>>[_toFeature(selectedPoint)];
        final selectedUserMarkerFeatures = selectedUserMarker == null
            ? const <Feature<Point>>[]
            : <Feature<Point>>[_toUserMarkerFeature(selectedUserMarker)];
        final draftUserMarkerFeatures = _draftUserMarkerPoint == null
            ? const <Feature<Point>>[]
            : <Feature<Point>>[
                _toDraftUserMarkerFeature(_draftUserMarkerPoint!),
              ];

        return Stack(
          children: [
            MapLibreMap(
              key: const ValueKey("mobile-map-osm-raster"),
              options: MapOptions(
                initStyle: _osmRasterStyle,
                initCenter: _nizhnyNovgorodCenter,
                initZoom: _initialZoom,
                initPitch: _isThreeDimensional
                    ? _threeDimensionalPitch
                    : _twoDimensionalPitch,
                initBearing: _isThreeDimensional ? _threeDimensionalBearing : 0,
                minZoom: 10.5,
                maxZoom: 18,
                minPitch: 0,
                maxPitch: 60,
                maxBounds: _toLngLatBounds(overview.bounds),
                androidTextureMode: true,
                androidMode: AndroidPlatformViewMode.tlhc_hc,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              onEvent: (event) =>
                  _handleMapTap(event, filteredPoints, filteredUserMarkers),
              layers: [
                for (final layer in pointLayers)
                  CircleLayer(
                    points: layer.points,
                    radius: 9,
                    color: layer.appearance.color,
                    strokeWidth: 4,
                    strokeColor: layer.appearance.strokeColor,
                  ),
                if (userMarkerFeatures.isNotEmpty)
                  CircleLayer(
                    points: userMarkerFeatures,
                    radius: 8,
                    color: _userMarkerColor,
                    strokeWidth: 3,
                    strokeColor: _userMarkerStrokeColor,
                  ),
                if (selectedUserMarkerFeatures.isNotEmpty)
                  CircleLayer(
                    points: selectedUserMarkerFeatures,
                    radius: 17,
                    color: _userMarkerHaloColor,
                    blur: 0.2,
                    strokeWidth: 2,
                    strokeColor: _userMarkerStrokeColor,
                  ),
                if (selectedUserMarkerFeatures.isNotEmpty)
                  CircleLayer(
                    points: selectedUserMarkerFeatures,
                    radius: 10,
                    color: _userMarkerSelectedColor,
                    strokeWidth: 4,
                    strokeColor: const Color(0xFFFFFFFF),
                  ),
                if (draftUserMarkerFeatures.isNotEmpty)
                  CircleLayer(
                    points: draftUserMarkerFeatures,
                    radius: 22,
                    color: const Color(0x220EA5E9),
                    blur: 0.2,
                    strokeWidth: 2,
                    strokeColor: _userMarkerStrokeColor,
                  ),
                if (draftUserMarkerFeatures.isNotEmpty)
                  CircleLayer(
                    points: draftUserMarkerFeatures,
                    radius: 11,
                    color: _draftMarkerColor,
                    strokeWidth: 4,
                    strokeColor: const Color(0xFFFFFFFF),
                  ),
                if (selectedPointFeatures.isNotEmpty)
                  CircleLayer(
                    points: selectedPointFeatures,
                    radius: 18,
                    color: selectedAppearance!.haloColor,
                    blur: 0.2,
                    strokeWidth: 2,
                    strokeColor: selectedAppearance.strokeColor,
                  ),
                if (selectedPointFeatures.isNotEmpty)
                  CircleLayer(
                    points: selectedPointFeatures,
                    radius: 10,
                    color: selectedAppearance!.selectedColor,
                    strokeWidth: 4,
                    strokeColor: selectedAppearance.selectedStrokeColor,
                  ),
              ],
              children: [
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MapFilterPanel(
                          points: overview.points,
                          categories: sortedCategories,
                          selectedCategoryTitle: selectedCategoryTitle,
                          selectedSlug: _selectedCategorySlug,
                          pointsCount: filteredPoints.length,
                          userMarkersCount: overview.userMarkers.length,
                          isThreeDimensional: _isThreeDimensional,
                          isExpanded: _filtersExpanded,
                          showUserMarkers: _showUserMarkers,
                          isAddingUserMarker: _isAddingUserMarker,
                          categoryIconBuilder: _categoryIcon,
                          categoryColorBuilder: (category) =>
                              getMapPointAppearance(category).color,
                          countForCategory: _countForCategory,
                          onCategorySelected: (slug) {
                            if (slug == _selectedCategorySlug) {
                              return;
                            }

                            setState(() {
                              _selectedCategorySlug = slug;
                              _selectedPointId = null;
                              _selectedUserMarkerId = null;
                              _draftUserMarkerPoint = null;
                            });
                          },
                          onToggleExpanded: () {
                            setState(() {
                              _filtersExpanded = !_filtersExpanded;
                            });
                          },
                          onTogglePerspective: _togglePerspective,
                          onToggleUserMarkers: () {
                            final nextValue = !_showUserMarkers;
                            setState(() {
                              _showUserMarkers = nextValue;
                              _selectedUserMarkerId = null;
                            });
                            unawaited(_saveUserMarkersVisibility(nextValue));
                          },
                          onToggleAddUserMarker: () {
                            final authState = ref.read(authControllerProvider);
                            if (!authState.isAuthenticated) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Войдите, чтобы добавить метку",
                                  ),
                                ),
                              );
                              return;
                            }

                            setState(() {
                              _isAddingUserMarker = !_isAddingUserMarker;
                              _selectedPointId = null;
                              _selectedUserMarkerId = null;
                              _draftUserMarkerPoint = null;
                            });
                          },
                          onReset: _selectedCategorySlug == "all"
                              ? null
                              : () {
                                  setState(() {
                                    _selectedCategorySlug = "all";
                                    _selectedPointId = null;
                                    _selectedUserMarkerId = null;
                                    _draftUserMarkerPoint = null;
                                  });
                                },
                        ),
                        if (filteredPoints.isEmpty) ...[
                          const SizedBox(height: 12),
                          _EmptyFilterCard(
                            onReset: () {
                              setState(() {
                                _selectedCategorySlug = "all";
                                _selectedPointId = null;
                                _selectedUserMarkerId = null;
                                _draftUserMarkerPoint = null;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: SafeArea(
                    top: false,
                    child: _MapAttributionPill(
                      onOpenStreetMapTap: () => _openExternalLink(
                        "https://www.openstreetmap.org/copyright",
                      ),
                      onOpenMapTilesTap: () =>
                          _openExternalLink("https://www.openmaptiles.org/"),
                      onOpenFreeMapTap: () =>
                          _openExternalLink("https://openfreemap.org/"),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 14,
              right: 132,
              bottom: 14,
              child: IgnorePointer(
                ignoring: selectedPoint != null || selectedUserMarker != null,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: selectedPoint == null && selectedUserMarker == null
                      ? 1
                      : 0,
                  child: SafeArea(
                    top: false,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.92,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _isAddingUserMarker
                              ? _draftUserMarkerPoint == null
                                    ? "Нажмите на карту, чтобы поставить метку"
                                    : "Место выбрано, заполните карточку"
                              : "Нажмите на точку, чтобы открыть подробности",
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MapFilterPanel extends StatelessWidget {
  const _MapFilterPanel({
    required this.points,
    required this.categories,
    required this.selectedCategoryTitle,
    required this.selectedSlug,
    required this.pointsCount,
    required this.userMarkersCount,
    required this.isThreeDimensional,
    required this.isExpanded,
    required this.showUserMarkers,
    required this.isAddingUserMarker,
    required this.categoryIconBuilder,
    required this.categoryColorBuilder,
    required this.countForCategory,
    required this.onCategorySelected,
    required this.onToggleExpanded,
    required this.onTogglePerspective,
    required this.onToggleUserMarkers,
    required this.onToggleAddUserMarker,
    required this.onReset,
  });

  final List<EcoMapPoint> points;
  final List<EcoMapCategory> categories;
  final String selectedCategoryTitle;
  final String selectedSlug;
  final int pointsCount;
  final int userMarkersCount;
  final bool isThreeDimensional;
  final bool isExpanded;
  final bool showUserMarkers;
  final bool isAddingUserMarker;
  final IconData Function(String slug) categoryIconBuilder;
  final Color Function(EcoMapCategory? category) categoryColorBuilder;
  final int Function(String slug, List<EcoMapPoint> points) countForCategory;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onToggleExpanded;
  final VoidCallback onTogglePerspective;
  final VoidCallback onToggleUserMarkers;
  final VoidCallback onToggleAddUserMarker;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$selectedCategoryTitle · $pointsCount точек",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Фильтры",
                      style: theme.textTheme.labelMedium?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      IconButton.filledTonal(
                        onPressed: onToggleExpanded,
                        tooltip: isExpanded
                            ? "Скрыть фильтры"
                            : "Показать фильтры",
                        icon: const Icon(Icons.filter_alt_rounded),
                      ),
                      IconButton.filledTonal(
                        onPressed: onTogglePerspective,
                        tooltip: isThreeDimensional
                            ? "Переключить в 2D"
                            : "Переключить в 3D",
                        icon: Icon(
                          isThreeDimensional
                              ? Icons.view_in_ar_rounded
                              : Icons.flip_to_front_outlined,
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: onToggleUserMarkers,
                        tooltip: showUserMarkers
                            ? "Скрыть метки людей"
                            : "Показать метки людей",
                        icon: Icon(
                          showUserMarkers
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: onToggleAddUserMarker,
                        tooltip: isAddingUserMarker
                            ? "Отменить добавление"
                            : "Добавить место",
                        icon: Icon(
                          isAddingUserMarker
                              ? Icons.location_searching_outlined
                              : Icons.add_location_alt_outlined,
                        ),
                      ),
                      if (onReset != null)
                        IconButton.filledTonal(
                          onPressed: onReset,
                          tooltip: "Сбросить фильтр",
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeOutCubic,
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterOptionChip(
                      label: "Все",
                      count: countForCategory("all", points),
                      icon: Icons.apps_rounded,
                      accentColor: const Color(0xFF56616F),
                      selected: selectedSlug == "all",
                      onTap: () => onCategorySelected("all"),
                    ),
                    const SizedBox(width: 10),
                    _FilterOptionChip(
                      label: "Метки людей",
                      count: userMarkersCount,
                      icon: Icons.person_pin_circle_outlined,
                      accentColor: _MapPlaceholderScreenState._userMarkerColor,
                      selected: showUserMarkers,
                      onTap: onToggleUserMarkers,
                    ),
                    for (final category in categories) ...[
                      const SizedBox(width: 10),
                      _FilterOptionChip(
                        label: category.title,
                        count: countForCategory(category.slug, points),
                        icon: categoryIconBuilder(category.slug),
                        accentColor: categoryColorBuilder(category),
                        selected: selectedSlug == category.slug,
                        onTap: () => onCategorySelected(category.slug),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _MapAttributionPill extends StatelessWidget {
  const _MapAttributionPill({
    required this.onOpenStreetMapTap,
    required this.onOpenMapTilesTap,
    required this.onOpenFreeMapTap,
  });

  final VoidCallback onOpenStreetMapTap;
  final VoidCallback onOpenMapTilesTap;
  final VoidCallback onOpenFreeMapTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          _AttributionLink(
            label: "OpenStreetMap",
            style: textStyle,
            onTap: onOpenStreetMapTap,
          ),
          Text("•", style: textStyle),
          _AttributionLink(
            label: "OpenMapTiles",
            style: textStyle,
            onTap: onOpenMapTilesTap,
          ),
          Text("•", style: textStyle),
          _AttributionLink(
            label: "OpenFreeMap",
            style: textStyle,
            onTap: onOpenFreeMapTap,
          ),
        ],
      ),
    );
  }
}

class _AttributionLink extends StatelessWidget {
  const _AttributionLink({
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle? style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Text(label, style: style),
      ),
    );
  }
}

class _FilterOptionChip extends StatelessWidget {
  const _FilterOptionChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.accentColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color accentColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedForeground =
        ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Material(
      color: selected ? accentColor : accentColor.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? selectedForeground : accentColor,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected
                      ? selectedForeground
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? selectedForeground.withValues(alpha: 0.16)
                      : accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "$count",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected ? selectedForeground : accentColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointLayerGroup {
  const _PointLayerGroup({required this.appearance, required this.points});

  final MapPointAppearance appearance;
  final List<Feature<Point>> points;
}

class _EmptyFilterCard extends StatelessWidget {
  const _EmptyFilterCard({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "По текущему фильтру точек нет. Сбросьте фильтр и посмотрите все точки.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: onReset, child: const Text("Сбросить")),
        ],
      ),
    );
  }
}

class _CreateUserMarkerSheet extends ConsumerStatefulWidget {
  const _CreateUserMarkerSheet({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  ConsumerState<_CreateUserMarkerSheet> createState() =>
      _CreateUserMarkerSheetState();
}

class _CreateUserMarkerSheetState
    extends ConsumerState<_CreateUserMarkerSheet> {
  static const List<String> _mediaExtensions = [
    "jpg",
    "jpeg",
    "png",
    "webp",
    "gif",
    "mp4",
    "mov",
    "m4v",
    "webm",
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<UserMapMarkerMediaInput> _media = [];

  bool _isPublic = true;
  bool _isUploadingMedia = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _mediaExtensions,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final paths = result.files
          .map((file) => file.path)
          .whereType<String>()
          .toList(growable: false);
      if (paths.isEmpty) {
        setState(() {
          _errorMessage = "Не удалось получить выбранные файлы";
        });
        return;
      }

      setState(() {
        _isUploadingMedia = true;
        _errorMessage = null;
      });

      final uploader = ref.read(imageUploadServiceProvider);
      final uploaded = <UserMapMarkerMediaInput>[];
      for (final path in paths) {
        final media = await uploader.uploadMedia(path);
        uploaded.add(
          UserMapMarkerMediaInput(
            mediaUrl: media.url,
            mediaType: media.mediaType,
          ),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _media.addAll(uploaded);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = humanizeNetworkError(
          error,
          fallback: "Не удалось загрузить фото или видео",
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingMedia = false;
        });
      }
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _media.removeAt(index);
    });
  }

  void _submit() {
    if (_isUploadingMedia || !_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      UserMapMarkerInput(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        latitude: widget.latitude,
        longitude: widget.longitude,
        isPublic: _isPublic,
        media: List.unmodifiable(_media),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Новое место",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)}",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: "Название"),
              validator: (value) {
                if ((value ?? "").trim().length < 3) {
                  return "Укажите название";
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: "Что здесь интересного",
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if ((value ?? "").trim().length < 10) {
                  return "Добавьте описание";
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _VisibilitySwitchTile(
              value: _isPublic,
              onChanged: (value) {
                setState(() {
                  _isPublic = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Фото и видео",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _isUploadingMedia ? null : _pickAndUploadMedia,
                  icon: const Icon(Icons.attach_file_outlined),
                  label: Text(_isUploadingMedia ? "Загрузка..." : "Добавить"),
                ),
              ],
            ),
            if (_media.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < _media.length; index++)
                    InputChip(
                      avatar: Icon(
                        _media[index].mediaType == "video"
                            ? Icons.play_circle_outline
                            : Icons.image_outlined,
                        size: 18,
                      ),
                      label: Text(
                        _media[index].mediaType == "video"
                            ? "Видео ${index + 1}"
                            : "Фото ${index + 1}",
                      ),
                      onDeleted: () => _removeMedia(index),
                    ),
                ],
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isUploadingMedia ? null : _submit,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text("Добавить место"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilitySwitchTile extends StatelessWidget {
  const _VisibilitySwitchTile({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _MapPlaceholderScreenState._userMarkerColor;

    return Material(
      color: value
          ? accent.withValues(alpha: 0.10)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: value
                  ? accent.withValues(alpha: 0.32)
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: value
                      ? accent.withValues(alpha: 0.14)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  value ? Icons.visibility_outlined : Icons.lock_outline,
                  color: value ? accent : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value ? "Видно всем на карте" : "Только для меня",
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value
                          ? "Другие пользователи смогут открыть метку и оставить комментарий."
                          : "Метка сохранится, но не появится у других пользователей.",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Switch.adaptive(
                value: value,
                activeThumbColor: accent,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
