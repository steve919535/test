import 'package:flutter/material.dart';

import '../data/trip.dart';

const Color _seedColor = Color(0xFF2E6F40);

ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    ),
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ),
  );
}

Color categoryColor(BuildContext context, TripCategory category) {
  final scheme = Theme.of(context).colorScheme;
  return switch (category) {
    TripCategory.business => scheme.primary,
    TripCategory.personal => scheme.tertiary,
    TripCategory.unclassified => scheme.outline,
  };
}
