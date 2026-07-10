import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HanziPathApp builds without crashing', (tester) async {
    await tester.pumpWidget(const HanziPathApp());

    expect(find.byType(HanziPathApp), findsOneWidget);
    expect(find.text('早上好，学员'), findsOneWidget);
  });
}
