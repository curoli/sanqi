import 'package:material_ui/material_ui.dart';

import 'l10n/generated/app_localizations.dart';

enum SkinPattern {
  diamonds,
  grid,
  dots,
  circles,
  confetti,
  waves,
  sunburst,
  tiles,
  stars,
  lines,
}

enum AppSkin {
  linen(
    brightness: Brightness.light,
    background: Color(0xFFE9DFC9),
    surface: Color(0xFFF8EFDD),
    button: Color(0xFFE3E9D9),
    text: Color(0xFF25352B),
    buttonText: Color(0xFF234A35),
    border: Color(0xFF6F8364),
    accent: Color(0xFF315948),
    fontFamily: 'Lora',
    pattern: SkinPattern.diamonds,
    radius: 12,
  ),
  porcelain(
    brightness: Brightness.light,
    background: Color(0xFFEAF1F8),
    surface: Color(0xFFF8FBFF),
    button: Color(0xFFDFE9F5),
    text: Color(0xFF142B46),
    buttonText: Color(0xFF1C3D65),
    border: Color(0xFF6C85A2),
    accent: Color(0xFF214D80),
    fontFamily: 'Inter',
    pattern: SkinPattern.grid,
    radius: 4,
  ),
  mint(
    brightness: Brightness.light,
    background: Color(0xFFD7F3E6),
    surface: Color(0xFFF0FFF7),
    button: Color(0xFFB8E9D0),
    text: Color(0xFF163F31),
    buttonText: Color(0xFF164F36),
    border: Color(0xFF559477),
    accent: Color(0xFF1F6C48),
    fontFamily: 'Nunito',
    pattern: SkinPattern.dots,
    radius: 20,
  ),
  sakura(
    brightness: Brightness.light,
    background: Color(0xFFF7DEE9),
    surface: Color(0xFFFFF4F8),
    button: Color(0xFFEDC9DB),
    text: Color(0xFF512B40),
    buttonText: Color(0xFF622542),
    border: Color(0xFFAC6B8E),
    accent: Color(0xFF8F3F69),
    fontFamily: 'Lora',
    pattern: SkinPattern.circles,
    radius: 18,
  ),
  sorbet(
    brightness: Brightness.light,
    background: Color(0xFFFFE4CC),
    surface: Color(0xFFFFF6EB),
    button: Color(0xFFFFD0B2),
    text: Color(0xFF4F263C),
    buttonText: Color(0xFF6C244A),
    border: Color(0xFFAC698C),
    accent: Color(0xFF9B2F60),
    fontFamily: 'Nunito',
    pattern: SkinPattern.confetti,
    radius: 22,
  ),
  lagoon(
    brightness: Brightness.light,
    background: Color(0xFFCDEEF0),
    surface: Color(0xFFECFAFA),
    button: Color(0xFFA6DCDD),
    text: Color(0xFF153E48),
    buttonText: Color(0xFF134853),
    border: Color(0xFF4D8994),
    accent: Color(0xFF126471),
    fontFamily: 'Inter',
    pattern: SkinPattern.waves,
    radius: 12,
  ),
  sunflower(
    brightness: Brightness.light,
    background: Color(0xFFF9E9A1),
    surface: Color(0xFFFFF8DA),
    button: Color(0xFFF4D86C),
    text: Color(0xFF3E3518),
    buttonText: Color(0xFF4E400B),
    border: Color(0xFF9B7E29),
    accent: Color(0xFF755A13),
    fontFamily: 'Nunito',
    pattern: SkinPattern.sunburst,
    radius: 16,
  ),
  blueprint(
    brightness: Brightness.dark,
    background: Color(0xFF102A50),
    surface: Color(0xFF173860),
    button: Color(0xFF234C7B),
    text: Color(0xFFEDF6FF),
    buttonText: Color(0xFFE8F8FF),
    border: Color(0xFF79AEDD),
    accent: Color(0xFFA0DFFF),
    fontFamily: 'SpaceMono',
    pattern: SkinPattern.grid,
    radius: 2,
  ),
  arcade(
    brightness: Brightness.dark,
    background: Color(0xFF18122B),
    surface: Color(0xFF251C3B),
    button: Color(0xFF392759),
    text: Color(0xFFF4EDFF),
    buttonText: Color(0xFFCEFF8B),
    border: Color(0xFFAE83F7),
    accent: Color(0xFFCEFF8B),
    fontFamily: 'SpaceMono',
    pattern: SkinPattern.tiles,
    radius: 0,
  ),
  midnight(
    brightness: Brightness.dark,
    background: Color(0xFF101D35),
    surface: Color(0xFF1A2C48),
    button: Color(0xFF294463),
    text: Color(0xFFEBF3FF),
    buttonText: Color(0xFFD4E9FF),
    border: Color(0xFF6E9BCA),
    accent: Color(0xFFA0CAFF),
    fontFamily: 'Inter',
    pattern: SkinPattern.stars,
    radius: 12,
  ),
  graphite(
    brightness: Brightness.dark,
    background: Color(0xFF20252A),
    surface: Color(0xFF2C333A),
    button: Color(0xFF414B55),
    text: Color(0xFFF2F3F5),
    buttonText: Color(0xFFF1F5F8),
    border: Color(0xFF8E9EAC),
    accent: Color(0xFFC3D3E0),
    fontFamily: 'Inter',
    pattern: SkinPattern.lines,
    radius: 4,
  ),
  ember(
    brightness: Brightness.dark,
    background: Color(0xFF2D1A16),
    surface: Color(0xFF412820),
    button: Color(0xFF633B29),
    text: Color(0xFFFFF0DD),
    buttonText: Color(0xFFFFD69D),
    border: Color(0xFFC8925B),
    accent: Color(0xFFF4B563),
    fontFamily: 'Lora',
    pattern: SkinPattern.circles,
    radius: 10,
  ),
  gilded(
    brightness: Brightness.dark,
    background: Color(0xFF1D201D),
    surface: Color(0xFF2B2E26),
    button: Color(0xFF444632),
    text: Color(0xFFFFF6D7),
    buttonText: Color(0xFFF6DD91),
    border: Color(0xFFB5A56B),
    accent: Color(0xFFE8CA78),
    fontFamily: 'Lora',
    pattern: SkinPattern.diamonds,
    radius: 2,
  ),
  aurora(
    brightness: Brightness.dark,
    background: Color(0xFF102F36),
    surface: Color(0xFF1C4048),
    button: Color(0xFF305965),
    text: Color(0xFFE8FFF8),
    buttonText: Color(0xFFB5FFE1),
    border: Color(0xFF6BBDAE),
    accent: Color(0xFF93E8C2),
    fontFamily: 'Nunito',
    pattern: SkinPattern.waves,
    radius: 20,
  );

