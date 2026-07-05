import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';

void main() {
  testWidgets('dashboard renders core learning content', (tester) async {
    await tester.pumpWidget(const HanziPathApp());

    expect(find.text('早上好，学员'), findsOneWidget);
    expect(find.text('Family & Relationships'), findsNWidgets(2));
    expect(find.text('WEEKLY XP'), findsOneWidget);
  });
}
