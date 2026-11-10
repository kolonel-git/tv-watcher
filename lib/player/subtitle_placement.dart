import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';

import '../data/database.dart';

/// Where the subtitle text sits and whether it is being dragged.
///
/// Owns the placement rules so they can be unit-tested without a player:
/// the lift above the control bar applies only to the untouched default
/// position, dragging follows the pointer exactly, and the spot is saved.
class SubtitlePlacement extends ChangeNotifier {
  SubtitlePlacement({required this.baseBottom, required this.barClearance})
    : _bottom = baseBottom;

  /// Default distance from the bottom edge.
  final double baseBottom;

  /// Extra lift above the control bar for the default position.
  final double barClearance;

  double _bottom;
  double _dx = 0;
  bool _dragging = false;

  double get bottom => _bottom;
  double get dx => _dx;
  bool get dragging => _dragging;

  /// True once the user has moved the text away from the default spot.
  bool get moved => _bottom != baseBottom || _dx != 0;

  /// Distance from the bottom edge to draw at right now.
  double effectiveBottom({required bool controlsVisible}) {
    final lift = controlsVisible && !_dragging && !moved ? barClearance : 0.0;
    return _bottom < lift ? lift : _bottom;
  }

  /// Restores a saved spot (either value may be unknown).
  void restore({double? bottom, double? dx}) {
    if (bottom != null) _bottom = bottom;
    if (dx != null) _dx = dx;
    notifyListeners();
  }

  /// Starts from where the text is shown right now, not the stored value.
  void startDrag({required double shownBottom}) {
    _bottom = shownBottom;
    _dragging = true;
    notifyListeners();
  }

  void dragBy(Offset delta, {required Size area}) {
    _bottom = (_bottom - delta.dy).clamp(0.0, area.height - 60);
    _dx = (_dx + delta.dx).clamp(-area.width / 2, area.width / 2);
    notifyListeners();
  }

  void endDrag() {
    _dragging = false;
    notifyListeners();
  }

  void reset() {
    _bottom = baseBottom;
    _dx = 0;
    notifyListeners();
  }

  Future<void> load(AppDatabase db) async {
    restore(
      bottom: double.tryParse(await db.getSetting(settingSubBottom) ?? ''),
      dx: double.tryParse(await db.getSetting(settingSubDx) ?? ''),
    );
  }

  Future<void> save(AppDatabase? db) async {
    if (db == null) return;
    await db.setSetting(settingSubBottom, _bottom.toString());
    await db.setSetting(settingSubDx, _dx.toString());
  }
}
