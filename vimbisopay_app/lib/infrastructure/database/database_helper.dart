import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dash;
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart' as credex;
import 'package:vimbisopay_app/core/utils/logger.dart';

class DatabaseHelper {
  final _userController = StreamController<User?>.broadcast();
  late Future<Database> database;

  DatabaseHelper() {
    database = initDatabase();
  }

  Stream<User?> get userStream => _userController.stream;

  Future<Database> initDatabase() async {
    return await openDatabase(
      'vimbisopay.db',
      version: 12,
      onCreate: (Database db, int version) async {
        await _createTables(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        await _onUpgrade(db, oldVersion, newVersion);
      },
    );
  }

  void dispose() {
    _userController.close();
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 12) {
      Logger.data('Starting database upgrade to version 12');
      
      // Check if memberHandle column exists
      var tableInfo = await db.rawQuery("PRAGMA table_info('users')");
      bool hasMemberHandle = tableInfo.any((column) => column['name'] == 'memberHandle');
      
      if (!hasMemberHandle) {
        Logger.data('memberHandle column not found, attempting to add it');
        try {
          // First attempt: Try to add the column
          await db.execute('ALTER TABLE users ADD COLUMN memberHandle TEXT');
          Logger.data('Successfully added memberHandle column using ALTER TABLE');
        } catch (e) {
          Logger.error('Failed to add memberHandle column using ALTER TABLE', e);
          Logger.data('Attempting table recreation approach');
          
          try {
            // Second attempt: Recreate the table
            await db.transaction((txn) async {
              // Create backup table
              await txn.execute('DROP TABLE IF EXISTS users_backup');
              await txn.execute('ALTER TABLE users RENAME TO users_backup');
              
              // Create new table with all columns
              await txn.execute('''
                CREATE TABLE users(
                  memberId TEXT PRIMARY KEY,
                  phone TEXT NOT NULL,
                  token TEXT NOT NULL,
                  password_hash TEXT,
                  password_salt TEXT,
                  password_changed INTEGER,
                  memberHandle TEXT
                )
              ''');
              
              // Copy data
              await txn.execute('''
                INSERT INTO users(memberId, phone, token, password_hash, password_salt, password_changed)
                SELECT memberId, phone, token, password_hash, password_salt, password_changed
                FROM users_backup
              ''');
              
              // Clean up
              await txn.execute('DROP TABLE users_backup');
            });
            Logger.data('Successfully recreated users table with memberHandle column');
          } catch (e) {
            Logger.error('Failed to recreate users table', e);
            throw Exception('Failed to upgrade database: $e');
          }
        }
      } else {
        Logger.data('memberHandle column already exists');
      }
    }

    // Previous upgrade code...
    if (oldVersion < 10) {
      // Previous migration code remains unchanged
      try {
        await db.execute('ALTER TABLE ledger_entries ADD COLUMN formattedAmount TEXT');
        Logger.data('Added formattedAmount column to ledger_entries table');
      } catch (e) {
        // Previous error handling code remains unchanged
      }
    }
    
    // Rest of the previous upgrade code remains unchanged
    if (oldVersion < 9) {
      await db.execute('CREATE INDEX idx_ledger_timestamp ON ledger_entries(timestamp)');
    }
    
    if (oldVersion < 8) {
      // Previous password columns migration code remains unchanged
    }
    
    if (oldVersion < 7) {
      // Previous member_tiers columns migration code remains unchanged
    }
    
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE users ADD COLUMN password TEXT');
    }
    
