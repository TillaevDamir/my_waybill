// database_helper.dart

import 'package:path/path.dart';
// ИСПРАВЛЕННЫЙ ИМПОРТ
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const _databaseName = "WaybillApp.db";
  static const _databaseVersion = 3;

  static const table = 'user_data';

  static const columnId = '_id';
  static const columnPhone = 'phone';
  static const columnPassword = 'password';
  static const columnRequestId = 'request_id';
  static const columnRequestTimestamp = 'request_timestamp';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(path,
        version: _databaseVersion, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
          CREATE TABLE $table (
            $columnId INTEGER PRIMARY KEY,
            $columnPhone TEXT,
            $columnPassword TEXT,
            $columnRequestId TEXT,
            $columnRequestTimestamp INTEGER
          )
          ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnRequestId TEXT');
      await db.execute('ALTER TABLE $table ADD COLUMN $columnRequestTimestamp INTEGER');
    }
    if (oldVersion < 3) {
      final List<Map<String, dynamic>> oldData = await db.query(table);
      await db.execute('DROP TABLE $table');
      await _onCreate(db, newVersion);
      for (final row in oldData) {
        final newRow = {
          columnPhone: row[columnPhone],
          columnPassword: row[columnPassword],
          columnRequestId: row[columnRequestId],
          columnRequestTimestamp: row[columnRequestTimestamp],
        };
        await db.insert(table, newRow);
      }
    }
  }

  // --- METHODS ---

  Future<void> saveUserData({
    String? phone,
    String? password,
    String? requestId,
    int? requestTimestamp,
  }) async {
    final db = await instance.database;
    final existingData = await getUserData();

    final Map<String, dynamic> dataToSave = {
      if (phone != null) columnPhone: phone,
      if (password != null) columnPassword: password,
      if (requestId != null) columnRequestId: requestId,
      if (requestTimestamp != null) columnRequestTimestamp: requestTimestamp,
    };

    if (dataToSave.isEmpty) return;

    if (existingData != null) {
      await db.update(table, dataToSave, where: '$columnId = ?', whereArgs: [existingData[columnId]]);
    } else {
      final allData = {
        columnPhone: phone,
        columnPassword: password,
        columnRequestId: requestId,
        columnRequestTimestamp: requestTimestamp,
      };
      await db.insert(table, allData);
    }
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final db = await instance.database;
    final maps = await db.query(table, limit: 1);
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<void> clearAuthCredentials() async {
    final db = await instance.database;
    await db.update(table, {
      columnPhone: null,
      columnPassword: null,
    });
  }

  Future<void> clearAllUserData() async {
    final db = await instance.database;
    await db.delete(table);
  }

  // ИСПРАВЛЕННЫЙ МЕТОД
  // Теперь он НЕ вызывается после успешной загрузки файла,
  // а только при явном завершении смены.
  Future<void> clearWaybillRequestData() async {
    final db = await instance.database;
    await db.update(
      table,
      {columnRequestId: null, columnRequestTimestamp: null},
    );
  }
}

