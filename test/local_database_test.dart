import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/local_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('database initializes and starts empty', () async {
    await LocalDatabase.resetForTesting();
    final db = await LocalDatabase.ensureInitialized();

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='app_data'",
    );

    expect(tables, hasLength(1));

    final rows = await db.query('app_data');
    expect(rows, isEmpty);
  });
}
