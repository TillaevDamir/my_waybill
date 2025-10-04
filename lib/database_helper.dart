import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:typed_data';

class DatabaseHelper {
  static const _databaseName = "WaybillApp.db";
  static const _databaseVersion = 2; // <-- Version incremented for migration

  static const table = 'user_data';

  static const columnId = '_id';
  static const columnPhone = 'phone';
  static const columnPassword = 'password';
  static const columnRequestId = 'request_id'; // <-- New field
  static const columnRequestTimestamp = 'request_timestamp'; // <-- New field

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
            $columnPhone TEXT NOT NULL,
            $columnPassword TEXT NOT NULL,
            $columnRequestId TEXT,
            $columnRequestTimestamp INTEGER
          )
          ''');
  }

  // Method to update DB schema when version is incremented
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnRequestId TEXT');
      await db.execute('ALTER TABLE $table ADD COLUMN $columnRequestTimestamp INTEGER');
    }
  }

  // --- METHODS ---

  // Universal method to save data
  Future<void> saveUserData({
    required String phone,
    required String password,
    String? requestId,
    int? requestTimestamp,
  }) async {
    final db = await instance.database;
    await db.delete(table); // Clear old data
    await db.insert(table, {
      columnPhone: phone,
      columnPassword: password,
      columnRequestId: requestId,
      columnRequestTimestamp: requestTimestamp,
    });
  }


  // Get all user data
  Future<Map<String, dynamic>?> getUserData() async {
    final db = await instance.database;
    final maps = await db.query(table, limit: 1);
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // Clear all user data (on logout)
  Future<void> clearAllUserData() async {
    final db = await instance.database;
    await db.delete(table);
  }

  // Clear only the waybill request data
  Future<void> clearWaybillRequestData() async {
    final db = await instance.database;
    await db.update(
      table,
      {columnRequestId: null, columnRequestTimestamp: null},
    );
  }
}
