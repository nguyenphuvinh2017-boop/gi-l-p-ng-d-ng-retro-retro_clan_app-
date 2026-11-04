import 'package:flutter_test/flutter_test.dart';
import 'package:retro_clan_app/main.dart';

void main() {
  testWidgets('RetroClanApp basic smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RetroClanApp());
    expect(find.text('Retro'), findsWidgets);
  });
}
