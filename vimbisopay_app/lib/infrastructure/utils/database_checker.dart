import 'package:sqflite/sqflite.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';

/// Utility class to check the status of the database
class DatabaseChecker {
  /// Checks the status of the database and logs information about it
  static Future<void> checkDatabaseStatus() async {
    try {
      Logger.data('[DB_CHECK] Starting database status check');
      
      final DatabaseHelper databaseHelper = ServiceLocator.databaseHelper;
      final Database db = await databaseHelper.database;
      
      // Check if the database is open
      final isOpen = db.isOpen;
      Logger.data('[DB_CHECK] Database is ${isOpen ? 'open' : 'closed'}');
      
      // Get the database path
      final path = db.path;
      Logger.data('[DB_CHECK] Database path: $path');
      
      // Get the database version
      final version = await db.getVersion();
      Logger.data('[DB_CHECK] Database version: $version');
      
      // Get all tables in the database
      final tables = await db.query(
        'sqlite_master',
        where: 'type = ?',
        whereArgs: ['table'],
        columns: ['name'],
      );
      
      Logger.data('[DB_CHECK] Tables in database: ${tables.length}');
      for (final table in tables) {
        final tableName = table['name'] as String;
        Logger.data('[DB_CHECK] Table: $tableName');
        
        // Get the number of records in each table
        final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
        final count = Sqflite.firstIntValue(countResult) ?? 0;
        Logger.data('[DB_CHECK] Records in $tableName: $count');
        
        // If it's the cached_stores table, get more details
        if (tableName == 'cached_stores' && count > 0) {
          final storeRecords = await db.query('cached_stores');
          for (final record in storeRecords) {
            final storeId = record['storeId'] as String;
            final vendorJson = record['vendor'] as String;
            final productsJson = record['products'] as String;
            final lastUpdated = DateTime.fromMillisecondsSinceEpoch(record['lastUpdated'] as int);
            
            Logger.data('[DB_CHECK] Store record - ID: $storeId, Last updated: $lastUpdated');
            Logger.data('[DB_CHECK] Vendor JSON length: ${vendorJson.length}, Products JSON length: ${productsJson.length}');
          }
        }
      }
      
      Logger.data('[DB_CHECK] Database status check completed successfully');
    } catch (e, stackTrace) {
      Logger.error('[DB_CHECK] Error checking database status', e);
      Logger.error('[DB_CHECK] Stack trace: $stackTrace');
    }
  }
}
