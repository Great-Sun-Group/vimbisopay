import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vimbisopay_app/application/usecases/accept_credex_bulk.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_event.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final AcceptCredexBulk acceptCredexBulk;
  final AccountRepository accountRepository;
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final Set<String> _processedCredexIds = {};
  bool _isInitialized = false;

  HomeBloc({
    required this.acceptCredexBulk,
    required this.accountRepository,
  }) : super(const HomeState()) {
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

      Logger.data('User accounts: ${user.dashboard!.accounts.length}');
      Logger.data(
          'Raw pending in data: ${user.dashboard!.accounts.map((a) => a.pendingInData.data.length ?? 0).reduce((a, b) => a + b)}');
      Logger.data(
          'Raw pending out data: ${user.dashboard!.accounts.map((a) => a.pendingOutData.data.length ?? 0).reduce((a, b) => a + b)}');

      final pendingInTransactions = user.dashboard!.accounts
          .expand((account) => (account.pendingInData.data ?? []))
          .map((offer) => PendingOffer.fromMap(offer.toMap()))
          .toList();
      final pendingOutTransactions = user.dashboard!.accounts
          .expand((account) => (account.pendingOutData.data ?? []))
          .map((offer) => PendingOffer.fromMap(offer.toMap()))
          .toList();

      Logger.data(
          'Found ${pendingInTransactions.length} pending in and ${pendingOutTransactions.length} pending out transactions');

      add(HomeDataLoaded(
        dashboard: user.dashboard!,
        pendingInTransactions: pendingInTransactions,
        pendingOutTransactions: pendingOutTransactions,
        keepLoading: user.dashboard!.accounts.isNotEmpty,
      ));

      if (user.dashboard!.accounts.isNotEmpty) {
        await _loadLedgerData(user.dashboard!);
      } else {
        add(const HomeLedgerLoaded(
          accountLedgers: {},
          combinedEntries: [],
          hasMore: false,
        ));
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to load initial data', e, stackTrace);
      add(const HomeErrorOccurred('Failed to load initial data'));
    }

    stopwatch.stop();
    Logger.performance(
        'Initial data load took ${stopwatch.elapsedMilliseconds}ms');
  }

  Future<void> _loadLedgerData(dashboard) async {
    Logger.data('Loading ledger data for accounts');

    add(const HomeLoadStarted());

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

      loginResult.fold(
        (failure) async {
          Logger.error('Login refresh failed', failure);
          add(HomeErrorOccurred(failure.message ?? 'Failed to refresh data'));
        },
        (newUser) async {
          Logger.data('Login refresh successful, updating dashboard');

          final pendingInTransactions = newUser.dashboard!.accounts
              .expand((account) => (account.pendingInData.data ?? []))
              .map((offer) => PendingOffer.fromMap(offer.toMap()))
              .toList();
          final pendingOutTransactions = newUser.dashboard!.accounts
              .expand((account) => (account.pendingOutData.data ?? []))
              .map((offer) => PendingOffer.fromMap(offer.toMap()))
              .toList();

          Logger.data(
              'Refresh found ${pendingInTransactions.length} pending in and ${pendingOutTransactions.length} pending out transactions');

          // Update local storage with new data
          await _databaseHelper.saveUser(newUser);

          add(HomeDataLoaded(
            dashboard: newUser.dashboard!,
            pendingInTransactions: pendingInTransactions,
            pendingOutTransactions: pendingOutTransactions,
            keepLoading: true,
          ));

          _processedCredexIds.clear();

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

      final (pendingIn, pendingOut) =
          await _databaseHelper.getAllPendingTransactions();
      Logger.data('Database contains:');
      Logger.data('- ${pendingIn.length} pending in transactions');
      Logger.data('- ${pendingOut.length} pending out transactions');

      // Update state with fetched transactions
      emit(state.copyWith(
        status: HomeStatus.success,
        pendingInTransactions: pendingIn,
        pendingOutTransactions: pendingOut,
      ));

      // Log each transaction for debugging
      if (pendingIn.isNotEmpty) {
        Logger.data('Pending In Transactions:');
        for (var tx in pendingIn) {
          Logger.data(
              '- ${tx.credexID}: ${tx.formattedInitialAmount} from ${tx.counterpartyAccountName}');
        }
      }

      if (pendingOut.isNotEmpty) {
        Logger.data('Pending Out Transactions:');
        for (var tx in pendingOut) {
          Logger.data(
              '- ${tx.credexID}: ${tx.formattedInitialAmount} to ${tx.counterpartyAccountName}');
        }
      }
    } catch (e) {
      Logger.error('Failed to fetch pending transactions', e);
      add(HomeErrorOccurred('Failed to fetch pending transactions: $e'));
    }
  }

  void _onLoadMoreStarted(HomeLoadMoreStarted event, Emitter<HomeState> emit) {
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
  }

  void _onDataLoaded(HomeDataLoaded event, Emitter<HomeState> emit) {
    Logger.data('''Dashboard data loaded:
      Accounts: ${event.dashboard.accounts.length}
      Pending In: ${event.pendingInTransactions.length}
      Pending Out: ${event.pendingOutTransactions.length}
    ''');

    emit(state.copyWith(
      status: event.keepLoading ? HomeStatus.loading : HomeStatus.success,
      dashboard: event.dashboard,
      pendingInTransactions: event.pendingInTransactions,
      pendingOutTransactions: event.pendingOutTransactions,
      message: null,
      error: null,
    ));
  }

  void _onLedgerLoaded(HomeLedgerLoaded event, Emitter<HomeState> emit) {
    Logger.data('''Ledger data loaded:
      Total Entries: ${event.combinedEntries.length}
      Has More: ${event.hasMore}
      Accounts with Data: ${event.accountLedgers.keys.length}
    ''');

    emit(state.copyWith(
      status: HomeStatus.success,
      accountLedgers: event.accountLedgers,
      combinedLedgerEntries: event.combinedEntries,
      hasMoreEntries: event.hasMore,
      message: null,
      error: null,
    ));
  }

  void _onErrorOccurred(HomeErrorOccurred event, Emitter<HomeState> emit) {
    Logger.error('Home error occurred: ${event.message}');
    emit(state.copyWith(
      status: HomeStatus.error,
      error: event.message,
      message: null,
    ));
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

        final updatedPendingIn = state.pendingInTransactions
            .where((tx) => !event.credexIds.contains(tx.credexID))
            .toList();
        final updatedPendingOut = state.pendingOutTransactions
            .where((tx) => !event.credexIds.contains(tx.credexID))
            .toList();

        // Update UI state immediately
        emit(state.copyWith(
          status: HomeStatus.success,
          pendingInTransactions: updatedPendingIn,
          pendingOutTransactions: updatedPendingOut,
          message: 'Credex transactions accepted successfully',
          error: null,
        ));

        // Update database in background
        try {
          final user = await _databaseHelper.getUser();
          if (user?.dashboard != null) {
            final updatedAccounts = user!.dashboard!.accounts.map((account) {
              return DashboardAccount(
                accountID: account.accountID,
                accountName: account.accountName,
                accountHandle: account.accountHandle,
                defaultDenom: account.defaultDenom,
                isOwnedAccount: account.isOwnedAccount,
                balanceData: account.balanceData,
                pendingInData: PendingData(
                  success: true,
                  data: (account.pendingInData.data ?? [])
                      .where((tx) => !event.credexIds.contains(tx.credexID))
                      .map((offer) => PendingOffer.fromMap(offer.toMap()))
                      .toList(),
                  message: 'Pending offers retrieved',
                ),
                pendingOutData: account.pendingOutData,
                sendOffersTo: account.sendOffersTo,
              );
            }).toList();

            final updatedDashboard = Dashboard(
              id: user.dashboard!.id,
              member: user.dashboard!.member,
              accounts: updatedAccounts,
            );
            await _databaseHelper
                .saveUser(user.copyWith(dashboard: updatedDashboard));
            Logger.data('Pending transactions updated in database');
          }
        } catch (e) {
          Logger.error('Failed to update database', e);
          // Don't emit error state since UI is already updated
        }

        add(const HomeAcceptCredexBulkCompleted());
      },
    );
  }

  void _onAcceptCredexBulkCompleted(
    HomeAcceptCredexBulkCompleted event,
    Emitter<HomeState> emit,
  ) {
    Logger.state('Bulk credex acceptance completed');
    emit(state.copyWith(
      status: HomeStatus.success,
      processingCredexIds: const [],
      message: 'Credex transactions accepted successfully',
      error: null,
    ));
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

        // Update UI state immediately
        final updatedPendingOut = state.pendingOutTransactions
            .where((tx) => tx.credexID != event.credexId)
            .toList();

        emit(state.copyWith(
          status: HomeStatus.success,
          pendingInTransactions: state.pendingInTransactions,
          pendingOutTransactions: updatedPendingOut,
          message: 'Credex cancelled successfully',
          error: null,
        ));

        // Update database in background
        try {
          final user = await _databaseHelper.getUser();
          if (user?.dashboard != null) {
            final updatedAccounts = user!.dashboard!.accounts.map((account) {
              return DashboardAccount(
                accountID: account.accountID,
                accountName: account.accountName,
                accountHandle: account.accountHandle,
                defaultDenom: account.defaultDenom,
                isOwnedAccount: account.isOwnedAccount,
                balanceData: account.balanceData,
                pendingInData: account.pendingInData,
                pendingOutData: PendingData(
                  success: true,
                  data: (account.pendingOutData.data ?? [])
                      .where((tx) => tx.credexID != event.credexId)
                      .map((offer) => PendingOffer.fromMap(offer.toMap()))
                      .toList(),
                  message: 'Pending outgoing offers retrieved',
                ),
                sendOffersTo: account.sendOffersTo,
              );
            }).toList();

            final updatedDashboard = Dashboard(
              id: user.dashboard!.id,
              member: user.dashboard!.member,
              accounts: updatedAccounts,
            );
            await _databaseHelper
                .saveUser(user.copyWith(dashboard: updatedDashboard));
            Logger.data('Pending transactions updated in database');
          }
        } catch (e) {
          Logger.error('Failed to update database', e);
          // Don't emit error state since UI is already updated
        }

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
}
