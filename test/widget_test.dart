import 'package:flutter_test/flutter_test.dart';

import 'package:voice_driver_mobile/app.dart';
import 'package:voice_driver_mobile/shared/strings/app_strings.dart';

void main() {
  testWidgets('Показывает экран списка задач', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartTaskAssistantApp());
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.taskListTitle), findsOneWidget);
    expect(
      find.text('Подготовить слайды к защите диплома'),
      findsOneWidget,
    );
  });
}
