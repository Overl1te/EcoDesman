import "package:flutter/material.dart";

import "remote_network_image.dart";

class RemoteAvatar extends StatelessWidget {
  const RemoteAvatar({
    super.key,
    required this.imageUrl,
    required this.fallbackLabel,
    this.radius = 22,
    this.cacheBuster,
  });

  final String imageUrl;
  final String fallbackLabel;
  final double radius;
  final String? cacheBuster;

  String get _resolvedImageUrl {
    final resolved = RemoteNetworkImage.resolve(imageUrl);
    if (resolved.isEmpty || cacheBuster == null || cacheBuster!.isEmpty) {
      return resolved;
    }

    final separator = resolved.contains("?") ? "&" : "?";
    return "$resolved${separator}_cb=$cacheBuster";
  }

  @override
  Widget build(BuildContext context) {
    final trimmedLabel = fallbackLabel.trim();
    final initial = trimmedLabel.isEmpty
        ? "Э"
        : trimmedLabel.substring(0, 1).toUpperCase();
    final resolvedImageUrl = _resolvedImageUrl;

    return CircleAvatar(
      key: ValueKey(resolvedImageUrl),
      radius: radius,
      backgroundImage: resolvedImageUrl.isNotEmpty
          ? NetworkImage(resolvedImageUrl)
          : null,
      child: resolvedImageUrl.isEmpty ? Text(initial) : null,
    );
  }
}
