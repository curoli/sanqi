enum AppLanguage {
  english('en', '🇬🇧', 'English'),
  german('de', '🇩🇪', 'Deutsch'),
  indonesian('id', '🇮🇩', 'Bahasa Indonesia'),
  arabic('ar', '🇸🇦', 'العربية'),
  chinese('zh', '🇨🇳', '中文'),
  spanish('es', '🇪🇸', 'Español'),
  turkish('tr', '🇹🇷', 'Türkçe'),
  hindi('hi', '🇮🇳', 'हिन्दी'),
  french('fr', '🇫🇷', 'Français'),
  bengali('bn', '🇧🇩', 'বাংলা'),
  portuguese('pt', '🇵🇹', 'Português'),
  urdu('ur', '🇵🇰', 'اردو'),
  russian('ru', '🇷🇺', 'Русский'),
  japanese('ja', '🇯🇵', '日本語');

  const AppLanguage(this.code, this.flag, this.name);
  final String code;
  final String flag;
  final String name;
  bool get isRtl => this == arabic || this == urdu;

  static AppLanguage? fromCode(String? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return null;
  }
}
