import 'package:material_ui/material_ui.dart';

import 'package:free_send/ui/kit/tokens.dart';

export 'package:free_send/ui/kit/tokens.dart';

extension AppSchemeColors on ColorScheme {
  bool get isLight => brightness == Brightness.light;

  /// Accent colour that stays readable as text on this brightness.
  Color get accentText => isLight ? AppColors.accentDeep : AppColors.accent;

  /// Fill for grouped content that needs to stand slightly off the page.
  Color get softFill => surfaceContainerLow;

  /// Hairline between rows.
  Color get hairline => outlineVariant;
}

abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.accent,
      onPrimary: AppColors.neutral0,
      primaryContainer: AppColors.accentWash,
      onPrimaryContainer: AppColors.accentInk,
      secondary: AppColors.neutral700,
      onSecondary: AppColors.neutral0,
      secondaryContainer: AppColors.neutral100,
      onSecondaryContainer: AppColors.neutral900,
      tertiary: AppColors.accent,
      onTertiary: AppColors.neutral0,
      error: AppColors.danger,
      onError: AppColors.neutral0,
      surface: AppColors.page,
      onSurface: AppColors.ink,
      surfaceContainerLowest: AppColors.neutral0,
      surfaceContainerLow: AppColors.neutral50,
      surfaceContainer: AppColors.neutral50,
      surfaceContainerHigh: AppColors.neutral100,
      surfaceContainerHighest: AppColors.neutral200,
      onSurfaceVariant: AppColors.neutral600,
      outline: AppColors.neutral200,
      outlineVariant: Color(0xFFEDEDED),
      shadow: Color(0x0F000000),
      scrim: Color(0x66000000),
      inverseSurface: AppColors.neutral900,
      onInverseSurface: AppColors.neutral50,
    );
    return _base(scheme, AppColors.page);
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.accent,
      onPrimary: AppColors.neutral0,
      primaryContainer: AppColors.accentWashDark,
      onPrimaryContainer: AppColors.accentInkDark,
      secondary: AppColors.neutral300,
      onSecondary: AppColors.neutral900,
      secondaryContainer: AppColors.surfaceRaised,
      onSecondaryContainer: AppColors.neutral100,
      tertiary: AppColors.accent,
      onTertiary: AppColors.neutral0,
      error: AppColors.danger,
      onError: AppColors.neutral0,
      surface: AppColors.ink,
      onSurface: AppColors.neutral100,
      surfaceContainerLowest: AppColors.surfaceRaised,
      surfaceContainerLow: AppColors.surfaceRaised,
      surfaceContainer: AppColors.surfaceRaised,
      surfaceContainerHigh: AppColors.surfaceRaised,
      surfaceContainerHighest: AppColors.surfaceRaised,
      onSurfaceVariant: AppColors.neutral400,
      outline: Color(0xFF3A3A3A),
      outlineVariant: Color(0xFF2C2C2C),
      shadow: Color(0x66000000),
      scrim: Color(0x99000000),
      inverseSurface: AppColors.neutral100,
      onInverseSurface: AppColors.neutral900,
    );
    return _base(scheme, AppColors.ink);
  }

  static ThemeData _base(ColorScheme scheme, Color page) {
    final textTheme = _textTheme(scheme);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Public Sans',
      fontFamilyFallback: const ['Cairo'],
      scaffoldBackgroundColor: page,
      canvasColor: page,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      dividerColor: scheme.outlineVariant,
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface, size: 20),
      appBarTheme: AppBarTheme(
        backgroundColor: page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 20),
        actionsIconTheme: IconThemeData(color: scheme.onSurface, size: 20),
      ),
      // Cards carry a soft fill and nothing else: no border, no shadow.
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 45),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.field),
          ),
        ),
      ),
      // The secondary button is a soft neutral fill rather than an outline.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 45)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? scheme.surfaceContainerLow
                : scheme.surfaceContainerHigh,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
                : scheme.onSurface,
          ),
          side: const WidgetStatePropertyAll(BorderSide.none),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.field),
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: textTheme.labelLarge,
          foregroundColor: scheme.accentText,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(AppColors.neutral0),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          20,
          AppSpacing.md,
          14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => textTheme.labelMedium!.copyWith(
            color: states.contains(WidgetState.focused)
                ? scheme.accentText
                : scheme.onSurfaceVariant,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerLow,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        modalBarrierColor: scheme.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: scheme.surfaceContainerHigh,
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    final base = ThemeData(
      brightness: scheme.brightness,
      colorScheme: scheme,
    ).textTheme;
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontFamily: 'Public Sans',
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
        color: scheme.onSurface,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: 'Public Sans',
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: scheme.onSurface,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontFamily: 'Public Sans',
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: scheme.onSurface,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: 'Public Sans',
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        fontSize: 19,
        color: scheme.onSurface,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 16,
        height: 1.45,
        color: scheme.onSurface,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 14,
        height: 1.45,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}
