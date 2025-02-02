import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dash;
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart' as credex;
import 'package:vimbisopay_app/domain/entities/pending_offer.dart' as pending;
import 'package:vimbisopay_app/infrastructure/services/password_service.dart';
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
      version: 10,
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
    if (oldVersion < 11) {
      try {
        await db.execute('DROP TABLE IF EXISTS ledger_entries_old');
        await db.execute('ALTER TABLE ledger_entries RENAME TO ledger_entries_old');
        
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

        await db.execute('''
          INSERT INTO ledger_entries 
          SELECT 
            credexID,
            accountId,
            timestamp,
            type,
            CAST(REPLACE(REPLACE(amount, '+', ''), ' ' || denomination, '') AS REAL) as amount,
            denomination,
            description,
            counterpartyAccountName,
            formattedAmount,
            accountName
          FROM ledger_entries_old
        ''');
        
        await db.execute('DROP TABLE ledger_entries_old');
        await db.execute('CREATE INDEX idx_ledger_timestamp ON ledger_entries(timestamp)');
        Logger.data('Successfully recreated ledger_entries table with proper amount format');
      } catch (e) {
        Logger.error('Error migrating ledger_entries table', e);
      }
    }

    if (oldVersion < 10) {
      // Add formattedAmount column to ledger_entries if it doesn't exist
      try {
        await db.execute('ALTER TABLE ledger_entries ADD COLUMN formattedAmount TEXT');
        Logger.data('Added formattedAmount column to ledger_entries table');
      } catch (e) {
        Logger.error('Error adding formattedAmount column: $e');
        // If error occurs, recreate the table with all columns
        await db.execute('DROP TABLE IF EXISTS ledger_entries_old');
        await db.execute('ALTER TABLE ledger_entries RENAME TO ledger_entries_old');
        
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
        
        // Copy data from old table, generating formattedAmount
        await db.execute('''
          INSERT INTO ledger_entries 
          SELECT 
            credexID,
            accountId,
            timestamp,
            type,
            amount,
            denomination,
            description,
            counterpartyAccountName,
            CASE 
              WHEN amount >= 0 THEN '+' || printf('%.2f', amount) || ' ' || denomination
              ELSE printf('%.2f', amount) || ' ' || denomination
            END as formattedAmount,
            accountName
          FROM ledger_entries_old
        ''');
        
        await db.execute('DROP TABLE ledger_entries_old');
        await db.execute('CREATE INDEX idx_ledger_timestamp ON ledger_entries(timestamp)');
        Logger.data('Successfully recreated ledger_entries table with formattedAmount column');
      }
    }
    
    if (oldVersion < 9) {
      // Previous migration code...
      await db.execute('CREATE INDEX idx_ledger_timestamp ON ledger_entries(timestamp)');
    }
    
    if (oldVersion < 8) {
      // Add new password columns
      await db.execute('ALTER TABLE users ADD COLUMN password_hash TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN password_salt TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN password_changed INTEGER');
      
      // Migrate existing passwords if any
      final users = await db.query('users', columns: ['memberId', 'password']);
      final passwordService = PasswordService();
      
      for (var user in users) {
        if (user['password'] != null) {
          final oldPassword = user['password'] as String;
          final ({String hash, String salt}) result = await passwordService.hashPassword(oldPassword);
          
          await db.update(
            'users',
            {
              'password_hash': result.hash,
              'password_salt': result.salt,
              'password_changed': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'memberId = ?',
            whereArgs: [user['memberId']],
          );
        }
      }
      
      // Remove old password column
      await db.execute('CREATE TABLE users_new(memberId TEXT PRIMARY KEY, phone TEXT NOT NULL, token TEXT NOT NULL, password_hash TEXT, password_salt TEXT, password_changed INTEGER)');
      await db.execute('INSERT INTO users_new(memberId, phone, token, password_hash, password_salt, password_changed) SELECT memberId, phone, token, password_hash, password_salt, password_changed FROM users');
      await db.execute('DROP TABLE users');
      await db.execute('ALTER TABLE users_new RENAME TO users');
    }
    
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE member_tiers ADD COLUMN firstname TEXT');
      await db.execute('ALTER TABLE member_tiers ADD COLUMN lastname TEXT');
      await db.execute('ALTER TABLE member_tiers ADD COLUMN defaultDenom TEXT');
    }
    
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE users ADD COLUMN password TEXT');
    }
    
    if (oldVersion < 5) {
      try {
        final List<Map<String, dynamic>> oldUsers = await db.query('users');
        await db.execute('DROP TABLE IF EXISTS users');
        await _createTables(db);
        
        for (var oldUser in oldUsers) {
          if (oldUser['dashboard'] != null) {
            Map<String, dynamic> dashboardMap;
            try {
              String dashboardStr = oldUser['dashboard'] as String;
              dashboardStr = dashboardStr.replaceAll('=', ':');
              dashboardMap = jsonDecode(dashboardStr) as Map<String, dynamic>;
            } catch (e) {
              print('Error parsing dashboard JSON: $e');
              continue;
            }
            
            try {
              final dashboard = dash.Dashboard.fromMap(dashboardMap);
              
              await db.insert('users', {
                'memberId': oldUser['memberId'],
                'phone': oldUser['phone'],
                'token': oldUser['token'],
                'password': oldUser['password'],
              });
              
              await db.insert('member_tiers', {
                'memberId': oldUser['memberId'],
                'low': dashboard.memberTier.low,
                'high': dashboard.memberTier.high,
                'firstname': dashboard.firstname,
                'lastname': dashboard.lastname,
                'defaultDenom': dashboard.defaultDenom,
              });
                        } catch (e) {
              print('Error migrating dashboard data: $e');
              continue;
            }
          }
        }
      } catch (e) {
        print('Database upgrade error: $e');
        throw Exception('Failed to upgrade database: $e');
      }
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE users(
        memberId TEXT PRIMARY KEY,
        phone TEXT NOT NULL,
        token TEXT NOT NULL,
        password_hash TEXT,
        password_salt TEXT,
        password_changed INTEGER
      )
    ''');
    
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

        // Insert user data
        await txn.insert('users', {
          'memberId': user.memberId,
          'phone': user.phone,
          'token': user.token,
          'password_hash': user.passwordHash,
          'password_salt': user.passwordSalt,
          'password_changed': user.passwordChanged?.millisecondsSinceEpoch,
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
          
          // No need to insert remaining_available as it's not used in new structure
          
          // Save all accounts
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
            
            Logger.data('Processing pending transactions for account ${account.accountName}');
            Logger.data('Raw pending in count: ${account.pendingInData.data.length ?? 0}');
            Logger.data('Raw pending out count: ${account.pendingOutData.data.length ?? 0}');
            
            // Process incoming transactions
            for (var pending in account.pendingInData.data ?? []) {
              if (!processedCredexIds.contains(pending.credexID)) {
                Logger.data('Saving incoming transaction: ${pending.credexID}');
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
            
            // Process outgoing transactions
            for (var pending in account.pendingOutData.data ?? []) {
              if (!processedCredexIds.contains(pending.credexID)) {
                Logger.data('Saving outgoing transaction: ${pending.credexID}');
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

            Logger.data('Saved ${processedCredexIds.length} unique transactions for account ${account.accountName}');
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
          
          Logger.data('Retrieved ${pendingTxs.length} total pending transactions from database');
          final pendingIn = pendingTxs.where((tx) => tx['direction'] == 'in').toList();
          final pendingOut = pendingTxs.where((tx) => tx['direction'] == 'out').toList();
          Logger.data('Split into ${pendingIn.length} incoming and ${pendingOut.length} outgoing transactions');

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
            memberHandle: null,
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
        passwordSalt: userData['password_salt'] as String?,
        passwordChanged: userData['password_changed'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(userData['password_changed'] as int)
            : null,
        dashboard: dashboardData,
      );
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

  Future<void> clearAllTables() async {
    Logger.data('Clearing all database tables');
    final Database db = await database;
    await db.transaction((txn) async {
      // Get all table names
      final tables = await txn.query(
        'sqlite_master',
        where: 'type = ?',
        whereArgs: ['table'],
        columns: ['name'],
      );
      
      // Drop each table except sqlite_sequence (system table)
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

  Future<void> updateAccountPendingTransactions(String accountId, List<pending.PendingOffer> pendingIn, List<pending.PendingOffer> pendingOut) async {
    final Database db = await database;
    await db.transaction((txn) async {
      // Delete existing pending transactions for this account
      await txn.delete(
        'pending_transactions',
        where: 'accountId = ?',
        whereArgs: [accountId],
      );
      
      // Insert new pending transactions
      for (var pending in pendingIn) {
        await txn.insert('pending_transactions', {
          'credexId': pending.credexID,
          'accountId': accountId,
          'amount': pending.formattedInitialAmount ?? '0',
          'counterpartyName': pending.counterpartyAccountName ?? '',
          'isSecured': pending.secured ? 1 : 0,
          'direction': 'in',
        });
      }
      
      for (var pending in pendingOut) {
        await txn.insert('pending_transactions', {
          'credexId': pending.credexID,
          'accountId': accountId,
          'amount': pending.formattedInitialAmount ?? '0',
          'counterpartyName': pending.counterpartyAccountName ?? '',
          'isSecured': pending.secured ? 1 : 0,
          'direction': 'out',
        });
      }
    });
  }

  Future<void> updatePendingTransactions(credex.CredexResponse response) async {
    Logger.data('Updating pending transactions from response');
    Logger.data('Response has ${response.data.dashboard.accounts.length} accounts');
    
    for (var account in response.data.dashboard.accounts) {
      Logger.data('Updating account ${account.accountName}:');
      Logger.data('- Pending in: ${account.pendingInData.length ?? 0}');
      Logger.data('- Pending out: ${account.pendingOutData.length ?? 0}');
      
      final Database db = await database;
      // Convert credex.PendingOffer to database records directly
      await db.transaction((txn) async {
        // Delete existing pending transactions for this account
        await txn.delete(
          'pending_transactions',
          where: 'accountId = ?',
          whereArgs: [account.accountID],
        );
        
        // Insert incoming transactions
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
        
        // Insert outgoing transactions
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
      // Handle amount conversion
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

  Future<(List<pending.PendingOffer>, List<pending.PendingOffer>)> getAllPendingTransactions() async {
    final Database db = await database;
    final List<Map<String, dynamic>> pendingTxs = await db.query('pending_transactions');
    
    final pendingIn = pendingTxs
        .where((tx) => tx['direction'] == 'in')
        .map((tx) => pending.PendingOffer(
              credexID: tx['credexId'] as String,
              formattedInitialAmount: tx['amount'] as String,
              counterpartyAccountName: tx['counterpartyName'] as String,
              secured: tx['isSecured'] == 1,
            ))
        .toList();
    
    final pendingOut = pendingTxs
        .where((tx) => tx['direction'] == 'out')
        .map((tx) => pending.PendingOffer(
              credexID: tx['credexId'] as String,
              formattedInitialAmount: tx['amount'] as String,
              counterpartyAccountName: tx['counterpartyName'] as String,
              secured: tx['isSecured'] == 1,
            ))
        .toList();
    
    return (pendingIn, pendingOut);
  }
}
