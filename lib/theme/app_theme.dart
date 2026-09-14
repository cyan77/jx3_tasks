import 'package:flutter/material.dart';

class AppTheme {
  static const ink = Color(0xff26332f);
  static const muted = Color(0xff76857f);
  static const line = Color(0xffe4eae7);
  static const soft = Color(0xfff7f9f8);
  static const accent = Color(0xff3c8c72);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
                seedColor: accent, brightness: Brightness.light)
            .copyWith(
          primary: accent,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xffe1f1ea),
          onPrimaryContainer: const Color(0xff245f4c),
          secondary: const Color(0xff69a991),
          secondaryContainer: const Color(0xffe8f3ee),
          tertiary: const Color(0xff8bb7a5),
          outline: const Color(0xffc5d5ce),
          outlineVariant: line,
          surface: Colors.white,
        ),
        fontFamily: 'Arial',
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: ink,
              height: 1.2),
          titleLarge:
              TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
          titleMedium:
              TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ink),
          bodyLarge: TextStyle(fontSize: 14, color: ink),
          bodyMedium: TextStyle(fontSize: 13, color: ink),
          labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: soft,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: line)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: line)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: accent, width: 1.2)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          isDense: true,
        ),
        dividerTheme:
            const DividerThemeData(color: line, space: 1, thickness: 1),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          titleSpacing: 24,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: const NavigationBarThemeData(
            height: 62,
            labelTextStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            indicatorColor: Color(0xffe5f3ed)),
        chipTheme: ChipThemeData(
            backgroundColor: soft,
            side: const BorderSide(color: line),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            labelStyle: const TextStyle(fontSize: 12, color: ink)),
      );

  static ThemeData get dark {
    const darkSurface = Color(0xff171d1b);
    const darkRaised = Color(0xff202925);
    const darkLine = Color(0xff35433d);
    const darkText = Color(0xffe5ece8);
    const darkMuted = Color(0xffa5b4ad);
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: darkSurface,
    ).copyWith(
      primary: const Color(0xff74b89f),
      onPrimary: const Color(0xff10372b),
      primaryContainer: const Color(0xff294a3f),
      onPrimaryContainer: const Color(0xffd6eee4),
      secondary: const Color(0xff91bfae),
      secondaryContainer: const Color(0xff304a40),
      tertiary: const Color(0xffabcbbd),
      surface: darkSurface,
      surfaceContainerLow: darkRaised,
      surfaceContainer: darkRaised,
      outlineVariant: darkLine,
      onSurface: darkText,
      onSurfaceVariant: darkMuted,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkSurface,
      colorScheme: scheme,
      fontFamily: 'Arial',
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: darkText,
            height: 1.2),
        titleLarge: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: darkText),
        titleMedium: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: darkText),
        bodyLarge: TextStyle(fontSize: 14, color: darkText),
        bodyMedium: TextStyle(fontSize: 13, color: darkText),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: darkLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: darkLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: Color(0xff74b89f), width: 1.2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        isDense: true,
      ),
      dividerTheme:
          const DividerThemeData(color: darkLine, space: 1, thickness: 1),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        titleSpacing: 24,
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 62,
        backgroundColor: darkRaised,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        indicatorColor: Color(0xff294a3f),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkRaised,
        side: const BorderSide(color: darkLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        labelStyle: const TextStyle(fontSize: 12, color: darkText),
      ),
      cardColor: darkRaised,
      dialogTheme: const DialogThemeData(backgroundColor: darkRaised),
    );
  }
}
