/// What the player does when an episode with a saved position is opened.
enum ResumeBehavior {
  always('Always resume'),
  ask('Ask each time'),
  restart('Always start over');

  const ResumeBehavior(this.label);
  final String label;
}

/// Starting volume of the player.
enum VolumeMode {
  remember('Last used'),
  fixed('Fixed value');

  const VolumeMode(this.label);
  final String label;
}

enum PosterSize {
  small('Small', 160),
  medium('Medium', 200),
  large('Large', 250);

  const PosterSize(this.label, this.maxWidth);
  final String label;

  /// Grid `maxCrossAxisExtent` for this size.
  final double maxWidth;
}

/// How the home grid is ordered. Lives here (not in the home page) because
/// it is a saved setting.
enum ShowSort {
  name('Name, A to Z'),
  nameDesc('Name, Z to A'),
  episodes('Most episodes'),
  recentlyAdded('Recently added'),
  recentlyWatched('Recently watched');

  const ShowSort(this.label);
  final String label;
}

/// Languages offered for TMDB metadata (codes as TMDB expects them).
const metadataLanguages = <(String, String)>[
  ('en-US', 'English'),
  ('es-ES', 'Spanish'),
  ('fr-FR', 'French'),
  ('de-DE', 'German'),
  ('it-IT', 'Italian'),
  ('pt-BR', 'Portuguese (Brazil)'),
  ('ja-JP', 'Japanese'),
  ('ko-KR', 'Korean'),
  ('zh-CN', 'Chinese (Simplified)'),
  ('hi-IN', 'Hindi'),
];

/// Every user-changeable setting, immutable, with validated ranges.
/// Pure Dart: no storage, no Flutter. [SettingsController] persists it.
///
/// Out-of-range or unknown stored values fall back to the default for that
/// field, so a damaged or older settings table can never break the app.
class UserSettings {
  const UserSettings({
    this.autoplay = true,
    this.autoplayLeadSeconds = 30,
    this.autoplayCountdownSeconds = 10,
    this.skipStepSeconds = 10,
    this.controlsHideSeconds = 3,
    this.watchedPercent = 90,
    this.resume = ResumeBehavior.always,
    this.volumeMode = VolumeMode.remember,
    this.fixedVolume = 100,
    this.metadataLanguage,
    this.homeSort = ShowSort.name,
    this.posterSize = PosterSize.medium,
    this.showSpecials = true,
    this.showMissing = false,
    this.hardwareDecoding = true,
  });

  static const defaults = UserSettings();

  // Allowed ranges and choices (the settings screen uses these too).
  static const leadRange = (10, 120);
  static const countdownRange = (3, 30);
  static const skipSteps = [5, 10, 15, 30, 60];
  static const hideRange = (2, 10);
  static const watchedRange = (70, 100);
  static const volumeRange = (0, 100);

  final bool autoplay;

  /// The next-episode card appears when this many seconds remain.
  final int autoplayLeadSeconds;
  final int autoplayCountdownSeconds;
  final int skipStepSeconds;
  final int controlsHideSeconds;

  /// Percent of an episode played that counts as watched.
  final int watchedPercent;
  final ResumeBehavior resume;
  final VolumeMode volumeMode;
  final int fixedVolume;

  /// TMDB language code; null = use `TMDB_LANGUAGE` from `.env` (or en-US).
  final String? metadataLanguage;
  final ShowSort homeSort;
  final PosterSize posterSize;
  final bool showSpecials;
  final bool showMissing;

  /// Let the GPU decode video. Off falls back to the CPU (slower, but works
  /// around drivers that glitch).
  final bool hardwareDecoding;

  double get watchedFraction => watchedPercent / 100;
  Duration get skipStep => Duration(seconds: skipStepSeconds);

