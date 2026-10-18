import 'dart:io';
import 'package:multisynk/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A controllable clock shared by a test (milliseconds).
class TestClock {
  int now;
  TestClock([this.now = 1000]);
  int call() => now;
  void advance([int ms = 1000]) => now += ms;
}

Directory? _tmp;

String tempDbPath(String name) {
  sqfliteFfiInit();
  _tmp ??= Directory.systemTemp.createTempSync('multisynk_test_');
  final file = File('${_tmp!.path}${Platform.pathSeparator}$name-${DateTime.now().microsecondsSinceEpoch}.db');
  if (file.existsSync()) file.deleteSync();
  return file.path;
}

DatabaseHelper newTestDb(String name, TestClock clock) {
  sqfliteFfiInit();
  return DatabaseHelper.forTesting(factory: databaseFactoryFfi, path: tempDbPath(name), clock: clock.call);
}
