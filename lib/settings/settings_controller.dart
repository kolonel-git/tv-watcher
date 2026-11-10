import 'package:flutter/widgets.dart';

import '../data/database.dart';
import '../metadata/metadata_service.dart';
import 'user_settings.dart';

/// Holds the current [UserSettings], saves changes to the database and pushes
/// the ones other layers cache (watched threshold, metadata language).
///
/// Widgets read it through [SettingsScope]; they never touch the database
/// settings table for these keys.
class SettingsController extends ChangeNotifier {
  SettingsController._(this._db, this._meta, this._value, this._envLanguage);

  /// Storage key prefix, so settings never collide with other keys
  /// (`player.volume`, `player.subStyle`, ...).
  static const keyPrefix = 'settings.';

  final AppDatabase _db;
  final MetadataService? _meta;
  final String _envLanguage;
  UserSettings _value;

  UserSettings get value => _value;

  /// Language used when the user has not picked one (from `.env`).
  String get envLanguage => _envLanguage;

  /// Loads saved settings and applies them. [envLanguage] is the
  /// `TMDB_LANGUAGE` default used while no language is chosen.
  static Future<SettingsController> load(
    AppDatabase db, {
    MetadataService? meta,
    String envLanguage = 'en-US',
  }) async {
    final stored = await db.settingsWithPrefix(keyPrefix);
    final c = SettingsController._(
      db,
      meta,
      UserSettings.fromMap(stored),
      envLanguage,
    );
    c._apply();
    return c;
  }

  /// In-memory controller for tests and previews (nothing is stored).
  @visibleForTesting
  static SettingsController memory(
    AppDatabase db, [
    UserSettings value = UserSettings.defaults,
  ]) => SettingsController._(db, null, value, 'en-US');

  /// Applies [next], notifies listeners and saves only what changed.
  Future<void> update(UserSettings next) async {
    if (next == _value) return;
    final before = _value.toMap();
    _value = next;
    _apply();
    notifyListeners();
    final after = next.toMap();
    for (final k in after.keys) {
      if (after[k] != before[k]) {
        await _db.setSetting('$keyPrefix$k', after[k]!);
      }
    }
  }

  /// Re-reads the stored settings (after a backup restore wrote them).
  Future<void> reload() async {
    _value = UserSettings.fromMap(await _db.settingsWithPrefix(keyPrefix));
    _apply();
    notifyListeners();
  }

  /// Back to defaults; also removes the stored values.
  Future<void> reset() async {
    _value = UserSettings.defaults;
    _apply();
    notifyListeners();
    await _db.deleteSettingsWithPrefix(keyPrefix);
  }

  void _apply() {
    _db.watchedFraction = _value.watchedFraction;
    _meta?.client.language = _value.metadataLanguage ?? _envLanguage;
  }
}

/// Makes the [SettingsController] available below it. Widgets without a
/// scope (most widget tests) get [UserSettings.defaults].
class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Current settings; rebuilds the caller when they change.
  static UserSettings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    return scope?.notifier?.value ?? UserSettings.defaults;
  }

  /// The controller, or null when there is no scope (tests).
  static SettingsController? controllerOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SettingsScope>()?.notifier;
}
