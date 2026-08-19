import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Network image that survives the web renderer.
///
/// On web, CanvasKit uploads decoded images into GPU textures; when the WebGL
/// context is lost or a texture is evicted the image repaints as solid black.
/// Rendering through a real <img> element avoids that entirely.
/// On mobile we keep CachedNetworkImage for its disk cache.
class ProductImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;

  const ProductImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) {
      return _box(const Icon(Icons.image_outlined, color: Colors.black26));
    }

    if (kIsWeb) {
      return Image.network(
        u,
        fit: fit,
        width: width,
        height: height,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, _, _) =>
            _box(const Icon(Icons.broken_image_outlined, color: Colors.black26)),
      );
    }

    return CachedNetworkImage(
      imageUrl: u,
      fit: fit,
      width: width,
      height: height,
      placeholder: (_, _) => _box(null),
      errorWidget: (_, _, _) =>
          _box(const Icon(Icons.broken_image_outlined, color: Colors.black26)),
    );
  }

  Widget _box(Widget? child) => Container(
        width: width,
        height: height,
        color: const Color(0xFFEDEFF3),
        child: child == null ? null : Center(child: child),
      );
}
