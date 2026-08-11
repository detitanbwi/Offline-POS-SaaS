import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppFontSize {
  smallest(0.75, 'Sangat Kecil'),
  small(0.85, 'Kecil'),
  normal(0.95, 'Normal'),
  big(1.05, 'Besar'),
  biggest(1.15, 'Sangat Besar');

  final double scale;
  final String label;

  const AppFontSize(this.scale, this.label);

  static AppFontSize fromString(String? name) {
    return AppFontSize.values.firstWhere(
      (e) => e.name == name,
      orElse: () => AppFontSize.normal,
    );
  }
}

class FontSizeNotifier extends StateNotifier<AppFontSize> {
  static const _key = 'app_font_size_preference';
  final SharedPreferences? _prefs;

  FontSizeNotifier(this._prefs) : super(AppFontSize.normal) {
    _loadPreference();
  }

  void _loadPreference() {
    if (_prefs == null) return;
    final savedValue = _prefs!.getString(_key);
    state = AppFontSize.fromString(savedValue);
  }

  Future<void> setFontSize(AppFontSize fontSize) async {
    state = fontSize;
    if (_prefs != null) {
      await _prefs!.setString(_key, fontSize.name);
    }
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null); // Will be overridden in main or initialization

final fontSizeProvider = StateNotifierProvider<FontSizeNotifier, AppFontSize>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FontSizeNotifier(prefs);
});
