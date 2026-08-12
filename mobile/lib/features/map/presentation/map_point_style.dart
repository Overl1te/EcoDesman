import "package:flutter/material.dart";

import "../domain/models/eco_map_category.dart";

class MapPointAppearance {
  const MapPointAppearance({
    required this.color,
    required this.haloColor,
    required this.strokeColor,
    required this.selectedColor,
    required this.selectedStrokeColor,
  });

  final Color color;
  final Color haloColor;
  final Color strokeColor;
  final Color selectedColor;
  final Color selectedStrokeColor;
}

const Color _defaultCategoryColor = Color(0xFF56616F);
final RegExp _hexColorPattern = RegExp(r"^#?[0-9A-Fa-f]{6}$");

MapPointAppearance _buildAppearance(Color color) {
  return MapPointAppearance(
    color: color,
    haloColor: color.withValues(alpha: 0.2),
    strokeColor: Color.alphaBlend(Colors.white.withValues(alpha: 0.74), color),
    selectedColor: Color.alphaBlend(
      Colors.white.withValues(alpha: 0.12),
      color,
    ),
    selectedStrokeColor: Color.alphaBlend(
      Colors.white.withValues(alpha: 0.88),
      color,
    ),
  );
}

int getCategoryPriority(EcoMapCategory? category) {
  if (category == null) {
    return -1 << 20;
  }

  return category.sortOrder;
}

EcoMapCategory? getPrimaryMapCategory(
  List<EcoMapCategory> categories, {
  EcoMapCategory? primaryCategory,
}) {
  if (primaryCategory != null) {
    return primaryCategory;
  }

  if (categories.isEmpty) {
    return null;
  }

  final sorted = [...categories]
    ..sort((left, right) {
      final priorityDiff =
          getCategoryPriority(right) - getCategoryPriority(left);
      if (priorityDiff != 0) {
        return priorityDiff;
      }
      return left.title.compareTo(right.title);
    });

  return sorted.first;
}

MapPointAppearance getMapPointAppearance(EcoMapCategory? category) {
  return _buildAppearance(_parseHexColor(category?.color));
}

MapPointAppearance getMapPointAppearanceForPoint({
  required String? markerColor,
  required EcoMapCategory? category,
}) {
  return _buildAppearance(
    resolvePointMarkerColor(markerColor: markerColor, category: category),
  );
}

Color resolvePointMarkerColor({
  required String? markerColor,
  required EcoMapCategory? category,
}) {
  final pointColor = _parseHexColorOrNull(markerColor);
  if (pointColor != null) {
    return pointColor;
  }

  final categoryColor = _parseHexColorOrNull(category?.color);
  if (categoryColor != null) {
    return categoryColor;
  }

  return _defaultCategoryColor;
}

Color _parseHexColor(String? value) {
  return _parseHexColorOrNull(value) ?? _defaultCategoryColor;
}

Color? _parseHexColorOrNull(String? value) {
  final raw = (value ?? "").trim();
  if (!_hexColorPattern.hasMatch(raw)) {
    return null;
  }

  final normalized = (value ?? "").replaceAll("#", "");
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) {
    return null;
  }
  return Color(0xFF000000 | parsed);
}
