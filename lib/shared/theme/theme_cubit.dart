import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/storage/hive_storage.dart';

/// Управление темой приложения (light/dark) с персистентностью в Hive.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.light) {
    _restore();
  }

  static const String _key = 'theme_mode';

  Future<void> _restore() async {
    try {
      final box = HiveStorage.preferencesBox();
      final raw = box.get(_key) as String?;
      switch (raw) {
        case 'dark':
          emit(ThemeMode.dark);
        case 'light':
          emit(ThemeMode.light);
      }
    } catch (e) {
      debugPrint('[Theme] restore failed: $e');
    }
  }

  Future<void> _persist(ThemeMode mode) async {
    try {
      final box = HiveStorage.preferencesBox();
      await box.put(_key, mode == ThemeMode.dark ? 'dark' : 'light');
    } catch (e) {
      debugPrint('[Theme] persist failed: $e');
    }
  }

  void setLight() {
    emit(ThemeMode.light);
    _persist(ThemeMode.light);
  }

  void setDark() {
    emit(ThemeMode.dark);
    _persist(ThemeMode.dark);
  }

  void toggle() {
    final next = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    emit(next);
    _persist(next);
  }
}
