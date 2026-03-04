// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_counter_local/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const CalorieCounterApp());
    expect(find.textContaining('Today'), findsOneWidget);
  });
}