import 'package:flutter/material.dart';

import 'artwork.dart';

/// Netflix-style poster tile: 2:3 poster, scales up on hover/focus.
class PosterCard extends StatefulWidget {
  const PosterCard({
    super.key,
    required this.title,
    required this.posterFile,
    required this.onTap,
    this.subtitle,
    this.badge,
  });

  final String title;
  final String? posterFile;
  final String? subtitle;

  /// Small label on the poster corner, e.g. "Needs match".
  final String? badge;
  final VoidCallback onTap;

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _active = false;

  void _set(bool v) {
    if (_active != v) setState(() => _active = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => _set(true),
      onExit: (_) => _set(false),
      child: AnimatedScale(
        scale: _active ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: _set,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(fit: StackFit.expand, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ArtworkImage(
                      path: widget.posterFile,
                      cacheWidth: 400,
                      placeholderLabel: widget.title,
                    ),
                  ),
                  if (widget.badge != null)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(widget.badge!,
                            style: theme.textTheme.labelSmall),
                      ),
                    ),
                  if (_active)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white70, width: 2),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 6),
              Text(widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium),
              if (widget.subtitle != null)
                Text(widget.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }
}
