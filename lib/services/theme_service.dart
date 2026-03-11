import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeType { modern, corporate }

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'selected_theme';
  ThemeType _currentTheme = ThemeType.modern;

  ThemeType get currentTheme => _currentTheme;
  bool get isModern => _currentTheme == ThemeType.modern;

  ThemeService() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey);
    if (themeIndex != null) {
      _currentTheme = ThemeType.values[themeIndex];
      notifyListeners();
    }
  }

  Future<void> setTheme(ThemeType theme) async {
    if (_currentTheme == theme) return;
    _currentTheme = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, theme.index);
  }

  void toggleTheme() {
    setTheme(_currentTheme == ThemeType.modern ? ThemeType.corporate : ThemeType.modern);
  }

  // --- Theme-Aware Color Helpers ---
  Color get headingColor => isModern ? AppColors.textHeading : AppColors.mgmtTextHeading;
  Color get bodyColor => isModern ? AppColors.textBody : AppColors.mgmtTextBody;
  Color get cardColor => isModern ? AppColors.surface : AppColors.mgmtSurface;
  Color get accentColor => isModern ? AppColors.primary : AppColors.mgmtAccent;
}
