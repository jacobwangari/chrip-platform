import 'package:flutter/material.dart';

/// Central theme definition. Keeping this out of main.dart means
/// swapping the whole visual identity later never touches the
/// entry point.
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      );

  static ThemeData get dark => ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      );
}
