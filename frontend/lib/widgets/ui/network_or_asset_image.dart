import 'package:flutter/material.dart';

/// A resilient image widget that tries a network URL, then falls back to a
/// bundled asset, then to a gradient placeholder with an icon. Never shows a
/// broken image.
class NetworkOrAssetImage extends StatelessWidget {
  final String? url;
  final String? assetPath;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? width;
  final double? height;
  final String? semanticLabel;

  const NetworkOrAssetImage({
    super.key,
    this.url,
    this.assetPath,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = errorWidget ??
        Container(
          width: width,
          height: height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5D4037), Color(0xFF3E2723)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.agriculture, color: Colors.white54, size: 32),
        );

    if (url != null && url!.isNotEmpty) {
      return Semantics(
        label: semanticLabel,
        child: Image.network(
          url!,
          width: width,
          height: height,
          fit: fit,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return placeholder ??
                Container(
                  width: width,
                  height: height,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF5D4037), Color(0xFF3E2723)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  ),
                );
          },
          errorBuilder: (context, error, stack) {
            if (assetPath != null) {
              return Image.asset(
                assetPath!,
                width: width,
                height: height,
                fit: fit,
                errorBuilder: (_, __, ___) => fallback,
              );
            }
            return fallback;
          },
        ),
      );
    }
    if (assetPath != null) {
      return Semantics(
        label: semanticLabel,
        child: Image.asset(
          assetPath!,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }
    return fallback;
  }
}