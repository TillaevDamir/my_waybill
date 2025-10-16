// database_helper.dart

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const _databaseName = "WaybillApp.db";
  static const _databaseVersion = 5;

  static const table = 'user_data';

  static const columnId = '_id';
  static const columnPhone = 'phone';
  static const columnPassword = 'password';
  static const columnFullName = 'fullName';
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
            $columnFullName TEXT,
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
      try {
        final List<Map<String, dynamic>> oldData = await db.query(table);
        await db.execute('DROP TABLE IF EXISTS $table');
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
      } catch (e) {
        await _onCreate(db, newVersion);
      }
    }

    if (oldVersion < 4) {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnFullName TEXT');
    }
  }

  // --- METHODS ---

  Future<void> saveUserData({
    String? phone,
    String? password,
    String? fullName,
    String? requestId,
    int? requestTimestamp,
  }) async {
    final db = await instance.database;
    final existingData = await getUserData();

    final Map<String, dynamic> dataToSave = {
      if (phone != null) columnPhone: phone,
      if (password != null) columnPassword: password,
      if (fullName != null) columnFullName: fullName,
      if (requestId != null) columnRequestId: requestId,
      columnRequestTimestamp: requestTimestamp, //if (requestTimestamp != null) columnRequestTimestamp: requestTimestamp
    };

    final updateData = Map<String, dynamic>.from(dataToSave)
      ..removeWhere((key, value) => value == null && key != columnRequestTimestamp);

    if (updateData.isEmpty) return;

    if (existingData != null) {
      await db.update(table, updateData, where: '$columnId = ?', whereArgs: [existingData[columnId]]);
    } else {
      await db.insert(table, dataToSave);
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
      columnFullName: null,
    });
  }

  Future<void> clearAllUserData() async {
    final db = await instance.database;
    await db.delete(table);
  }

  Future<void> clearWaybillRequestData() async {
    final db = await instance.database;
    await db.update(
      table,
      {columnRequestId: null, columnRequestTimestamp: null},
    );
  }
}

