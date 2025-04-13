// A simple script to clear the database
// This is a standalone script that doesn't require Flutter UI components

import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  // Initialize Flutter binding
  WidgetsFlutterBinding.ensureInitialized();
  print('Starting database wipe process...');
  
  try {
    // Get the database path
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'vimbisopay.db');
    
    // Check if the database exists
    if (await databaseExists(path)) {
      print('Found database at: $path');
      
      // Delete the database
      await deleteDatabase(path);
      print('✅ Database deleted successfully. Client state has been reset.');
    } else {
      print('Database not found at: $path');
      print('No action needed.');
    }
    
    // Exit with success code
    exit(0);
  } catch (e) {
    print('❌ Error wiping database: $e');
    // Exit with error code
    exit(1);
  }
}
