import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine_bridge.dart';

/// Centralized tactile haptic design system ported from Omlan/NoteX.
class AppHaptics {
  const AppHaptics._();

  static Future<void> selection() => HapticFeedback.selectionClick();
  static Future<void> light() => HapticFeedback.lightImpact();
  static Future<void> medium() => HapticFeedback.mediumImpact();
  static Future<void> heavy() => HapticFeedback.heavyImpact();

  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.lightImpact();
  }

  static Future<void> error() => HapticFeedback.vibrate();
}

/// Bento Grid + Pastel Semantic Colors from Omlan/NoteX
abstract final class AppColors {
  static const Color primary = Color(0xFF09090B);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5E9);
}

/// Radii & Spacing tokens from Omlan/NoteX
abstract final class AppTheme {
  static const double radiusXs = 8;
  static const double radiusSm = 14;
  static const double radiusMd = 22;
  static const double radiusLg = 30;
  static const double radiusXl = 38;
  static const double radiusFull = 999;

  static const double sp4 = 4;
  static const double sp8 = 8;
  static const double sp12 = 12;
  static const double sp16 = 16;
  static const double sp20 = 20;
  static const double sp24 = 24;
  static const double sp32 = 32;
  static const double sp48 = 48;
}

/// Curated 8 Font Families from Omlan/NoteX (bundled offline in assets/fonts/)
enum AppFontFamily {
  plusJakartaSans(
    id: 'plus_jakarta_sans',
    familyName: 'PlusJakartaSans',
    name: 'Plus Jakarta Sans',
    category: 'Modern Sans',
    subtitle: 'Geometric neo-grotesque with crisp balance',
    isHandwritten: false,
  ),
  outfit(
    id: 'outfit',
    familyName: 'Outfit',
    name: 'Outfit',
    category: 'Geometric Display',
    subtitle: 'Friendly, contemporary curves with high energy',
    isHandwritten: false,
  ),
  spaceGrotesk(
    id: 'space_grotesk',
    familyName: 'SpaceGrotesk',
    name: 'Space Grotesk',
    category: 'Display & Quirky',
    subtitle: 'Monospace-inspired proportional display typeface',
    isHandwritten: false,
  ),
  playfairDisplay(
    id: 'playfair_display',
    familyName: 'PlayfairDisplay',
    name: 'Playfair Display',
    category: 'Editorial Serif',
    subtitle: 'Sophisticated, high-contrast literary headlines',
    isHandwritten: false,
  ),
  lora(
    id: 'lora',
    familyName: 'Lora',
    name: 'Lora',
    category: 'Contemporary Serif',
    subtitle: 'Warm, memorable book serif with effortless readability',
    isHandwritten: false,
  ),
  jetBrainsMono(
    id: 'jetbrains_mono',
    familyName: 'JetBrainsMono',
    name: 'JetBrains Mono',
    category: 'Modern Code',
    subtitle: 'Clean developer aesthetic with rhythmic spacing',
    isHandwritten: false,
  ),
  caveat(
    id: 'caveat',
    familyName: 'Caveat',
    name: 'Caveat',
    category: 'Handwritten Script',
    subtitle: 'Expressive, natural cursive handwritten notes',
    isHandwritten: true,
  ),
  kalam(
    id: 'kalam',
    familyName: 'Kalam',
    name: 'Kalam',
    category: 'Handwritten Casual',
    subtitle: 'Warm, authentic pen and marker bullet journal feel',
    isHandwritten: true,
  );

  const AppFontFamily({
    required this.id,
    required this.familyName,
    required this.name,
    required this.category,
    required this.subtitle,
    required this.isHandwritten,
  });

  final String id;
  final String familyName;
  final String name;
  final String category;
  final String subtitle;
  final bool isHandwritten;

  static AppFontFamily fromString(String? raw) {
    if (raw == null || raw.isEmpty) return AppFontFamily.plusJakartaSans;
    for (final font in AppFontFamily.values) {
      if (font.id == raw) return font;
    }
    return AppFontFamily.plusJakartaSans;
  }

