import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// The browser has no native SQLite, `sqflite_common_ffi_web` runs SQLite
/// through WebAssembly instead.
///
/// The `sqlite3.wasm` file in the `web` folder is the engine that is loaded
/// here, it is downloaded by the browser when the app starts.
Future<void> setupDatabaseFactory() async {
  databaseFactory = databaseFactoryFfiWeb;
}