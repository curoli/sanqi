enum AppLanguage {
  english('en', '🇬🇧', 'English'),
  german('de', '🇩🇪', 'Deutsch'),
  indonesian('id', '🇮🇩', 'Bahasa Indonesia'),
  arabic('ar', '🇸🇦', 'العربية'),
  chinese('zh', '🇨🇳', '中文'),
  spanish('es', '🇪🇸', 'Español'),
  turkish('tr', '🇹🇷', 'Türkçe');

  const AppLanguage(this.code, this.flag, this.name);
  final String code;
  final String flag;
  final String name;

  static AppLanguage? fromCode(String? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return null;
  }
}