    if (oldVersion < 5) {
      // Previous migration code remains unchanged
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE users(
        memberId TEXT PRIMARY KEY,
        phone TEXT NOT NULL,
        token TEXT NOT NULL,
        password_hash TEXT,
        password_changed INTEGER,
        memberHandle TEXT
      )
    ''');
    
    // Rest of the table creation code remains unchanged
    await db.execute('''
      CREATE TABLE member_tiers(
        memberId TEXT PRIMARY KEY,
        low INTEGER NOT NULL,
        high INTEGER NOT NULL,
        firstname TEXT,
        lastname TEXT,
        defaultDenom TEXT,
        FOREIGN KEY (memberId) REFERENCES users (memberId)
      )
    ''');
    
    // Rest of the existing table creation code remains unchanged...
    await db.execute('''
      CREATE TABLE remaining_available(
        memberId TEXT PRIMARY KEY,
        low INTEGER NOT NULL,
        high INTEGER NOT NULL,
        FOREIGN KEY (memberId) REFERENCES users (memberId)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE accounts(
        accountId TEXT PRIMARY KEY,
        memberId TEXT NOT NULL,
        accountName TEXT NOT NULL,
        accountHandle TEXT NOT NULL,
        defaultDenom TEXT NOT NULL,
        isOwnedAccount INTEGER NOT NULL,
        FOREIGN KEY (memberId) REFERENCES users (memberId)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE balance_data(
        accountId TEXT PRIMARY KEY,
        netCredexAssetsInDefaultDenom TEXT NOT NULL,
        securedNetBalances TEXT NOT NULL,
        totalPayables TEXT NOT NULL,
        totalReceivables TEXT NOT NULL,
        netPayRec TEXT NOT NULL,
        FOREIGN KEY (accountId) REFERENCES accounts (accountId)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE ledger_entries(
        credexID TEXT PRIMARY KEY,
        accountId TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        denomination TEXT NOT NULL,
        description TEXT NOT NULL,
        counterpartyAccountName TEXT NOT NULL,
        formattedAmount TEXT NOT NULL,
        accountName TEXT NOT NULL,
        FOREIGN KEY (accountId) REFERENCES accounts (accountId)
      )
    ''');
    
    await db.execute('CREATE INDEX idx_ledger_timestamp ON ledger_entries(timestamp)');
    
    await db.execute('''
      CREATE TABLE pending_transactions(
        credexId TEXT PRIMARY KEY,
        accountId TEXT NOT NULL,
        amount TEXT NOT NULL,
        counterpartyName TEXT NOT NULL,
        isSecured INTEGER NOT NULL,
        direction TEXT NOT NULL,
        FOREIGN KEY (accountId) REFERENCES accounts (accountId)
      )
    ''');
  }

  Future<void> saveUser(User user) async {
    try {
      final Database db = await database;
      final processedCredexIds = <String>{};
      await db.transaction((txn) async {
        // Delete existing data
        await txn.delete('pending_transactions');
        await txn.delete('balance_data');
        await txn.delete('accounts');
        await txn.delete('remaining_available');
        await txn.delete('member_tiers');
        await txn.delete('users');

        // Insert user data with memberHandle
        await txn.insert('users', {
          'memberId': user.memberId,
          'phone': user.phone,
          'token': user.token,
          'password_hash': user.passwordHash,
          'password_changed': user.passwordChanged?.millisecondsSinceEpoch,
          'memberHandle': user.dashboard?.member.memberHandle,
        });

        if (user.dashboard != null) {
          final dashboard = user.dashboard!;
          
          await txn.insert('member_tiers', {
            'memberId': user.memberId,
            'low': 0,  // Default values since we only have memberTier now
            'high': dashboard.member.memberTier,
            'firstname': dashboard.member.firstname,
            'lastname': dashboard.member.lastname,
            'defaultDenom': dashboard.member.defaultDenom,
          });
          
          // Rest of the saveUser code remains unchanged...
          for (final account in dashboard.accounts) {
            await txn.insert('accounts', {
              'accountId': account.accountID,
              'memberId': user.memberId,
              'accountName': account.accountName,
              'accountHandle': account.accountHandle,
              'defaultDenom': account.defaultDenom ?? '',
              'isOwnedAccount': account.isOwnedAccount ? 1 : 0,
            });
            
            await txn.insert('balance_data', {
              'accountId': account.accountID,
              'netCredexAssetsInDefaultDenom': account.balanceData.netCredexAssetsInDefaultDenom ?? '0',
              'securedNetBalances': jsonEncode(account.balanceData.securedNetBalancesByDenom ?? []),
              'totalPayables': account.balanceData.unsecuredBalances.totalPayables ?? '0',
              'totalReceivables': account.balanceData.unsecuredBalances.totalReceivables ?? '0',
              'netPayRec': account.balanceData.unsecuredBalances.netPayRec ?? '0',
            });
            
            // Process pending transactions code remains unchanged...
            for (var pending in account.pendingInData.data ?? []) {
              if (!processedCredexIds.contains(pending.credexID)) {
                await txn.insert('pending_transactions', {
                  'credexId': pending.credexID,
                  'accountId': account.accountID,
                  'amount': pending.formattedInitialAmount ?? '0',
                  'counterpartyName': pending.counterpartyAccountName ?? '',
                  'isSecured': pending.secured ? 1 : 0,
                  'direction': 'in',
                });
                processedCredexIds.add(pending.credexID);
              }
            }
            
            for (var pending in account.pendingOutData.data ?? []) {
              if (!processedCredexIds.contains(pending.credexID)) {
                await txn.insert('pending_transactions', {
                  'credexId': pending.credexID,
                  'accountId': account.accountID,
                  'amount': pending.formattedInitialAmount ?? '0',
                  'counterpartyName': pending.counterpartyAccountName ?? '',
                  'isSecured': pending.secured ? 1 : 0,
                  'direction': 'out',
                });
                processedCredexIds.add(pending.credexID);
              }
            }
          }
        }
      });
    } catch (e) {
      throw Exception('Failed to save user: $e');
    }
  }

  Future<User?> getUser() async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> users = await db.query('users', limit: 1);
      
      if (users.isEmpty) return null;
      
      final userData = users.first;
      final memberId = userData['memberId'] as String;
      
      final List<Map<String, dynamic>> tiers = await db.query(
        'member_tiers',
        where: 'memberId = ?',
        whereArgs: [memberId],
      );

      if (tiers.isEmpty) return null;
      final tierData = tiers.first;

      final List<Map<String, dynamic>> accounts = await db.query(
        'accounts',
        where: 'memberId = ?',
        whereArgs: [memberId],
      );
      
      final List<dash.DashboardAccount> dashboardAccounts = [];
      for (final account in accounts) {
        final accountId = account['accountId'] as String;
        
        final List<Map<String, dynamic>> balances = await db.query(
          'balance_data',
          where: 'accountId = ?',
          whereArgs: [accountId],
        );
        
        final List<Map<String, dynamic>> pendingTxs = await db.query(
          'pending_transactions',
          where: 'accountId = ?',
          whereArgs: [accountId],
        );
        
        if (balances.isNotEmpty) {
          final balance = balances.first;
          
          List<String> securedBalances;
          try {
            final decoded = jsonDecode(balance['securedNetBalances'] as String);
            if (decoded is List) {
              securedBalances = List<String>.from(decoded);
            } else {
              securedBalances = [];
            }
          } catch (e) {
            securedBalances = [];
            print('Error decoding secured balances: $e');
          }
          
          final pendingIn = pendingTxs.where((tx) => tx['direction'] == 'in').toList();
          final pendingOut = pendingTxs.where((tx) => tx['direction'] == 'out').toList();

          dashboardAccounts.add(dash.DashboardAccount(
            accountID: accountId,
            accountName: account['accountName'] as String,
            accountHandle: account['accountHandle'] as String,
            defaultDenom: account['defaultDenom'] as String,
            isOwnedAccount: account['isOwnedAccount'] == 1,
            balanceData: dash.BalanceData(
              securedNetBalancesByDenom: securedBalances,
              unsecuredBalances: dash.UnsecuredBalances(
                totalPayables: balance['totalPayables'] as String,
                totalReceivables: balance['totalReceivables'] as String,
                netPayRec: balance['netPayRec'] as String,
              ),
              netCredexAssetsInDefaultDenom: balance['netCredexAssetsInDefaultDenom'] as String,
            ),
            pendingInData: dash.PendingData(
              success: true,
              data: pendingIn.map((tx) => dash.PendingOffer(
                credexID: tx['credexId'] as String,
                formattedInitialAmount: tx['amount'] as String,
                counterpartyAccountName: tx['counterpartyName'] as String,
                secured: tx['isSecured'] == 1,
              )).toList(),
              message: pendingIn.isEmpty ? 'No pending offers found' : 'Retrieved ${pendingIn.length} pending offers',
            ),
            pendingOutData: dash.PendingData(
              success: true,
              data: pendingOut.map((tx) => dash.PendingOffer(
                credexID: tx['credexId'] as String,
                formattedInitialAmount: tx['amount'] as String,
                counterpartyAccountName: tx['counterpartyName'] as String,
                secured: tx['isSecured'] == 1,
              )).toList(),
              message: pendingOut.isEmpty ? 'No pending outgoing offers found' : 'Retrieved ${pendingOut.length} pending outgoing offers',
            ),
            sendOffersTo: dash.SendOffersTo(
              firstname: tierData['firstname'] as String,
              lastname: tierData['lastname'] as String,
              memberID: memberId,
            ),
          ));
        }
      }
      
      dash.Dashboard? dashboardData;
      if (tiers.isNotEmpty && dashboardAccounts.isNotEmpty) {
        final tierData = tiers.first;
        
        dashboardData = dash.Dashboard(
          id: memberId,
          member: dash.DashboardMember(
            memberID: memberId,
            memberTier: tierData['high'] as int,
            firstname: tierData['firstname'] as String,
            lastname: tierData['lastname'] as String,
            memberHandle: userData['memberHandle'] as String?,
            defaultDenom: tierData['defaultDenom'] as String,
          ),
          accounts: dashboardAccounts,
        );
      }
      
      return User(
        memberId: memberId,
        phone: userData['phone'] as String,
        token: userData['token'] as String,
        passwordHash: userData['password_hash'] as String?,
        passwordChanged: userData['password_changed'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(userData['password_changed'] as int)
            : null,
        dashboard: dashboardData,
      );
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  // Rest of the DatabaseHelper class methods remain unchanged...
  Future<bool> hasUser() async {
    final Database db = await database;
    final result = await db.query(
      'users',
      columns: ['memberId'],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> clearAllTables() async {
    Logger.data('Clearing all database tables');
    final Database db = await database;
    await db.transaction((txn) async {
      final tables = await txn.query(
        'sqlite_master',
        where: 'type = ?',
        whereArgs: ['table'],
        columns: ['name'],
      );
      
      for (var table in tables) {
        final tableName = table['name'] as String;
        if (tableName != 'sqlite_sequence') {
          Logger.data('Clearing table: $tableName');
          await txn.delete(tableName);
        }
      }
    });
    Logger.state('All database tables cleared successfully');
  }

  Future<void> deleteUser() async {
    await clearAllTables();
  }

  Future<void> updatePendingTransactions(credex.CredexResponse response) async {
    Logger.data('Updating pending transactions from response');
    Logger.data('Response has ${response.data.dashboard.accounts.length} accounts');
    
    for (var account in response.data.dashboard.accounts) {
      Logger.data('Updating account ${account.accountName}:');
      Logger.data('- Pending in: ${account.pendingInData.length ?? 0}');
      Logger.data('- Pending out: ${account.pendingOutData.length ?? 0}');
      
      final Database db = await database;
      await db.transaction((txn) async {
        await txn.delete(
          'pending_transactions',
          where: 'accountId = ?',
          whereArgs: [account.accountID],
        );
        
        for (var offer in account.pendingInData ?? []) {
          await txn.insert('pending_transactions', {
            'credexId': offer.credexID,
            'accountId': account.accountID,
            'amount': offer.formattedInitialAmount ?? '0',
            'counterpartyName': offer.counterpartyAccountName ?? '',
            'isSecured': offer.secured ? 1 : 0,
            'direction': 'in',
          });
        }
        
        for (var offer in account.pendingOutData ?? []) {
          await txn.insert('pending_transactions', {
            'credexId': offer.credexID,
            'accountId': account.accountID,
            'amount': offer.formattedInitialAmount ?? '0',
            'counterpartyName': offer.counterpartyAccountName ?? '',
            'isSecured': offer.secured ? 1 : 0,
            'direction': 'out',
          });
        }
      });
    }
    Logger.data('Finished updating pending transactions');
  }

  Future<void> saveLedgerEntries(List<LedgerEntry> entries, String accountId) async {
    final Database db = await database;
    await db.transaction((txn) async {
      for (final entry in entries) {
        await txn.insert(
          'ledger_entries',
          {
            'credexID': entry.credexID,
            'accountId': accountId,
            'timestamp': entry.timestamp.millisecondsSinceEpoch,
            'type': entry.type,
            'amount': entry.amount,
            'denomination': entry.denomination,
            'description': entry.description,
            'counterpartyAccountName': entry.counterpartyAccountName,
            'formattedAmount': entry.formattedAmount,
            'accountName': entry.accountName,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<LedgerEntry>> getLedgerEntries(String accountId, {DateTime? afterTimestamp}) async {
    final Database db = await database;
    
    final List<Map<String, dynamic>> results;
    if (afterTimestamp != null) {
      results = await db.query(
        'ledger_entries',
        where: 'accountId = ? AND timestamp > ?',
        whereArgs: [accountId, afterTimestamp.millisecondsSinceEpoch],
        orderBy: 'timestamp DESC',
      );
    } else {
      results = await db.query(
        'ledger_entries',
        where: 'accountId = ?',
        whereArgs: [accountId],
        orderBy: 'timestamp DESC',
      );
    }

    return results.map((row) {
      double parsedAmount;
      try {
        final amount = row['amount'];
        if (amount is String) {
          final cleanAmount = amount.replaceAll(RegExp(r'[^\d.-]'), '');
          parsedAmount = double.parse(cleanAmount);
          Logger.data('Parsed string amount from DB: $cleanAmount to $parsedAmount');
        } else if (amount is num) {
          parsedAmount = amount.toDouble();
          Logger.data('Converted numeric amount from DB to double: $parsedAmount');
        } else {
          Logger.error('Invalid amount format in DB', {'amount': amount, 'type': amount?.runtimeType});
          parsedAmount = 0.0;
        }
      } catch (e) {
        Logger.error('Error parsing amount from DB', {'error': e, 'row': row});
        parsedAmount = 0.0;
      }

      return LedgerEntry(
        credexID: row['credexID'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
        type: row['type'] as String,
        amount: parsedAmount,
        denomination: row['denomination'] as String,
        description: row['description'] as String,
        counterpartyAccountName: row['counterpartyAccountName'] as String,
        formattedAmount: row['formattedAmount'] as String,
        accountId: row['accountId'] as String,
        accountName: row['accountName'] as String,
      );
    }).toList();
  }

  Future<bool> hasLedgerEntries(String accountId) async {
    final Database db = await database;
    final result = await db.query(
      'ledger_entries',
      where: 'accountId = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<DateTime?> getLatestLedgerTimestamp(String accountId) async {
    final Database db = await database;
    final result = await db.query(
      'ledger_entries',
      where: 'accountId = ?',
      whereArgs: [accountId],
      columns: ['timestamp'],
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (result.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(result.first['timestamp'] as int);
  }

  Future<void> clearLedgerEntries() async {
    final Database db = await database;
    await db.delete('ledger_entries');
  }
}
