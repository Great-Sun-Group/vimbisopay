import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vimbisopay_app/application/usecases/accept_credex_bulk.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' show Dashboard, DashboardAccount, PendingData, PendingOffer;
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_event.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final AcceptCredexBulk acceptCredexBulk;
  final AccountRepository accountRepository;
  DatabaseHelper _databaseHelper = DatabaseHelper();
  
  // For testing
  set databaseHelper(DatabaseHelper helper) => _databaseHelper = helper;
  final Set<String> _processedCredexIds = {};
  bool _isInitialized = false;

  HomeBloc({
    required this.acceptCredexBulk,
    required this.accountRepository,
  }) : super(const HomeState(status: HomeStatus.initial)) {
    Logger.lifecycle('HomeBloc initialized');
    on<HomePageChanged>(_onPageChanged);
    on<HomeDataLoaded>(_onDataLoaded);
    on<HomeLedgerLoaded>(_onLedgerLoaded);
    on<HomeErrorOccurred>(_onErrorOccurred);
    on<HomeLoadStarted>(_onLoadStarted);
    on<HomeRefreshStarted>(_onRefreshStarted);
    on<HomeLoadMoreStarted>(_onLoadMoreStarted);
    on<HomeAcceptCredexBulkStarted>(_onAcceptCredexBulkStarted);
    on<HomeAcceptCredexBulkCompleted>(_onAcceptCredexBulkCompleted);
    on<HomeCancelCredexStarted>(_onCancelCredexStarted);
    on<HomeCancelCredexCompleted>(_onCancelCredexCompleted);
    on<HomeFetchPendingTransactions>(_onFetchPendingTransactions);
    on<HomeRegisterNotificationToken>(_onRegisterNotificationToken);
    on<HomeSearchStarted>(_onSearchStarted);
    on<HomeLoadPendingTransactions>(_onLoadPendingTransactions);
    on<CreateCredexEvent>(_onCreateCredex);
  }

  List<LedgerEntry> _deduplicateAndSortEntries(List<LedgerEntry> entries) {
    Logger.data('Deduplicating ${entries.length} ledger entries');
    final uniqueEntries = entries.where((entry) {
      final isUnique = !_processedCredexIds.contains(entry.credexID);
      if (isUnique) {
        _processedCredexIds.add(entry.credexID);
      }
      return isUnique;
    }).toList();

    uniqueEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    Logger.data('Returned ${uniqueEntries.length} unique entries');
    return uniqueEntries;
  }

  Future<void> loadInitialData() async {
    if (_isInitialized) {
      Logger.data('Initial data already loaded, skipping');
      return;
    }
    _isInitialized = true;

    Logger.data('Starting initial data load');
    final stopwatch = Stopwatch()..start();

    add(const HomeLoadStarted());
    _processedCredexIds.clear();

    try {
      // First try to get cached data from database
      final user = await _databaseHelper.getUser();
      Logger.data('Retrieved user from database: ${user != null}');
      
      if (user?.dashboard != null) {
        Logger.data('Using cached dashboard data');
        final pendingInTransactions = user!.dashboard!.accounts
            .expand((account) => (account.pendingInData.data ?? []).map((tx) => tx))
            .toList();
        final pendingOutTransactions = user.dashboard!.accounts
            .expand((account) => (account.pendingOutData.data ?? []).map((tx) => tx))
            .toList();

        // Emit cached data immediately
        emit(state.copyWith(
          status: HomeStatus.loading,
          dashboard: user.dashboard,
          pendingInTransactions: pendingInTransactions,
          pendingOutTransactions: pendingOutTransactions,
          filteredPendingInTransactions: pendingInTransactions,
          filteredPendingOutTransactions: pendingOutTransactions,
          filteredLedgerEntries: const [],
        ));

        // Load ledger data in background if we have accounts
        if (user.dashboard!.accounts.isNotEmpty) {
          await _loadLedgerData(user.dashboard!);
        }
      }

      // Then refresh data from server
      await _refreshViaLogin();
      
    } catch (e, stackTrace) {
      Logger.error('Failed to load initial data', e, stackTrace);
      
      // Only show error if we don't have any data
      if (state.dashboard == null) {
        add(const HomeErrorOccurred('Failed to load initial data'));
      }
    }

    stopwatch.stop();
    Logger.performance(
        'Initial data load took ${stopwatch.elapsedMilliseconds}ms');
  }

  Future<void> _loadLedgerData(Dashboard dashboard) async {
    Logger.data('Loading ledger data for accounts');

    final Map<String, List<LedgerEntry>> accountLedgers = {};
    final List<LedgerEntry> allEntries = [];
    bool hasMoreEntries = false;
    final List<String> errors = [];
    int processedAccounts = 0;
    final totalAccounts = dashboard.accounts.length;

    try {
      final accounts = dashboard.accounts;
      for (int i = 0; i < accounts.length; i += 2) {
        final batch = accounts.skip(i).take(2);

        for (final account in batch) {
          Logger.data('Fetching ledger for account: ${account.accountName}');

          final result = await accountRepository.getLedger(
            accountId: account.accountID,
            startRow: 0,
            numRows: 20,
          );

          processedAccounts++;
          final isLastAccount = processedAccounts == totalAccounts;

          result.fold(
            (failure) {
              Logger.error(
                  'Failed to fetch ledger for account ${account.accountID}',
                  failure);
              errors.add('Failed to load ledger for ${account.accountName}');

              if (isLastAccount && allEntries.isEmpty) {
                add(const HomeLedgerLoaded(
                  accountLedgers: {},
                  combinedEntries: [],
                  hasMore: false,
                ));
              }
            },
            (response) {
              try {
                if (!response.containsKey('data')) {
                  throw 'Invalid response structure: missing data field';
                }

                final data = response['data'];
                if (!data.containsKey('dashboard')) {
                  throw 'Invalid response structure: missing dashboard field';
                }

                final dashboard = data['dashboard'];
                final ledgerData = dashboard['ledger'] as List?;

                if (ledgerData == null) {
                  throw 'Invalid response structure: missing ledger data';
                }

                final pagination =
                    dashboard['pagination'] as Map<String, dynamic>?;
                final hasMore = pagination?['hasMore'] as bool? ?? false;

                if (hasMore) {
                  hasMoreEntries = true;
                }

                final entries = ledgerData
                    .map((entry) {
                      try {
                        return LedgerEntry.fromJson(
                          entry as Map<String, dynamic>,
                          accountId: account.accountID,
                          accountName: account.accountName,
                        );
                      } catch (e) {
                        Logger.error('Error parsing ledger entry', e);
                        return null;
                      }
                    })
                    .whereType<LedgerEntry>()
                    .toList();

                if (entries.isNotEmpty) {
                  accountLedgers[account.accountID] = entries;
                  allEntries.addAll(entries);
                }

                if (isLastAccount) {
                  if (allEntries.isNotEmpty) {
                    final uniqueEntries =
                        _deduplicateAndSortEntries(allEntries);
                    add(HomeLedgerLoaded(
                      accountLedgers: accountLedgers,
                      combinedEntries: uniqueEntries,
                      hasMore: false,
                    ));
                  } else if (errors.isNotEmpty) {
                    add(HomeErrorOccurred(errors.join('\n')));
                  } else {
                    add(const HomeLedgerLoaded(
                      accountLedgers: {},
                      combinedEntries: [],
                      hasMore: false,
                    ));
                  }
                }
              } catch (e) {
                Logger.error('Error processing ledger data', e);
                errors
                    .add('Error processing ledger for ${account.accountName}');

                if (isLastAccount && allEntries.isEmpty) {
                  add(const HomeLedgerLoaded(
                    accountLedgers: {},
                    combinedEntries: [],
                    hasMore: false,
                  ));
                }
              }
            },
          );
        }
      }
    } catch (e, stackTrace) {
      Logger.error('Error in _loadLedgerData', e, stackTrace);
      add(const HomeErrorOccurred('Failed to load ledger data'));
    }
  }

  Future<void> _refreshFromDb() async {
    try {
      final user = await _databaseHelper.getUser();
      Logger.data('Retrieved user from database: ${user != null}');
      if (user == null) {
        add(const HomeErrorOccurred('User not found'));
        return;
      }

      Logger.data('User dashboard available: ${user.dashboard != null}');
      if (user.dashboard == null) {
        add(const HomeErrorOccurred('Dashboard data not available'));
        return;
      }

      // Compare with state
      Logger.data('Current state:');
      Logger.data(
          '- ${state.pendingInTransactions.length} pending in transactions');
      Logger.data(
          '- ${state.pendingOutTransactions.length} pending out transactions');

      final pendingInTransactions = user.dashboard!.accounts
          .expand((account) => (account.pendingInData.data ?? []).map((tx) => tx))
          .toList();
      final pendingOutTransactions = user.dashboard!.accounts
          .expand((account) => (account.pendingOutData.data ?? []).map((tx) => tx))
          .toList();

      Logger.data('Database contains:');
      Logger.data('- ${pendingInTransactions.length} pending in transactions');
      Logger.data('- ${pendingOutTransactions.length} pending out transactions');

      // First update with refreshing state to ensure UI shows loading
      emit(state.copyWith(
        status: HomeStatus.refreshing,
        message: null,
        error: null,
      ));

      // Then update with new data and success state
      emit(state.copyWith(
        status: HomeStatus.success,
        dashboard: user.dashboard,
        pendingInTransactions: pendingInTransactions,
        pendingOutTransactions: pendingOutTransactions,
        // Also update filtered lists if no search is active
        filteredPendingInTransactions: state.searchQuery.isEmpty ? pendingInTransactions : null,
        filteredPendingOutTransactions: state.searchQuery.isEmpty ? pendingOutTransactions : null,
        message: null,
        error: null,
      ));

      // Log each transaction for debugging
      if (pendingInTransactions.isNotEmpty) {
        Logger.data('Pending In Transactions:');
        for (var tx in pendingInTransactions) {
          Logger.data(
              '- ${tx.credexID}: ${tx.formattedInitialAmount} from ${tx.counterpartyAccountName}');
        }
      }

      if (pendingOutTransactions.isNotEmpty) {
        Logger.data('Pending Out Transactions:');
        for (var tx in pendingOutTransactions) {
          Logger.data(
              '- ${tx.credexID}: ${tx.formattedInitialAmount} to ${tx.counterpartyAccountName}');
        }
      }
    } catch (e) {
      Logger.error('Failed to fetch pending transactions', e);
      add(HomeErrorOccurred('Failed to fetch pending transactions: $e'));
    }
  }

  Future<void> _refreshViaLogin() async {
    Logger.data('Starting refresh via login');
    final stopwatch = Stopwatch()..start();

    try {
      final user = await _databaseHelper.getUser();
      if (user == null || user.passwordHash == null || user.passwordSalt == null) {
        Logger.error('Cannot refresh: No stored user credentials');
        add(const HomeErrorOccurred(
            'Unable to refresh data: No stored credentials'));
        return;
      }

      final loginResult = await accountRepository.login(
        phone: user.phone,
        passwordHash: user.passwordHash,
        passwordSalt: user.passwordSalt,
      );

      await loginResult.fold(
        (failure) async {
          Logger.error('Login refresh failed', failure);
          add(HomeErrorOccurred(failure.message ?? 'Failed to refresh data'));
        },
        (newUser) async {
          Logger.data('Login refresh successful, processing new data');

          // Extract pending transactions from the new dashboard
          final pendingInTransactions = newUser.dashboard!.accounts
              .expand((account) => (account.pendingInData.data ?? []).map((tx) => tx))
          .toList();
          final pendingOutTransactions = newUser.dashboard!.accounts
              .expand((account) => (account.pendingOutData.data ?? []).map((tx) => tx))
          .toList();

          Logger.data(
              'Found ${pendingInTransactions.length} pending in and ${pendingOutTransactions.length} pending out transactions in new data');

          // Update database
          await _databaseHelper.saveUser(newUser);
          Logger.data('Updated user data in database');

          // Clear processed IDs before updating state
          _processedCredexIds.clear();

          // Force state update with loading first
          emit(state.copyWith(
            status: HomeStatus.refreshing,
            message: 'Updating balances...',
          ));

          // Then update with new data
          emit(state.copyWith(
            status: HomeStatus.success,
            dashboard: newUser.dashboard,
            pendingInTransactions: pendingInTransactions,
            pendingOutTransactions: pendingOutTransactions,
            // Also update filtered lists if no search is active
            filteredPendingInTransactions: state.searchQuery.isEmpty ? pendingInTransactions : null,
            filteredPendingOutTransactions: state.searchQuery.isEmpty ? pendingOutTransactions : null,
            message: null,
            error: null,
          ));

          if (newUser.dashboard!.accounts.isNotEmpty) {
            Logger.data('Updated state with new dashboard data. Net balance: ${newUser.dashboard!.accounts[state.currentPage].balanceData.netCredexAssetsInDefaultDenom}');
          }

          // Then load ledger data if needed
          if (newUser.dashboard!.accounts.isNotEmpty) {
            await _loadLedgerData(newUser.dashboard!);
          } else {
            add(const HomeLedgerLoaded(
              accountLedgers: {},
              combinedEntries: [],
              hasMore: false,
            ));
          }
        },
      );

      stopwatch.stop();
      Logger.performance(
          'Login refresh took ${stopwatch.elapsedMilliseconds}ms');
    } catch (e, stackTrace) {
      Logger.error('Error in login refresh', e, stackTrace);
      add(HomeErrorOccurred(e.toString()));
    }
  }

  void _onPageChanged(HomePageChanged event, Emitter<HomeState> emit) {
    Logger.interaction('Page changed to ${event.page}');
    emit(state.copyWith(
      currentPage: event.page,
      message: null,
    ));
  }

  void _onLoadStarted(HomeLoadStarted event, Emitter<HomeState> emit) {
    Logger.state('Initial loading started');
    emit(state.copyWith(
      status: HomeStatus.loading,
      message: null,
      error: null,
    ));
  }

  void _onRefreshStarted(
      HomeRefreshStarted event, Emitter<HomeState> emit) async {
    Logger.state('Refresh started');
    emit(state.copyWith(
      status: HomeStatus.refreshing,
      message: null,
      error: null,
    ));

    // First check what's in the database
    Logger.data('Checking database state before refresh');
    await _refreshViaLogin();
  }

  void _onLoadMoreStarted(HomeLoadMoreStarted event, Emitter<HomeState> emit) async {
    if (!state.hasMoreEntries) {
      Logger.state('Load more ignored - no more entries available');
      emit(state.copyWith(
        status: HomeStatus.success,
        error: null,
      ));
      return;
    }

    Logger.state('Loading more entries');
    emit(state.copyWith(
      status: HomeStatus.loadingMore,
      message: null,
      error: null,
    ));

    // Add a small delay to ensure state is emitted
    await Future.delayed(const Duration(milliseconds: 10));
  }

  void _onDataLoaded(HomeDataLoaded event, Emitter<HomeState> emit) {
    Logger.data('''Dashboard data loaded:
      Accounts: ${event.dashboard.accounts.length}
      Pending In: ${event.pendingInTransactions.length}
      Pending Out: ${event.pendingOutTransactions.length}
    ''');

    // Always update the main data lists
    final newState = state.copyWith(
      status: event.keepLoading ? state.status : HomeStatus.success,
      dashboard: event.dashboard,
      pendingInTransactions: event.pendingInTransactions,
      pendingOutTransactions: event.pendingOutTransactions,
      message: null,
      error: null,
    );

    // If there's an active search, apply filtering
    if (state.searchQuery.isNotEmpty) {
      final query = state.searchQuery.toLowerCase();
      
      final filteredPendingIn = event.pendingInTransactions.where((tx) {
        return tx.formattedInitialAmount.toLowerCase().contains(query) ||
               tx.counterpartyAccountName.toLowerCase().contains(query);
      }).toList();

      final filteredPendingOut = event.pendingOutTransactions.where((tx) {
        return tx.formattedInitialAmount.toLowerCase().contains(query) ||
               tx.counterpartyAccountName.toLowerCase().contains(query);
      }).toList();

      // Also filter ledger entries if they exist
      final filteredLedger = state.combinedLedgerEntries.where((entry) {
        return entry.description.toLowerCase().contains(query) ||
               entry.formattedAmount.toLowerCase().contains(query) ||
               entry.counterpartyAccountName.toLowerCase().contains(query);
      }).toList();

      emit(newState.copyWith(
        filteredPendingInTransactions: filteredPendingIn,
        filteredPendingOutTransactions: filteredPendingOut,
        filteredLedgerEntries: filteredLedger,
      ));
    } else {
      // If no search query, filtered lists should match main lists
      emit(newState.copyWith(
        filteredPendingInTransactions: event.pendingInTransactions,
        filteredPendingOutTransactions: event.pendingOutTransactions,
        filteredLedgerEntries: state.combinedLedgerEntries,
      ));
    }
  }

  void _onLedgerLoaded(HomeLedgerLoaded event, Emitter<HomeState> emit) {
    Logger.data('''Ledger data loaded:
      Total Entries: ${event.combinedEntries.length}
      Has More: ${event.hasMore}
      Accounts with Data: ${event.accountLedgers.keys.length}
    ''');

    // Always update the main ledger data
    final newState = state.copyWith(
      status: HomeStatus.success,
      accountLedgers: event.accountLedgers,
      combinedLedgerEntries: event.combinedEntries,
      hasMoreEntries: event.hasMore,
      message: null,
      error: null,
    );

    // If there's an active search, apply filtering
    if (state.searchQuery.isNotEmpty) {
      final query = state.searchQuery.toLowerCase();
      
      final filteredEntries = event.combinedEntries.where((entry) {
        return entry.description.toLowerCase().contains(query) ||
               entry.formattedAmount.toLowerCase().contains(query) ||
               entry.counterpartyAccountName.toLowerCase().contains(query);
      }).toList();

      // Also filter pending transactions to maintain consistency
      final filteredPendingIn = state.pendingInTransactions.where((tx) {
        return tx.formattedInitialAmount.toLowerCase().contains(query) ||
               tx.counterpartyAccountName.toLowerCase().contains(query);
      }).toList();

      final filteredPendingOut = state.pendingOutTransactions.where((tx) {
        return tx.formattedInitialAmount.toLowerCase().contains(query) ||
               tx.counterpartyAccountName.toLowerCase().contains(query);
      }).toList();

      emit(newState.copyWith(
        filteredLedgerEntries: filteredEntries,
        filteredPendingInTransactions: filteredPendingIn,
        filteredPendingOutTransactions: filteredPendingOut,
      ));
    } else {
      // If no search query, filtered lists should match main lists
      emit(newState.copyWith(
        filteredLedgerEntries: event.combinedEntries,
        filteredPendingInTransactions: state.pendingInTransactions,
        filteredPendingOutTransactions: state.pendingOutTransactions,
      ));
    }
  }

  void _onErrorOccurred(HomeErrorOccurred event, Emitter<HomeState> emit) {
    Logger.error('Home error occurred: ${event.message}');
    emit(state.copyWith(
      status: HomeStatus.error,
      error: event.message,
      message: null,
    ));

    // If error is related to authentication, clear state
    if (event.message?.toLowerCase().contains('credentials') == true ||
        event.message?.toLowerCase().contains('unauthorized') == true ||
        event.message?.toLowerCase().contains('unauthenticated') == true) {
      _processedCredexIds.clear();
      emit(const HomeState(status: HomeStatus.initial));
    }
  }

  @override
  Future<void> close() async {
    Logger.lifecycle('HomeBloc closing');
    _processedCredexIds.clear();
    _isInitialized = false;
    await super.close();
  }

  void _onAcceptCredexBulkStarted(
    HomeAcceptCredexBulkStarted event,
    Emitter<HomeState> emit,
  ) async {
    Logger.state(
        'Starting bulk credex acceptance for ${event.credexIds.length} transactions');

    emit(state.copyWith(
      status: HomeStatus.acceptingCredex,
      processingCredexIds: event.credexIds,
      error: null,
    ));

    final stopwatch = Stopwatch()..start();
    final result = await acceptCredexBulk(event.credexIds);
    stopwatch.stop();

    Logger.performance(
        'Bulk credex acceptance took ${stopwatch.elapsedMilliseconds}ms');

    result.fold(
      (failure) {
        Logger.error('Bulk credex acceptance failed', failure);
        add(HomeErrorOccurred(
            failure.message ?? 'Failed to accept transactions'));
      },
      (_) async {
        Logger.data(
            'Successfully processed ${event.credexIds.length} credex transactions');
            
        // Set loading state
        emit(state.copyWith(
          status: HomeStatus.refreshing,
          message: 'Refreshing balances...',
          error: null,
        ));
        
        // Add a small delay to ensure backend has processed the transaction
        await Future.delayed(const Duration(seconds: 2));
        
        // Refresh data to get updated balances and transactions
        await _refreshViaLogin();
        
        add(const HomeAcceptCredexBulkCompleted());
      },
    );
  }

  void _onAcceptCredexBulkCompleted(
    HomeAcceptCredexBulkCompleted event,
    Emitter<HomeState> emit,
  ) {
    Logger.state('Bulk credex acceptance completed');
    // No need to refresh here as it's already done in _onAcceptCredexBulkStarted
  }

  void _onCancelCredexStarted(
    HomeCancelCredexStarted event,
    Emitter<HomeState> emit,
  ) async {
    Logger.state('Starting credex cancellation for ${event.credexId}');

    emit(state.copyWith(
      status: HomeStatus.cancellingCredex,
      processingCredexIds: [event.credexId],
      error: null,
    ));

    final result = await accountRepository.cancelCredex(event.credexId);

    result.fold(
      (failure) {
        Logger.error('Credex cancellation failed', failure);
        add(HomeErrorOccurred(
            failure.message ?? 'Failed to cancel transaction'));
      },
      (_) async {
        Logger.data('Successfully cancelled credex transaction');
            
        // Set loading state and trigger refresh immediately
        emit(state.copyWith(
          status: HomeStatus.refreshing,
          message: 'Refreshing balances...',
          error: null,
        ));
        
        // Refresh data to get updated balances and transactions
        await _refreshViaLogin();
        
        add(const HomeCancelCredexCompleted());
      },
    );
  }

  void _onCancelCredexCompleted(
    HomeCancelCredexCompleted event,
    Emitter<HomeState> emit,
  ) {
    Logger.state('Credex cancellation completed');
    emit(state.copyWith(
      status: HomeStatus.success,
      processingCredexIds: const [],
      message: 'Credex cancelled successfully',
      error: null,
    ));
  }

  Future<void> _onFetchPendingTransactions(
    HomeFetchPendingTransactions event,
    Emitter<HomeState> emit,
  ) async {
    Logger.state('Refresh started');
    emit(state.copyWith(
      status: HomeStatus.refreshing,
      message: null,
      error: null,
    ));

    // First check what's in the database
    Logger.data('Checking database state before refresh');
    // Trigger refresh
    await _refreshFromDb();
  }

  void _onSearchStarted(HomeSearchStarted event, Emitter<HomeState> emit) {
    Logger.interaction('Search started with query: ${event.query}');
    
    // Always update search query first
    emit(state.copyWith(searchQuery: event.query));
    
    if (event.query.isEmpty) {
      Logger.data('Empty search query - showing all transactions');
      emit(state.copyWith(
        filteredLedgerEntries: state.combinedLedgerEntries,
        filteredPendingInTransactions: state.pendingInTransactions,
        filteredPendingOutTransactions: state.pendingOutTransactions,
      ));
      return;
    }

    final query = event.query.toLowerCase();
    Logger.data('Filtering transactions with query: $query');
    
    // Filter ledger entries
    final filteredEntries = state.combinedLedgerEntries.where((entry) {
      final matches = entry.description.toLowerCase().contains(query) ||
             entry.formattedAmount.toLowerCase().contains(query) ||
             entry.counterpartyAccountName.toLowerCase().contains(query);
      if (matches) {
        Logger.data('Matched ledger entry: ${entry.description}');
      }
      return matches;
    }).toList();

    // Filter pending in transactions
    final filteredPendingIn = state.pendingInTransactions.where((tx) {
      final matches = tx.formattedInitialAmount.toLowerCase().contains(query) ||
             tx.counterpartyAccountName.toLowerCase().contains(query);
      if (matches) {
        Logger.data('Matched pending in: ${tx.counterpartyAccountName}');
      }
      return matches;
    }).toList();

    // Filter pending out transactions
    final filteredPendingOut = state.pendingOutTransactions.where((tx) {
      final matches = tx.formattedInitialAmount.toLowerCase().contains(query) ||
             tx.counterpartyAccountName.toLowerCase().contains(query);
      if (matches) {
        Logger.data('Matched pending out: ${tx.counterpartyAccountName}');
      }
      return matches;
    }).toList();

    Logger.data('''Search results:
      Ledger entries: ${filteredEntries.length}
      Pending in: ${filteredPendingIn.length}
      Pending out: ${filteredPendingOut.length}
    ''');

    emit(state.copyWith(
      filteredLedgerEntries: filteredEntries,
      filteredPendingInTransactions: filteredPendingIn,
      filteredPendingOutTransactions: filteredPendingOut,
    ));
  }

  Future<void> _onRegisterNotificationToken(
    HomeRegisterNotificationToken event,
    Emitter<HomeState> emit,
  ) async {
    Logger.data('Registering notification token');
    
    final result = await accountRepository.registerNotificationToken(event.token);
    
    result.fold(
      (failure) {
        Logger.error('Failed to register notification token', failure);
        add(HomeErrorOccurred(failure.message ?? 'Failed to register notification token'));
      },
      (_) {
        Logger.data('Successfully registered notification token');
      },
    );
  }

  void _onLoadPendingTransactions(
    HomeLoadPendingTransactions event,
    Emitter<HomeState> emit,
  ) {
    Logger.data('Loading pending transactions');
    emit(state.copyWith(
      status: HomeStatus.success,
      pendingInTransactions: event.pendingInTransactions,
      pendingOutTransactions: event.pendingOutTransactions,
      filteredPendingInTransactions: event.pendingInTransactions,
      filteredPendingOutTransactions: event.pendingOutTransactions,
    ));
  }

  Future<void> _onCreateCredex(
    CreateCredexEvent event,
    Emitter<HomeState> emit,
  ) async {
    Logger.data('Creating credex request');
    
    final result = await accountRepository.createCredex(event.request);
    
    result.fold(
      (failure) {
        Logger.error('Failed to create credex', failure);
        add(HomeErrorOccurred(failure.message ?? 'Failed to create credex'));
      },
      (_) {
        Logger.data('Successfully created credex');
      },
    );
  }
}
