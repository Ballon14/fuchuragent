import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuchuragent/core/providers/app_providers.dart';

void main() {
  group('Theme Persistence Tests', () {
    test('ThemeModeNotifier defaults to ThemeMode.dark when no preference exists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final containerRef = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final theme = containerRef.read(themeModeProvider);
      expect(theme, equals(ThemeMode.dark));
    });

    test('ThemeModeNotifier loads saved ThemeMode.light from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'app_theme_mode': 'light'});
      final prefs = await SharedPreferences.getInstance();

      final containerRef = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final theme = containerRef.read(themeModeProvider);
      expect(theme, equals(ThemeMode.light));
    });

    test('Toggling theme changes state and writes to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'});
      final prefs = await SharedPreferences.getInstance();

      final containerRef = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      expect(containerRef.read(themeModeProvider), equals(ThemeMode.dark));

      // Toggle from dark to light
      await containerRef.read(themeModeProvider.notifier).toggle();
      expect(containerRef.read(themeModeProvider), equals(ThemeMode.light));
      expect(prefs.getString('app_theme_mode'), equals('light'));

      // Toggle from light back to dark
      await containerRef.read(themeModeProvider.notifier).toggle();
      expect(containerRef.read(themeModeProvider), equals(ThemeMode.dark));
      expect(prefs.getString('app_theme_mode'), equals('dark'));
    });

    test('Explicit setTheme persists custom value', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final containerRef = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      await containerRef.read(themeModeProvider.notifier).setTheme(ThemeMode.light);
      expect(containerRef.read(themeModeProvider), equals(ThemeMode.light));
      expect(prefs.getString('app_theme_mode'), equals('light'));
    });
  });
}
