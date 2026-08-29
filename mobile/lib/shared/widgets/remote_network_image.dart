import "package:flutter/material.dart";

import "../../core/config/app_config.dart";

class RemoteNetworkImage extends StatelessWidget {
  const RemoteNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.errorBuilder,
  });

  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final ImageErrorWidgetBuilder? errorBuilder;

  static String resolve(String? url) {
    return AppConfig.fromEnvironment().resolveMediaUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final resolved = resolve(imageUrl);
    if (resolved.isEmpty) {
      return errorBuilder?.call(context, "empty", null) ??
          const SizedBox.shrink();
    }

    return Image.network(
      resolved,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      errorBuilder: errorBuilder,
    );
  }
}
