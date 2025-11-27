import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class AppTheme {
  final String name;
  final Color background;
  final Color surface;
  final Color text;
  final Color textSecondary;
  final Color accent;
  final Color divider;
  final Color graphSleep;

  const AppTheme({
    required this.name,
    required this.background,
    required this.surface,
    required this.text,
    required this.textSecondary,
    required this.accent,
    required this.divider,
    required this.graphSleep,
  });
}

class ThemeProvider extends ChangeNotifier {
  static const String _boxName = 'settings';
  static const String _keyTheme = 'theme';

  late Box _box;
  bool _isInitialized = false;

  // Define Themes
  static const AppTheme blackTheme = AppTheme(
    name: 'Black',
    background: Colors.black,
    surface: Color(0xFF1E1E1E),
    text: Colors.white,
    textSecondary: Colors.white70,
    accent: Colors.blueAccent,
    divider: Colors.white10,
    graphSleep: Colors.purpleAccent,
  );

  static const AppTheme beigeTheme = AppTheme(
    name: 'Beige',
    background: Color(0xFFDCDAD2), // Darker Beige (was surface)
    surface: Color(0xFFEBE9E1),    // Light Beige (was background)
    text: Color(0xFF2D2D2D),       // Dark gray for text
    textSecondary: Color(0xFF555555),
    accent: Color(0xFF5D7B9D),     // Muted blue
    divider: Color(0xFFBDBBB5),
    graphSleep: Color(0xFF9D5D5D), // Muted Red/Brown
  );

  final List<AppTheme> availableThemes = [blackTheme, beigeTheme];

  AppTheme _currentTheme = blackTheme;
  AppTheme get currentTheme => _currentTheme;

  ThemeProvider() {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox(_boxName);
    _isInitialized = true;
    _loadTheme();
  }

  void _loadTheme() {
    final themeName = _box.get(_keyTheme, defaultValue: 'Black');
    _currentTheme = availableThemes.firstWhere(
      (t) => t.name == themeName,
      orElse: () => blackTheme,
    );
    notifyListeners();
  }

  Future<void> setTheme(String themeName) async {
    if (!_isInitialized) await _init();
    
    _currentTheme = availableThemes.firstWhere(
      (t) => t.name == themeName,
      orElse: () => blackTheme,
    );
    await _box.put(_keyTheme, themeName);
    notifyListeners();
  }
}
