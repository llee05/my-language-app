import 'dart:async';

import 'package:mylanguageapp/local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LocalDatabase.useDatabasePathForTesting(inMemoryDatabasePath);
  await testMain();
}