  const AppSkin({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.button,
    required this.text,
    required this.buttonText,
    required this.border,
    required this.accent,
    required this.fontFamily,
    required this.pattern,
    required this.radius,
  });

  final Brightness brightness;
  final Color background, surface, button, text, buttonText, border, accent;
  final String fontFamily;
  final SkinPattern pattern;
  final double radius;

  List<String> get fallbackFonts => [
    fontFamily == 'Lora' ? 'NotoNaskhArabic' : 'NotoSansArabic',
  ];

  static AppSkin? fromId(String? id) {
    for (final skin in values) {
      if (skin.name == id) return skin;
    }
    return null;
  }

  static AppSkin of(BuildContext context) =>
      Theme.of(context).extension<SkinTheme>()?.skin ?? AppSkin.linen;

  String label(AppLocalizations l) => switch (this) {
    AppSkin.linen => l.skinLinen,
    AppSkin.porcelain => l.skinPorcelain,
    AppSkin.mint => l.skinMint,
    AppSkin.sakura => l.skinSakura,
    AppSkin.sorbet => l.skinSorbet,
    AppSkin.lagoon => l.skinLagoon,
    AppSkin.sunflower => l.skinSunflower,
    AppSkin.blueprint => l.skinBlueprint,
    AppSkin.arcade => l.skinArcade,
    AppSkin.midnight => l.skinMidnight,
    AppSkin.graphite => l.skinGraphite,
    AppSkin.ember => l.skinEmber,
    AppSkin.gilded => l.skinGilded,
    AppSkin.aurora => l.skinAurora,
  };

  ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      primary: accent,
      onPrimary: surface,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: text,
      outline: border,
      error: brightness == Brightness.dark
          ? const Color(0xFFFFB4AB)
          : const Color(0xFF9C1C24),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      fontFamilyFallback: fallbackFonts,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: button,
          foregroundColor: buttonText,
          disabledBackgroundColor: surface,
          disabledForegroundColor: text.withValues(alpha: .45),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: button,
          foregroundColor: buttonText,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(accent),
        trackColor: WidgetStatePropertyAll(border.withValues(alpha: .2)),
      ),
      extensions: [SkinTheme(this)],
    );
  }
}

/// Keep painting and component colors aligned with the selected Material theme.
class SkinTheme extends ThemeExtension<SkinTheme> {
  const SkinTheme(this.skin);
  final AppSkin skin;
  @override
  SkinTheme copyWith({AppSkin? skin}) => SkinTheme(skin ?? this.skin);
  @override
  SkinTheme lerp(covariant SkinTheme? other, double t) =>
      t < .5 ? this : other ?? this;
}
