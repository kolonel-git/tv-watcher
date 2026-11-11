import 'package:flutter/painting.dart';

/// Memory limits for decoded images (posters, stills, backdrops).
///
/// Flutter's defaults (100 MB, 1000 images) are too small for a big poster
/// grid (a 400 px poster decodes to about 1 MB, so ~100 fit and scrolling
/// re-decodes) and have no relation to how much memory a media app should
/// hold. These are explicit and small enough for a modest PC.
class ImageBudget {
  const ImageBudget._();

  static const maxBytes = 200 * 1024 * 1024;
  static const maxImages = 400;

  /// Applies the limits to [cache] (the app's cache by default).
  static void apply([ImageCache? cache]) {
    final c = cache ?? PaintingBinding.instance.imageCache;
    c.maximumSizeBytes = maxBytes;
    c.maximumSize = maxImages;
  }
}