  TextStyle getTextStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    FontStyle? fontStyle,
  }) {
    return TextStyle(
      fontFamily: familyName,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      fontStyle: fontStyle,
    );
  }

  TextTheme getTextTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: getTextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: primary,
        letterSpacing: -0.8,
        height: 1.25,
      ),
      displayMedium: getTextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: primary,
        letterSpacing: -0.6,
        height: 1.25,
      ),
      displaySmall: getTextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.4,
        height: 1.25,
      ),
      headlineMedium: getTextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.3,
        height: 1.3,
      ),
      headlineSmall: getTextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.3,
      ),
      titleLarge: getTextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.35,
      ),
      titleMedium: getTextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.35,
      ),
      titleSmall: getTextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: secondary,
        height: 1.35,
      ),
      bodyLarge: getTextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primary,
        height: 1.45,
      ),
      bodyMedium: getTextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: primary,
        height: 1.45,
      ),
      bodySmall: getTextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.4,
      ),
      labelLarge: getTextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      labelMedium: getTextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
      labelSmall: getTextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
    );
  }
}

class FontSettings {
  const FontSettings({
    this.fontFamily = AppFontFamily.plusJakartaSans,
    this.noteTitleSize = 20.0,
    this.noteBodySize = 14.0,
    this.uiTextScale = 1.0,
  });

  final AppFontFamily fontFamily;
  final double noteTitleSize;
  final double noteBodySize;
  final double uiTextScale;

  FontSettings copyWith({
    AppFontFamily? fontFamily,
    double? noteTitleSize,
    double? noteBodySize,
    double? uiTextScale,
  }) {
    return FontSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      noteTitleSize: noteTitleSize ?? this.noteTitleSize,
      noteBodySize: noteBodySize ?? this.noteBodySize,
      uiTextScale: uiTextScale ?? this.uiTextScale,
    );
  }
}

/// Only 2 Themes: White Mode and Dark Mode
enum AppThemeId {
  pureLight(
    id: 'pure_light',
    name: 'White Mode',
    subtitle: 'Crisp minimalist white mode',
    isDark: false,
  ),
  pureDark(
    id: 'pure_dark',
    name: 'Dark Mode',
    subtitle: 'Stealth pitch dark mode',
    isDark: true,
  );

  const AppThemeId({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.isDark,
  });

  final String id;
  final String name;
  final String subtitle;
  final bool isDark;

  static AppThemeId fromString(String? raw) {
    if (raw == 'pure_dark' || raw == 'dark' || raw == 'dark_mode') {
      return AppThemeId.pureDark;
    }
    return AppThemeId.pureLight;
  }
}

class AppThemePalette {
  const AppThemePalette({
    required this.themeId,
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.primaryContainer,
    required this.secondary,
    required this.accent,
    required this.error,
    required this.success,
    required this.cardBackground,
    required this.cardColors,
    required this.noteDetailsBackground,
    required this.totalExpenseCardColor,
    required this.previewCardBg,
    required this.previewTextColor,
    required this.previewAccentColor,
  });

  final AppThemeId themeId;
  final bool isDark;
  final Color background;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color primary;
  final Color primaryContainer;
  final Color secondary;
  final Color accent;
  final Color error;
  final Color success;
  final Color cardBackground;
  final List<Color> cardColors;
  final Color noteDetailsBackground;
  final Color totalExpenseCardColor;
  final Color previewCardBg;
  final Color previewTextColor;
  final Color previewAccentColor;

  Color get onPrimary =>
      isDark && (primary == Colors.white || primary.computeLuminance() > 0.5)
          ? Colors.black
          : (primary.computeLuminance() > 0.5 ? Colors.black : Colors.white);

  Color getNoteCardColor(int index) {
    if (cardColors.length > 1) {
      return cardColors[index.abs() % cardColors.length];
    }
    return cardBackground;
  }

  Color getNoteCardTextColor(int index) {
    final bg = getNoteCardColor(index);
    return bg.computeLuminance() > 0.45
        ? const Color(0xFF111114)
        : const Color(0xFFFFFFFF);
  }

  Color getNoteCardSubtitleColor(int index) {
    final bg = getNoteCardColor(index);
    return bg.computeLuminance() > 0.45
        ? const Color(0xFF4B5563)
        : const Color(0xFFD1D5DB);
  }

  ThemeData buildThemeData({FontSettings? fontSettings}) {
    final family = fontSettings?.fontFamily ?? AppFontFamily.plusJakartaSans;
    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: textPrimary,
      secondary: secondary,
      onSecondary: Colors.white,
      secondaryContainer: secondary.withValues(alpha: 0.15),
      onSecondaryContainer: textPrimary,
      tertiary: accent,
      onTertiary: isDark ? Colors.black : Colors.white,
      error: error,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: border,
      outlineVariant: border.withValues(alpha: 0.5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: family.getTextTheme(textPrimary, textSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: family.getTextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.05,
          height: 1.35,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: border),
        ),
        color: surface,
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(38)),
        ),
      ),
      extensions: [AppThemePaletteExtension(this)],
    );
  }
}

