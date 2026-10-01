import 'package:flutter/material.dart';

import 'theme_preferences.dart';

/// Тема приложения в стиле Material 3.
class AppTheme {
  const AppTheme._();

  /// Базовый цвет, из которого строятся светлая и тёмная схемы.
  static const Color seedColor = Color(0xFF7C4DFF);

  /// Ступени поверхностей AMOLED-темы.
  ///
  /// В обычной тёмной теме фон и карточка отличаются на пару процентов, и
  /// на OLED-экране глаз не различает их. Здесь разница между соседними
  /// ступенями заметно больше: 0 — фон, 1 — панели и поля, 2 — карточки,
  /// 3 — наведение и всплывающие элементы. Так карточка всегда темнее фона,
  /// а кнопка поверх карточки — светлее неё, и структура читается сразу.
  static const Color amoledSurface = Color(0xFF000000);
  static const Color amoledSurfaceLow = Color(0xFF0C0C0F);
  static const Color amoledSurfaceMid = Color(0xFF15151A);
  static const Color amoledSurfaceHigh = Color(0xFF1E1E25);
  static const Color amoledOutline = Color(0xFF2A2A33);

  /// Пересобирает тёмную схему в AMOLED-вариант.
  ///
  /// Акценты и текст берутся из обычной тёмной схемы — они уже читаемы.
  /// Меняются только фоновые тона и контуры.
  static ColorScheme _amoledScheme(ColorScheme base) {
    return base.copyWith(
      surface: amoledSurface,
      surfaceContainerLowest: amoledSurface,
      surfaceContainerLow: amoledSurfaceLow,
      surfaceContainer: amoledSurfaceLow,
      surfaceContainerHigh: amoledSurfaceMid,
      surfaceContainerHighest: amoledSurfaceHigh,
      surfaceTint: Colors.transparent,
      outlineVariant: amoledOutline,
      onSurfaceVariant: const Color(0xFFA0A0AE),
    );
  }

  /// Светлая тема.
  static ThemeData light({
    AccentColor accent = AccentColor.defaultAccent,
    int? customSeedColor,
  }) => _build(Brightness.light, accent, customSeedColor);

  /// Тёмная тема.
  static ThemeData dark({
    AccentColor accent = AccentColor.defaultAccent,
    int? customSeedColor,
    bool amoled = false,
  }) => _build(Brightness.dark, accent, customSeedColor, amoled: amoled);

  /// AMOLED-тема: чистый чёрный фон и ступенчатые поверхности.
  static ThemeData amoled({
    AccentColor accent = AccentColor.defaultAccent,
    int? customSeedColor,
  }) => _build(Brightness.dark, accent, customSeedColor, amoled: true);

  static ThemeData _build(
    Brightness brightness,
    AccentColor accent,
    int? customSeedColor, {
    bool amoled = false,
  }) {
    final seed = accent == AccentColor.custom
        ? (customSeedColor ?? ThemeSettings.defaultCustomSeedColor)
        : accent.seedValue;
    final base = ColorScheme.fromSeed(
      seedColor: Color(seed),
      brightness: brightness,
    );
    final scheme = amoled ? _amoledScheme(base) : base;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Списки и карточки с закруглёнными краями — проще ориентироваться
      // в списках дней рождения.
      cardTheme: CardThemeData(
        elevation: 0,
        color: amoled ? amoledSurfaceMid : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      // Карточки и плитки лежат на ступень выше фона: в AMOLED это единственный
      // способ отличить панель от подложки, потому что заливок почти нет.
      dialogTheme: DialogThemeData(
        backgroundColor: amoled ? amoledSurfaceMid : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: amoled ? amoledSurfaceMid : null,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: amoled ? amoledSurfaceLow : null,
        indicatorColor: amoled ? scheme.primary.withValues(alpha: 0.28) : null,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: amoled ? amoledSurfaceHigh : null,
        contentTextStyle: TextStyle(color: scheme.onSurface),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: amoled ? amoledSurfaceMid : null,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 0,
      ),
    );
  }
}
