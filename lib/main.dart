import 'package:flutter/material.dart';

import 'app.dart';
import 'core/storage/hive_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveStorage.ensureInitialized();
  runApp(const SmartTaskAssistantApp());
}