  UserSettings copyWith({
    bool? autoplay,
    int? autoplayLeadSeconds,
    int? autoplayCountdownSeconds,
    int? skipStepSeconds,
    int? controlsHideSeconds,
    int? watchedPercent,
    ResumeBehavior? resume,
    VolumeMode? volumeMode,
    int? fixedVolume,
    String? metadataLanguage,
    bool clearMetadataLanguage = false,
    ShowSort? homeSort,
    PosterSize? posterSize,
    bool? showSpecials,
    bool? showMissing,
    bool? hardwareDecoding,
  }) => UserSettings(
    autoplay: autoplay ?? this.autoplay,
    autoplayLeadSeconds: autoplayLeadSeconds ?? this.autoplayLeadSeconds,
    autoplayCountdownSeconds:
        autoplayCountdownSeconds ?? this.autoplayCountdownSeconds,
    skipStepSeconds: skipStepSeconds ?? this.skipStepSeconds,
    controlsHideSeconds: controlsHideSeconds ?? this.controlsHideSeconds,
    watchedPercent: watchedPercent ?? this.watchedPercent,
    resume: resume ?? this.resume,
    volumeMode: volumeMode ?? this.volumeMode,
    fixedVolume: fixedVolume ?? this.fixedVolume,
    metadataLanguage: clearMetadataLanguage
        ? null
        : (metadataLanguage ?? this.metadataLanguage),
    homeSort: homeSort ?? this.homeSort,
    posterSize: posterSize ?? this.posterSize,
    showSpecials: showSpecials ?? this.showSpecials,
    showMissing: showMissing ?? this.showMissing,
    hardwareDecoding: hardwareDecoding ?? this.hardwareDecoding,
  );

  /// Flat string map for the key/value settings table.
  Map<String, String> toMap() => {
    'autoplay': '$autoplay',
    'autoplayLead': '$autoplayLeadSeconds',
    'autoplayCountdown': '$autoplayCountdownSeconds',
    'skipStep': '$skipStepSeconds',
    'controlsHide': '$controlsHideSeconds',
    'watchedPercent': '$watchedPercent',
    'resume': resume.name,
    'volumeMode': volumeMode.name,
    'fixedVolume': '$fixedVolume',
    'metadataLanguage': metadataLanguage ?? '',
    'homeSort': homeSort.name,
    'posterSize': posterSize.name,
    'showSpecials': '$showSpecials',
    'showMissing': '$showMissing',
    'hardwareDecoding': '$hardwareDecoding',
  };

  /// Tolerant decode: missing, unparsable or out-of-range fields use the
  /// default.
  factory UserSettings.fromMap(Map<String, String> m) {
    const d = UserSettings.defaults;
    bool b(String k, bool fallback) => switch (m[k]) {
      'true' => true,
      'false' => false,
      _ => fallback,
    };
    int n(String k, int fallback, (int, int) range) {
      final v = int.tryParse(m[k] ?? '');
      return v != null && v >= range.$1 && v <= range.$2 ? v : fallback;
    }

    T e<T extends Enum>(String k, List<T> values, T fallback) {
      for (final v in values) {
        if (v.name == m[k]) return v;
      }
      return fallback;
    }

    final step = int.tryParse(m['skipStep'] ?? '');
    final lang = m['metadataLanguage'];
    return UserSettings(
      autoplay: b('autoplay', d.autoplay),
      autoplayLeadSeconds: n('autoplayLead', d.autoplayLeadSeconds, leadRange),
      autoplayCountdownSeconds: n(
        'autoplayCountdown',
        d.autoplayCountdownSeconds,
        countdownRange,
      ),
      skipStepSeconds: skipSteps.contains(step) ? step! : d.skipStepSeconds,
      controlsHideSeconds: n('controlsHide', d.controlsHideSeconds, hideRange),
      watchedPercent: n('watchedPercent', d.watchedPercent, watchedRange),
      resume: e('resume', ResumeBehavior.values, d.resume),
      volumeMode: e('volumeMode', VolumeMode.values, d.volumeMode),
      fixedVolume: n('fixedVolume', d.fixedVolume, volumeRange),
      metadataLanguage: metadataLanguages.any((l) => l.$1 == lang)
          ? lang
          : null,
      homeSort: e('homeSort', ShowSort.values, d.homeSort),
      posterSize: e('posterSize', PosterSize.values, d.posterSize),
      showSpecials: b('showSpecials', d.showSpecials),
      showMissing: b('showMissing', d.showMissing),
      hardwareDecoding: b('hardwareDecoding', d.hardwareDecoding),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! UserSettings) return false;
    final a = toMap(), b = other.toMap();
    for (final k in a.keys) {
      if (a[k] != b[k]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(toMap().values);
}
