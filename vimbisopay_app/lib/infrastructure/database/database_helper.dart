import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart' as credex;

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
      version: 7,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
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
              final dashboard = Dashboard.fromMap(dashboardMap);
              
              await db.insert('users', {
                'memberId': oldUser['memberId'],
                'phone': oldUser['phone'],
                'token': oldUser['token'],
                'password': oldUser['password'],
              });
              
              if (dashboard.memberTier != null) {
                await db.insert('member_tiers', {
                  'memberId': oldUser['memberId'],
                  'low': dashboard.memberTier.low,
                  'high': dashboard.memberTier.high,
                  'firstname': dashboard.firstname,
                  'lastname': dashboard.lastname,
                  'defaultDenom': dashboard.defaultDenom,
                });
              }
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
        password TEXT
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
      CREATE TABLE auth_users(
        accountId TEXT NOT NULL,
        memberId TEXT NOT NULL,
        firstname TEXT NOT NULL,
        lastname TEXT NOT NULL,
        PRIMARY KEY (accountId, memberId),
        FOREIGN KEY (accountId) REFERENCES accounts (accountId)
      )
    ''');
    
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
      await db.transaction((txn) async {
        // Delete existing data
        await txn.delete('pending_transactions');
        await txn.delete('auth_users');
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
          'password': user.password,
        });

        if (user.dashboard != null) {
          final dashboard = user.dashboard!;
          
          await txn.insert('member_tiers', {
            'memberId': user.memberId,
            'low': dashboard.memberTier.low,
            'high': dashboard.memberTier.high,
            'firstname': dashboard.firstname,
            'lastname': dashboard.lastname,
            'defaultDenom': dashboard.defaultDenom,
          });
          
          await txn.insert('remaining_available', {
            'memberId': user.memberId,
            'low': dashboard.remainingAvailableUSD.low,
            'high': dashboard.remainingAvailableUSD.high,
          });
          
          // Track processed credexIds to avoid duplicates
          final processedCredexIds = <String>{};
          
          for (var account in dashboard.accounts) {
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
              'totalPayables': account.balanceData.unsecuredBalances?.totalPayables ?? '0',
              'totalReceivables': account.balanceData.unsecuredBalances?.totalReceivables ?? '0',
              'netPayRec': account.balanceData.unsecuredBalances?.netPayRec ?? '0',
            });
            
            for (var auth in account.authFor) {
              await txn.insert('auth_users', {
                'accountId': account.accountID,
                'memberId': auth.memberID,
                'firstname': auth.firstname ?? '',
                'lastname': auth.lastname ?? '',
              });
            }
            
            // Process incoming transactions
            for (var pending in account.pendingInData?.data ?? []) {
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
            
            // Process outgoing transactions
            for (var pending in account.pendingOutData?.data ?? []) {
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
      
      final List<Map<String, dynamic>> remaining = await db.query(
        'remaining_available',
        where: 'memberId = ?',
        whereArgs: [memberId],
      );
      
      final List<Map<String, dynamic>> accounts = await db.query(
        'accounts',
        where: 'memberId = ?',
        whereArgs: [memberId],
      );
      
      final List<DashboardAccount> dashboardAccounts = [];
      
      for (var account in accounts) {
        final accountId = account['accountId'] as String;
        
        final List<Map<String, dynamic>> balances = await db.query(
          'balance_data',
          where: 'accountId = ?',
          whereArgs: [accountId],
        );
        
        final List<Map<String, dynamic>> authUsers = await db.query(
          'auth_users',
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

          final primaryAuth = authUsers.firstWhere(
            (auth) => auth['memberId'] == memberId,
            orElse: () => authUsers.first,
          );
          
          dashboardAccounts.add(DashboardAccount(
            accountID: accountId,
            accountName: account['accountName'] as String,
            accountHandle: account['accountHandle'] as String,
            defaultDenom: account['defaultDenom'] as String,
            isOwnedAccount: account['isOwnedAccount'] == 1,
            authFor: authUsers.map((auth) => AuthUser(
              firstname: auth['firstname'] as String,
              lastname: auth['lastname'] as String,
              memberID: auth['memberId'] as String,
            )).toList(),
            balanceData: BalanceData(
              securedNetBalancesByDenom: securedBalances,
              unsecuredBalances: UnsecuredBalances(
                totalPayables: balance['totalPayables'] as String,
                totalReceivables: balance['totalReceivables'] as String,
                netPayRec: balance['netPayRec'] as String,
              ),
              netCredexAssetsInDefaultDenom: balance['netCredexAssetsInDefaultDenom'] as String,
            ),
            pendingInData: credex.PendingData(
              success: true,
              data: pendingIn.map((tx) => credex.PendingOffer(
                credexID: tx['credexId'] as String,
                formattedInitialAmount: tx['amount'] as String,
                counterpartyAccountName: tx['counterpartyName'] as String,
                secured: tx['isSecured'] == 1,
              )).toList(),
              message: pendingIn.isEmpty ? "No pending offers found" : "Retrieved ${pendingIn.length} pending offers",
            ),
            pendingOutData: credex.PendingData(
              success: true,
              data: pendingOut.map((tx) => credex.PendingOffer(
                credexID: tx['credexId'] as String,
                formattedInitialAmount: tx['amount'] as String,
                counterpartyAccountName: tx['counterpartyName'] as String,
                secured: tx['isSecured'] == 1,
              )).toList(),
              message: pendingOut.isEmpty ? "No pending outgoing offers found" : "Retrieved ${pendingOut.length} pending outgoing offers",
            ),
            sendOffersTo: AuthUser(
              firstname: primaryAuth['firstname'] as String,
              lastname: primaryAuth['lastname'] as String,
              memberID: primaryAuth['memberId'] as String,
            ),
          ));
        }
      }
      
      Dashboard? dashboard;
      if (tiers.isNotEmpty && remaining.isNotEmpty) {
        final tierData = tiers.first;
        dashboard = Dashboard(
          id: memberId,
          memberTier: MemberTier(
            low: tierData['low'] as int,
            high: tierData['high'] as int,
          ),
          remainingAvailableUSD: RemainingAvailable(
            low: remaining.first['low'] as int,
            high: remaining.first['high'] as int,
          ),
          accounts: dashboardAccounts,
          firstname: tierData['firstname'] as String?,
          lastname: tierData['lastname'] as String?,
          defaultDenom: tierData['defaultDenom'] as String?,
        );
      }
      
      return User(
        memberId: memberId,
        phone: userData['phone'] as String,
        token: userData['token'] as String,
        password: userData['password'] as String?,
        dashboard: dashboard,
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

  Future<void> deleteUser() async {
    final Database db = await database;
    await db.transaction((txn) async {
      await txn.delete('pending_transactions');
      await txn.delete('auth_users');
      await txn.delete('balance_data');
      await txn.delete('accounts');
      await txn.delete('remaining_available');
      await txn.delete('member_tiers');
      await txn.delete('users');
    });
  }
}
