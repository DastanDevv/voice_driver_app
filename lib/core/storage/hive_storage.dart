import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Имена ящиков Hive — единый источник истины.
abstract final class HiveBoxes {
  static const String tasks = 'tasks';
  static const String history = 'command_history';
  static const String chat = 'chat_messages';
  static const String preferences = 'preferences';
}

/// Инициализация Hive перед запуском приложения.
class HiveStorage {
  HiveStorage._();

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      await Hive.initFlutter();
      await Future.wait([
        Hive.openBox<Map<dynamic, dynamic>>(HiveBoxes.tasks),
        Hive.openBox<Map<dynamic, dynamic>>(HiveBoxes.history),
        Hive.openBox<Map<dynamic, dynamic>>(HiveBoxes.chat),
        Hive.openBox<dynamic>(HiveBoxes.preferences),
      ]);
      _initialized = true;
    } catch (e, st) {
      debugPrint('[Hive] init failed: $e\n$st');
    }
  }

  static Box<Map<dynamic, dynamic>> tasksBox() =>
      Hive.box<Map<dynamic, dynamic>>(HiveBoxes.tasks);

  static Box<Map<dynamic, dynamic>> historyBox() =>
      Hive.box<Map<dynamic, dynamic>>(HiveBoxes.history);

  static Box<Map<dynamic, dynamic>> chatBox() =>
      Hive.box<Map<dynamic, dynamic>>(HiveBoxes.chat);

  static Box<dynamic> preferencesBox() =>
      Hive.box<dynamic>(HiveBoxes.preferences);
}
