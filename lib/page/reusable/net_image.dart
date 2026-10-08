import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Drop-in for [Image.network] that keeps downloaded images on disk and in
/// memory. Recipe thumbnails were re-downloaded on every list rebuild and
/// every app start.
class NetImage extends StatelessWidget {
  const NetImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.errorBuilder,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    // Decode near display size instead of full resolution: a 75px thumbnail
    // does not need a multi-megapixel bitmap in memory.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = (width != null && width!.isFinite) ? (width! * dpr).round() : null;
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheW,
      errorWidget: errorBuilder == null
          ? null
          : (ctx, _, error) => errorBuilder!(ctx, error, null),
    );
  }
}