class AppThemePaletteExtension
    extends ThemeExtension<AppThemePaletteExtension> {
  const AppThemePaletteExtension(this.palette);
  final AppThemePalette palette;

  @override
  ThemeExtension<AppThemePaletteExtension> copyWith({
    AppThemePalette? palette,
  }) => AppThemePaletteExtension(palette ?? this.palette);

  @override
  ThemeExtension<AppThemePaletteExtension> lerp(
    covariant ThemeExtension<AppThemePaletteExtension>? other,
    double t,
  ) => this;
}

extension AppThemeContextExtension on BuildContext {
  AppThemePalette get palette =>
      Theme.of(this).extension<AppThemePaletteExtension>()?.palette ??
      AppThemePalettes.pureLight;
}

abstract final class AppThemePalettes {
  static const pureLight = AppThemePalette(
    themeId: AppThemeId.pureLight,
    isDark: false,
    background: Color(0xFFF6F6F8),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEFEFF3),
    border: Color(0xFFE4E4E8),
    textPrimary: Color(0xFF09090B),
    textSecondary: Color(0xFF52525B),
    textMuted: Color(0xFF71717A),
    primary: Color(0xFF09090B),
    primaryContainer: Color(0xFFE4E4E7),
    secondary: Color(0xFF52525B),
    accent: Color(0xFF18181B),
    error: AppColors.error,
    success: AppColors.success,
    cardBackground: Color(0xFFFFFFFF),
    cardColors: [Color(0xFFFFFFFF)],
    noteDetailsBackground: Color(0xFFFFFFFF),
    totalExpenseCardColor: Color(0xFFFFFFFF),
    previewCardBg: Color(0xFFFFFFFF),
    previewTextColor: Color(0xFF09090B),
    previewAccentColor: Color(0xFF09090B),
  );

  static const pureDark = AppThemePalette(
    themeId: AppThemeId.pureDark,
    isDark: true,
    background: Color(0xFF09090B),
    surface: Color(0xFF141417),
    surface2: Color(0xFF1E1E24),
    border: Color(0xFF27272A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
    primary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF27272A),
    secondary: Color(0xFFA1A1AA),
    accent: Color(0xFFE4E4E7),
    error: AppColors.error,
    success: AppColors.success,
    cardBackground: Color(0xFF141417),
    cardColors: [Color(0xFF141417)],
    noteDetailsBackground: Color(0xFF0E0E11),
    totalExpenseCardColor: Color(0xFF141417),
    previewCardBg: Color(0xFF141417),
    previewTextColor: Color(0xFFFFFFFF),
    previewAccentColor: Color(0xFFE4E4E7),
  );

  static const List<AppThemePalette> all = [
    pureLight,
    pureDark,
  ];

  static AppThemePalette getById(AppThemeId id) {
    switch (id) {
      case AppThemeId.pureLight:
        return pureLight;
      case AppThemeId.pureDark:
        return pureDark;
    }
  }
}

/// Global controller synchronizing White/Dark Theme & Font preferences with NoDoomPrefs
class AppUiController extends ChangeNotifier {
  static final AppUiController instance = AppUiController._();
  AppUiController._();

  AppThemeId _themeId = AppThemeId.pureLight;
  final FontSettings _fontSettings = const FontSettings();

  AppThemeId get themeId => _themeId;
  AppThemePalette get palette => AppThemePalettes.getById(_themeId);
  FontSettings get fontSettings => _fontSettings;

  void syncFromEngineState(EngineState s) {
    final nextTheme = s.themeId == 'pure_dark' || (!s.lightMode && s.themeId == 'pure_dark')
        ? AppThemeId.pureDark
        : AppThemeId.fromString(s.themeId);
    if (nextTheme != _themeId) {
      _themeId = nextTheme;
      notifyListeners();
    }
  }

  Future<void> setTheme(AppThemeId next) async {
    _themeId = next;
    notifyListeners();
    await EngineBridge.updateSettings(
      themeId: next.id,
      lightMode: !next.isDark,
    );
  }

  Future<void> setDarkMode(bool isDark) async {
    await setTheme(isDark ? AppThemeId.pureDark : AppThemeId.pureLight);
  }
}
