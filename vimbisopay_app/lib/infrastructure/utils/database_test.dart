import 'package:flutter/material.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/infrastructure/utils/database_checker.dart';

/// A simple widget to test the database status
class DatabaseTestScreen extends StatefulWidget {
  const DatabaseTestScreen({super.key});

  @override
  State<DatabaseTestScreen> createState() => _DatabaseTestScreenState();
}

class _DatabaseTestScreenState extends State<DatabaseTestScreen> {
  String _status = 'Checking database...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkDatabase();
  }

  Future<void> _checkDatabase() async {
    try {
      setState(() {
        _isLoading = true;
        _status = 'Checking database...';
      });

      // Check database status
      await DatabaseChecker.checkDatabaseStatus();

      // Check if the cached_stores table exists
      final DatabaseHelper databaseHelper = ServiceLocator.databaseHelper;
      final db = await databaseHelper.database;
      
      final tableCheck = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='cached_stores'");
      final tableExists = tableCheck.isNotEmpty;
      
      String status = 'Database check completed.\n\n';
      status += 'cached_stores table exists: $tableExists\n';
      
      if (tableExists) {
        // Check if there are any records in the table
        final countCheck = await db.rawQuery('SELECT COUNT(*) as count FROM cached_stores');
        final count = countCheck.first['count'] as int? ?? 0;
        status += 'Records in cached_stores table: $count\n';
        
        if (count > 0) {
          // Get the records
          final records = await db.query('cached_stores');
          status += '\nRecords:\n';
          for (final record in records) {
            final storeId = record['storeId'] as String;
            final vendorJson = record['vendor'] as String;
            final productsJson = record['products'] as String;
            final lastUpdated = DateTime.fromMillisecondsSinceEpoch(record['lastUpdated'] as int);
            
            status += '- Store ID: $storeId\n';
            status += '  Last updated: $lastUpdated\n';
            status += '  Vendor JSON length: ${vendorJson.length}\n';
            status += '  Products JSON length: ${productsJson.length}\n\n';
          }
        }
      }
      
      setState(() {
        _isLoading = false;
        _status = status;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error checking database: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    _status,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _checkDatabase,
                child: const Text('Refresh'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
