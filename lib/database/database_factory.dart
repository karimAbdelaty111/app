import 'database_factory_native.dart'
    if (dart.library.js_interop) 'database_factory_web.dart' as platform;

/// Prepares the `databaseFactory` of `sqflite` before the database is opened.
///
/// Android, iOS, desktop and the test runner already ship a native SQLite, so
/// the regular implementation is used there. The browser has no native SQLite
/// and needs a different one, which is why this small indirection exists.
Future<void> setupDatabaseFactory() => platform.setupDatabaseFactory();