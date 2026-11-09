// Language code normalisation. mpv reports ISO 639-2 codes ("eng", "jpn"),
// subtitle filenames tend to use 2-letter codes ("en") or names ("English").

const _names = <String, String>{
  'en': 'English',
  'ja': 'Japanese',
  'fr': 'French',
  'de': 'German',
  'es': 'Spanish',
  'it': 'Italian',
  'pt': 'Portuguese',
  'ru': 'Russian',
  'ko': 'Korean',
  'zh': 'Chinese',
  'hi': 'Hindi',
  'ar': 'Arabic',
  'tr': 'Turkish',
  'pl': 'Polish',
  'nl': 'Dutch',
  'sv': 'Swedish',
  'no': 'Norwegian',
  'da': 'Danish',
  'fi': 'Finnish',
  'th': 'Thai',
  'vi': 'Vietnamese',
  'id': 'Indonesian',
  'he': 'Hebrew',
  'el': 'Greek',
  'cs': 'Czech',
  'hu': 'Hungarian',
  'ro': 'Romanian',
  'uk': 'Ukrainian',
  'bg': 'Bulgarian',
  'tl': 'Filipino',
  'ms': 'Malay',
  'fa': 'Persian',
  'ta': 'Tamil',
  'te': 'Telugu',
  'bn': 'Bengali',
};

/// 3-letter (and variant) codes and names -> 2-letter code.
const _aliases = <String, String>{
  'eng': 'en',
  'english': 'en',
  'en-us': 'en',
  'en-gb': 'en',
  'jpn': 'ja',
  'jap': 'ja',
  'japanese': 'ja',
  'jp': 'ja',
  'fra': 'fr',
  'fre': 'fr',
  'french': 'fr',
  'deu': 'de',
  'ger': 'de',
  'german': 'de',
  'spa': 'es',
  'spanish': 'es',
  'esp': 'es',
  'ita': 'it',
  'italian': 'it',
  'por': 'pt',
  'portuguese': 'pt',
  'pt-br': 'pt',
  'pob': 'pt',
  'rus': 'ru',
  'russian': 'ru',
  'kor': 'ko',
  'korean': 'ko',
  'zho': 'zh',
  'chi': 'zh',
  'chinese': 'zh',
  'zh-cn': 'zh',
  'zh-tw': 'zh',
  'chs': 'zh',
  'cht': 'zh',
  'hin': 'hi',
  'hindi': 'hi',
  'ara': 'ar',
  'arabic': 'ar',
  'tur': 'tr',
  'turkish': 'tr',
  'pol': 'pl',
  'polish': 'pl',
  'nld': 'nl',
  'dut': 'nl',
  'dutch': 'nl',
  'swe': 'sv',
  'swedish': 'sv',
  'nor': 'no',
  'nob': 'no',
  'norwegian': 'no',
  'dan': 'da',
  'danish': 'da',
  'fin': 'fi',
  'finnish': 'fi',
  'tha': 'th',
  'thai': 'th',
  'vie': 'vi',
  'vietnamese': 'vi',
  'ind': 'id',
  'indonesian': 'id',
  'heb': 'he',
  'hebrew': 'he',
  'ell': 'el',
  'gre': 'el',
  'greek': 'el',
  'ces': 'cs',
  'cze': 'cs',
  'czech': 'cs',
  'hun': 'hu',
  'hungarian': 'hu',
  'ron': 'ro',
  'rum': 'ro',
  'romanian': 'ro',
  'ukr': 'uk',
  'ukrainian': 'uk',
  'bul': 'bg',
  'bulgarian': 'bg',
  'fil': 'tl',
  'tgl': 'tl',
  'filipino': 'tl',
  'msa': 'ms',
  'may': 'ms',
  'malay': 'ms',
  'fas': 'fa',
  'per': 'fa',
  'persian': 'fa',
  'tam': 'ta',
  'tamil': 'ta',
  'tel': 'te',
  'telugu': 'te',
  'ben': 'bn',
  'bengali': 'bn',
};

/// Canonical form for comparing languages, or null when unknown/empty.
/// Known languages become their 2-letter code; unknown values are lowercased.
String? normalizeLang(String? raw) {
  if (raw == null) return null;
  final v = raw.trim().toLowerCase();
  if (v.isEmpty || v == 'und' || v == 'unknown') return null;
  if (_names.containsKey(v)) return v;
  final alias = _aliases[v];
  if (alias != null) return alias;
  // "en-US", "pt_BR": try the primary subtag.
  final primary = v.split(RegExp(r'[-_]')).first;
  if (_names.containsKey(primary)) return primary;
  return _aliases[primary] ?? v;
}

/// True when [token] is recognisably a language code or name.
bool isKnownLanguage(String token) {
  final v = token.trim().toLowerCase();
  if (v.isEmpty) return false;
  return _names.containsKey(v) ||
      _aliases.containsKey(v) ||
      _names.containsKey(v.split(RegExp(r'[-_]')).first);
}

/// Display name for a language code or name ("jpn" -> "Japanese").
String? languageName(String? raw) {
  final n = normalizeLang(raw);
  if (n == null) return null;
  return _names[n] ?? raw!.trim();
}
