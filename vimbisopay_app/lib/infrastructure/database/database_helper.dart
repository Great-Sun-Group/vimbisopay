import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), 'vimbisopay.db');
    return await openDatabase(
      path,
      version: 3, // Increment version to trigger upgrade
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Handle upgrade to version 3 (adding tier column)
      await db.execute('ALTER TABLE users ADD COLUMN tier TEXT NOT NULL DEFAULT "free"');
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE users(
        memberId TEXT PRIMARY KEY,
        phone TEXT NOT NULL,
        token TEXT NOT NULL,
        tier TEXT NOT NULL DEFAULT "free"
      )
    ''');
  }

  Future<void> saveUser(User user) async {
    try {
      final Database db = await database;

      // Clear any existing user first since we only want one user
      await db.delete('users');

      // Save the new user
      await db.insert(
        'users',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw Exception('Failed to save user: $e');
    }
  }

  Future<User?> getUser() async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> maps = await db.query('users', limit: 1);

      if (maps.isEmpty) return null;

      return User.fromMap(maps.first);
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  Future<bool> hasUser() async {
    final Database db = await database;
    final result = await db.query(
      'users',
      columns: ['memberId'],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> deleteUser() async {
    final Database db = await database;
    await db.delete('users');
  }
}
