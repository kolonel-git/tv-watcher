import 'dart:io';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Returns the cached artwork file if it exists on disk.
File? artworkFile(String? path) {
  if (path == null) return null;
  final f = File(path);
  return f.existsSync() ? f : null;
}

/// Image from the local artwork cache, or a placeholder.
class ArtworkImage extends StatelessWidget {
  const ArtworkImage({
    super.key,
    required this.path,
    this.cacheWidth,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.tv,
    this.placeholderLabel,
  });

  final String? path;
  final int? cacheWidth;
  final BoxFit fit;
  final IconData placeholderIcon;
  final String? placeholderLabel;

  @override
  Widget build(BuildContext context) {
    final f = artworkFile(path);
    if (f != null) {
      return Image.file(
        f,
        fit: fit,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => _placeholder(context),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) => Container(
    color: Ui.surface,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(8),
    child: placeholderLabel != null
        ? Text(
            placeholderLabel!,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: Ui.dim),
          )
        : Icon(placeholderIcon, color: Colors.white24, size: 32),
  );
}
