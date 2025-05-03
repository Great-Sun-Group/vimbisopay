import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:vimbisopay_app/core/error/exceptions.dart';
import 'package:vimbisopay_app/core/utils/error_translator.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/application/usecases/accept_credex_bulk.dart';
import 'package:vimbisopay_app/application/usecases/accept_credex.dart';
import 'package:vimbisopay_app/application/usecases/upgrade_member_tier.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_event.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final AccountRepository accountRepository;
  final DatabaseHelper databaseHelper;
  final AcceptCredexBulk acceptCredexBulk;
  final AcceptCredex acceptCredex;
  final UpgradeMemberTier upgradeMemberTier;
  final _logger = Logger();
  
  int _totalAccounts = 0;
  int _processedAccounts = 0;
  DateTime? _lastRefreshTimestamp;

  HomeBloc({
    required this.accountRepository,
    required this.databaseHelper,
    required this.acceptCredexBulk,
    required this.acceptCredex,
    required this.upgradeMemberTier,
  }) : super(const HomeState()) {
    on<HomeLoadStarted>(_onHomeLoadStarted);
    on<HomeRefreshStarted>(_onHomeRefreshStarted);
    on<HomeLoadMoreStarted>(_onHomeLoadMoreStarted);
    on<HomeDataLoaded>(_onHomeDataLoaded);
    on<HomeLedgerLoaded>(_onHomeLedgerLoaded);
    on<HomeErrorOccurred>(_onHomeErrorOccurred);
    on<HomePageChanged>(_onHomePageChanged);
    on<HomeAcceptCredexStarted>(_onHomeAcceptCredexStarted);
    on<HomeAcceptCredexBulkStarted>(_onHomeAcceptCredexBulkStarted);
    on<HomeCancelCredexStarted>(_onHomeCancelCredexStarted);
    on<HomeDeclineCredexStarted>(_onHomeDeclineCredexStarted);
    on<HomeSearchStarted>(_onHomeSearchStarted);
    on<HomeUpgradeTierStarted>(_onHomeUpgradeTierStarted);
    on<HomeUpgradeTierCompleted>(_onHomeUpgradeTierCompleted);
    on<HomeUpgradeTierFailed>(_onHomeUpgradeTierFailed);
    on<HomeFetchPendingTransactions>(_onHomeFetchPendingTransactions);
    on<HomeOfferAccepted>(_onHomeOfferAccepted);
  }

  void loadInitialData() {
    add(const HomeLoadStarted());
  }

  Future<void> _onHomeLoadStarted(HomeLoadStarted event, Emitter<HomeState> emit) async {
    // Check if update screen is showing - if so, don't proceed with loading
    if (ServiceLocator.appStateManager.isUpdateScreenShowing) {
      _logger.i('Home load prevented while update screen is showing');
      return;
    }
    
    emit(state.copyWith(status: HomeStatus.loading));
    
    try {
      // Get current user which includes the dashboard
      final userResult = await accountRepository.getCurrentUser();
      
      // Check again if update screen is showing before processing the result
      if (ServiceLocator.appStateManager.isUpdateScreenShowing) {
        _logger.i('Home load result processing prevented while update screen is showing');
        return;
      }
      
      await userResult.fold(
        (failure) async {
          emit(state.copyWith(
            status: HomeStatus.error,
            error: failure.message ?? 'Failed to load dashboard',
          ));
        },
        (user) async {
          if (user == null || user.dashboard == null) {
            emit(state.copyWith(
              status: HomeStatus.error,
              error: 'No user data found',
            ));
            return;
          }
          
          // Extract pending transactions from all accounts
          final List<PendingOffer> pendingIn = [];
          final List<PendingOffer> pendingOut = [];
          
          for (final account in user.dashboard!.accounts) {
            pendingIn.addAll(account.pendingInData.data);
            pendingOut.addAll(account.pendingOutData.data);
          }

          // Add the HomeDataLoaded event with the dashboard and pending transactions
          add(HomeDataLoaded(
            dashboard: user.dashboard!,
            pendingInTransactions: pendingIn,
            pendingOutTransactions: pendingOut,
            keepLoading: true,
          ));
          
          await _loadLedgerData(user.dashboard!);
        },
      );
    } catch (e) {
      final userFriendlyMessage = ErrorTranslator.translateError(e);
      emit(state.copyWith(
        status: HomeStatus.error,
        error: 'Failed to initialize dashboard: $userFriendlyMessage',
      ));
    }
  }

  Future<void> _onHomeRefreshStarted(HomeRefreshStarted event, Emitter<HomeState> emit) async {
    _logger.i('''
Starting home refresh:
- Has dashboard: ${state.dashboard != null}
- Current status: ${state.status}
- Source: ${event.source}
- Force refresh: ${event.forceRefresh}
''');

    // Check if update screen is showing - if so, don't proceed with refresh
    if (ServiceLocator.appStateManager.isUpdateScreenShowing) {
      _logger.i('Home refresh prevented while update screen is showing');
      return;
    }

    if (state.dashboard == null) {
      _logger.e('Cannot refresh - no dashboard available');
      return;
    }
    
    // Apply throttling for foreground refreshes
    if (event.source == RefreshSource.foreground && !event.forceRefresh) {
      // Skip if last refresh was recent (within 2 minutes)
      if (_lastRefreshTimestamp != null) {
        final timeSinceLastRefresh = DateTime.now().difference(_lastRefreshTimestamp!);
        if (timeSinceLastRefresh < const Duration(minutes: 2)) {
          _logger.i('Skipping foreground refresh - last refresh was ${timeSinceLastRefresh.inSeconds} seconds ago');
          return;
        }
      }
    }
    
    emit(state.copyWith(status: HomeStatus.refreshing));
    
    try {
      // Get stored user first
      final storedUser = await databaseHelper.getUser();
      if (storedUser == null) {
        emit(state.copyWith(
          status: HomeStatus.error,
          error: 'No stored user found',
        ));
        return;
      }

      _logger.i('Re-logging in to refresh token...');
      // Re-login to refresh token using v1 login
      final loginResult = await accountRepository.login(
        phone: storedUser.phone,
      );
      _logger.i('Re-login completed');
      
      await loginResult.fold(
        (failure) async {
          emit(state.copyWith(
            status: HomeStatus.error,
            error: failure.message ?? 'Failed to refresh dashboard',
          ));
        },
        (user) async {
          if (user.dashboard == null) {
            emit(state.copyWith(
              status: HomeStatus.error,
              error: 'No dashboard data found',
            ));
            return;
          }

          try {
            _logger.i('Saving updated user and refreshing data...');
            // Save updated user with new token
            await databaseHelper.saveUser(user);
            
            // Extract pending transactions from refreshed dashboard
            final List<PendingOffer> pendingIn = [];
            final List<PendingOffer> pendingOut = [];
            
            for (final account in user.dashboard!.accounts) {
              pendingIn.addAll(account.pendingInData.data);
              pendingOut.addAll(account.pendingOutData.data);
            }

            _logger.i('''
Dashboard refresh stats:
- Accounts: ${user.dashboard!.accounts.length}
- Pending In: ${pendingIn.length}
- Pending Out: ${pendingOut.length}
''');

            // Update state with refreshed data
            emit(state.copyWith(
              status: HomeStatus.success,
              dashboard: user.dashboard,
              pendingInTransactions: pendingIn,
              pendingOutTransactions: pendingOut,
              processingCredexIds: state.processingCredexIds, // Preserve processing state
            ));
            
            _logger.i('Loading ledger data for refreshed dashboard...');
            await _loadLedgerData(user.dashboard!, source: event.source);
            _logger.i('Refresh complete');

            // Show success message
            emit(state.copyWith(
              status: HomeStatus.success,
              message: 'Dashboard refreshed successfully',
              processingCredexIds: state.processingCredexIds, // Preserve processing state
            ));
            
            // Update last refresh timestamp
            _lastRefreshTimestamp = DateTime.now();
            _logger.i('Updated last refresh timestamp: $_lastRefreshTimestamp');
          } catch (e) {
            final userFriendlyMessage = ErrorTranslator.translateError(e);
            _logger.e('Error saving user or updating state: $e');
            emit(state.copyWith(
              status: HomeStatus.error,
              error: 'Failed to update dashboard data: $userFriendlyMessage',
            ));
          }
        },
      );
    } catch (e) {
      final userFriendlyMessage = ErrorTranslator.translateError(e);
      emit(state.copyWith(
        status: HomeStatus.error,
        error: 'Failed to refresh dashboard: $userFriendlyMessage',
      ));
    }
  }

  Future<void> _onHomeLoadMoreStarted(HomeLoadMoreStarted event, Emitter<HomeState> emit) async {
    // Check if update screen is showing - if so, don't proceed with loading more data
    if (ServiceLocator.appStateManager.isUpdateScreenShowing) {
      _logger.i('Load more prevented while update screen is showing');
      return;
    }
    
    if (state.dashboard == null || !state.hasMoreEntries) return;
    
    // Prevent multiple concurrent load more requests
    if (state.status == HomeStatus.loadingMore) return;
    
    emit(state.copyWith(status: HomeStatus.loadingMore));

    try {
      final accounts = state.dashboard!.accounts;
      final Map<String, List<LedgerEntry>> accountLedgers = Map.from(state.accountLedgers);
      final List<LedgerEntry> allEntries = List.from(state.combinedLedgerEntries);
      bool hasMoreEntries = false;

      // Find oldest timestamp across all entries
      DateTime? oldestTimestamp;
      for (final entries in accountLedgers.values) {
        if (entries.isNotEmpty) {
          final lastEntryTimestamp = entries.last.timestamp;
          if (oldestTimestamp == null || lastEntryTimestamp.isBefore(oldestTimestamp)) {
            oldestTimestamp = lastEntryTimestamp;
          }
        }
      }

      // Load next page for each account sequentially
      for (final account in accounts) {
        // Fetch new entries with retry logic
        bool success = false;
        int retryDelay = 5000; // Start with 5 seconds
        int retryCount = 0;
        const maxRetries = 3;

        while (!success && retryCount < maxRetries) {
          try {
            final result = await accountRepository.getLedger(
              accountId: account.accountID,
              afterTimestamp: oldestTimestamp,
              limit: 10, // Reduced batch size to prevent rate limiting
            );

            result.fold(
              (failure) {
                _logger.e('Failed to load more entries for account ${account.accountID}: ${failure.toString()}');
                success = true; // Don't retry on non-rate-limit failures
              },
              (entries) {
                if (entries.isNotEmpty) {
                  // Update existing entries
                  if (accountLedgers.containsKey(account.accountID)) {
                    accountLedgers[account.accountID]!.addAll(entries);
                  } else {
                    accountLedgers[account.accountID] = entries;
                  }
                  allEntries.addAll(entries);
                  
                  // Check if we got the maximum number of entries
                  if (entries.length >= 10) {
                    hasMoreEntries = true;
                  }

                  // Emit intermediate updates to show progress
                  final uniqueEntries = _deduplicateAndSortEntries(allEntries);
                  add(HomeLedgerLoaded(
                    accountLedgers: accountLedgers,
                    combinedEntries: uniqueEntries,
                    hasMore: hasMoreEntries,
                  ));
                }
                success = true;
              },
            );
          } catch (e) {
            if (e is RateLimitException) {
              retryCount++;
              if (retryCount < maxRetries) {
                _logger.w('Rate limit hit (attempt $retryCount of $maxRetries), retrying in ${retryDelay}ms');
                await Future.delayed(Duration(milliseconds: retryDelay));
                retryDelay *= 2; // Exponential backoff
              } else {
                _logger.e('Max retries reached for rate limit');
                success = true;
              }
            } else {
              final userFriendlyMessage = ErrorTranslator.translateError(e);
              _logger.e('Error fetching more entries: $e');
              add(HomeErrorOccurred('Error loading more entries: $userFriendlyMessage'));
              success = true;
            }
          }
        }

        // Add delay between accounts to prevent rate limiting
        if (accounts.last != account) {
          await Future.delayed(const Duration(milliseconds: 5000)); // Increased delay to match _loadLedgerData
        }
      }
    } catch (e, stackTrace) {
      final userFriendlyMessage = ErrorTranslator.translateError(e);
      _logger.e('Error in _onHomeLoadMoreStarted: $e\n$stackTrace');
      add(HomeErrorOccurred('Failed to load more entries: $userFriendlyMessage'));
    }
  }

  Future<void> _onHomeDataLoaded(HomeDataLoaded event, Emitter<HomeState> emit) async {
    emit(state.copyWith(
      status: HomeStatus.success,
      dashboard: event.dashboard,
      pendingInTransactions: event.pendingInTransactions,
      pendingOutTransactions: event.pendingOutTransactions,
      processingCredexIds: state.processingCredexIds, // Preserve processing state
    ));
    if (event.keepLoading) {
      await _loadLedgerData(event.dashboard);
    }
  }

  void _onHomeLedgerLoaded(HomeLedgerLoaded event, Emitter<HomeState> emit) {
    emit(state.copyWith(
      status: HomeStatus.success,
      accountLedgers: event.accountLedgers,
      combinedLedgerEntries: event.combinedEntries,
      hasMoreEntries: event.hasMore,
      processingCredexIds: state.processingCredexIds, // Preserve processing state
    ));
  }

  void _onHomeErrorOccurred(HomeErrorOccurred event, Emitter<HomeState> emit) {
    emit(state.copyWith(
      status: HomeStatus.error,
      error: event.message,
    ));
  }

  void _onHomePageChanged(HomePageChanged event, Emitter<HomeState> emit) {
    // Check if update screen is showing - if so, don't proceed with page change
    if (ServiceLocator.appStateManager.isUpdateScreenShowing) {
      _logger.i('Page change prevented while update screen is showing');
      return;
    }
    
    emit(state.copyWith(currentPage: event.page));
  }

  Future<void> _onHomeAcceptCredexStarted(HomeAcceptCredexStarted event, Emitter<HomeState> emit) async {
    // Check if update screen is showing - if so, don't proceed with accepting credex
    if (ServiceLocator.appStateManager.isUpdateScreenShowing) {
      _logger.i('Accept credex prevented while update screen is showing');
      return;
    }
    
    // Add the credexId to processing state
    final updatedProcessingIds = [...state.processingCredexIds, event.credexId];
    
    emit(state.copyWith(
      status: HomeStatus.acceptingCredex,
      processingCredexIds: updatedProcessingIds,
    ));
    
    final result = await acceptCredex(event.credexId);
    result.fold(
      (failure) {
        // On failure, remove from processing state
        final userFriendlyMessage = ErrorTranslator.translateError(failure);
        add(HomeErrorOccurred('Failed to accept Credex: $userFriendlyMessage'));
        emit(state.copyWith(
          processingCredexIds: state.processingCredexIds.where((id) => id != event.credexId).toList(),
        ));
      },
      (_) {
        // On success, keep in processing state
        emit(state.copyWith(
          status: HomeStatus.success,
          processingCredexIds: updatedProcessingIds, // Keep the credexId in processing state
          message: 'Transaction accepted successfully',
        ));
        // Trigger refresh to update dashboard and transactions
        add(const HomeRefreshStarted());
      },
    );
  }

  Future<void> _onHomeAcceptCredexBulkStarted(HomeAcceptCredexBulkStarted event, Emitter<HomeState> emit) async {
    // Check if update screen is showing - if so, don't proceed with accepting credex bulk
    if (ServiceLocator.appStateManager.isUpdateScreenShowing) {
      _logger.i('Accept credex bulk prevented while update screen is showing');
      return;
    }
    
    // Add all credexIds to processing state
    final updatedProcessingIds = [...state.processingCredexIds, ...event.credexIds];
    
    emit(state.copyWith(
      status: HomeStatus.acceptingCredex,
      processingCredexIds: updatedProcessingIds,
    ));
    
    final result = await acceptCredexBulk(event.credexIds);
    result.fold(
      (failure) {
        // On failure, remove all from processing state
        final userFriendlyMessage = ErrorTranslator.translateError(failure);
        add(HomeErrorOccurred('Failed to accept Credex transactions: $userFriendlyMessage'));
        emit(state.copyWith(
          processingCredexIds: state.processingCredexIds.where((id) => !event.credexIds.contains(id)).toList(),
        ));
      },
      (_) {
        // On success, keep in processing state
        emit(state.copyWith(
          status: HomeStatus.success,
          processingCredexIds: updatedProcessingIds, // Keep all credexIds in processing state
          message: 'Transactions accepted successfully',
        ));
        // Trigger refresh to update dashboard and transactions
        add(const HomeRefreshStarted());
      },
    );
  }

  Future<void> _onHomeCancelCredexStarted(HomeCancelCredexStarted event, Emitter<HomeState> emit) async {
    // Check if update screen is showing - if so, don't proceed with cancelling credex
    if (ServiceLocator.appStateManager.isUpdateScreenShowing) {
      _logger.i('Cancel credex prevented while update screen is showing');
      return;
    }
    
    emit(state.copyWith(
      status: HomeStatus.cancellingCredex,
      processingCredexIds: [...state.processingCredexIds, event.credexId],
    ));
    final result = await accountRepository.cancelCredex(event.credexId);
    result.fold(
      (failure) {
        final userFriendlyMessage = ErrorTranslator.translateError(failure);
        add(HomeErrorOccurred('Failed to cancel Credex: $userFriendlyMessage'));
      },
      (_) {
        emit(state.copyWith(
          status: HomeStatus.success,
          processingCredexIds: const [],
          message: 'Transaction cancelled successfully',
        ));
        // Trigger refresh to update dashboard and transactions
        add(const HomeRefreshStarted());
      },
    );
  }
  
  Future<void> _onHomeDeclineCredexStarted(HomeDeclineCredexStarted event, Emitter<HomeState> emit) async {
    // Check if update screen is showing - if so, don't proceed with declining credex
    if (ServiceLocator.appStateManager.isUpdateScreenShowing) {
      _logger.i('Decline credex prevented while update screen is showing');
      return;
    }
    
    emit(state.copyWith(
      status: HomeStatus.cancellingCredex, // Reuse the cancelling status for UI feedback
      processingCredexIds: [...state.processingCredexIds, event.credexId],
    ));
    final result = await accountRepository.declineCredex(event.credexId);
    result.fold(
      (failure) {
        final userFriendlyMessage = ErrorTranslator.translateError(failure);
        add(HomeErrorOccurred('Failed to decline Credex: $userFriendlyMessage'));
      },
      (_) {
        emit(state.copyWith(
          status: HomeStatus.success,
          processingCredexIds: const [],
          message: 'Transaction declined successfully',
        ));
        // Trigger refresh to update dashboard and transactions
        add(const HomeRefreshStarted());
      },
    );
  }

  void _onHomeSearchStarted(HomeSearchStarted event, Emitter<HomeState> emit) {
    final query = event.query.toLowerCase();
    final filteredEntries = state.combinedLedgerEntries.where((entry) {
      return entry.description.toLowerCase().contains(query) ||
             entry.formattedAmount.toLowerCase().contains(query) ||
             entry.counterpartyAccountName.toLowerCase().contains(query);
    }).toList();
    
    final filteredPendingIn = state.pendingInTransactions.where((tx) {
      return tx.counterpartyAccountName.toLowerCase().contains(query) ||
             tx.formattedInitialAmount.toLowerCase().contains(query);
    }).toList();
    
    final filteredPendingOut = state.pendingOutTransactions.where((tx) {
      return tx.counterpartyAccountName.toLowerCase().contains(query) ||
             tx.formattedInitialAmount.toLowerCase().contains(query);
    }).toList();

    emit(state.copyWith(
      searchQuery: query,
      filteredLedgerEntries: filteredEntries,
      filteredPendingInTransactions: filteredPendingIn,
      filteredPendingOutTransactions: filteredPendingOut,
    ));
  }

  Future<void> _onHomeUpgradeTierStarted(HomeUpgradeTierStarted event, Emitter<HomeState> emit) async {
    // Check if update screen is showing - if so, don't proceed with upgrading tier
    if (ServiceLocator.appStateManager.isUpdateScreenShowing) {
      _logger.i('Upgrade tier prevented while update screen is showing');
      return;
    }
    
    emit(state.copyWith(status: HomeStatus.upgradingTier));
    try {
      await upgradeMemberTier(event.sourceAccountId);
      add(const HomeUpgradeTierCompleted());
    } catch (e) {
      add(HomeUpgradeTierFailed(e.toString()));
    }
  }

  void _onHomeUpgradeTierCompleted(HomeUpgradeTierCompleted event, Emitter<HomeState> emit) {
    emit(state.copyWith(
      status: HomeStatus.success,
      message: 'Tier upgrade successful',
    ));
  }

  void _onHomeUpgradeTierFailed(HomeUpgradeTierFailed event, Emitter<HomeState> emit) {
    // Log the actual error for debugging
    _logger.e('Upgrade tier failed: ${event.message}');
    _logger.d('Full error message: ${event.message}');
    
    // Default message
    String userFriendlyMessage = 'Unable to upgrade membership at this time. Please try again later.';
    
    // Check for the error code in the message
    // The error code is embedded in the message as "|code=ERROR_CODE"
    if (event.message.contains('|code=INSUFFICIENT_SECURED_BALANCE')) {
      userFriendlyMessage = 'You don\'t have enough secured balance to upgrade. Your maximum securable balance is too low for this upgrade.';
      _logger.d('Detected INSUFFICIENT_SECURED_BALANCE error code');
    } 
    // Fallback to checking for the error code in JSON format
    else if (event.message.contains('"code": "INSUFFICIENT_SECURED_BALANCE"')) {
      userFriendlyMessage = 'You don\'t have enough secured balance to upgrade. Your maximum securable balance is too low for this upgrade.';
      _logger.d('Detected INSUFFICIENT_SECURED_BALANCE error code in JSON format');
    }
    
    emit(state.copyWith(
      status: HomeStatus.error,
      error: userFriendlyMessage,
    ));
  }

  Future<void> _onHomeFetchPendingTransactions(
    HomeFetchPendingTransactions event,
    Emitter<HomeState> emit,
  ) async {
    // Check if update screen is showing - if so, don't proceed with fetching pending transactions
    if (ServiceLocator.appStateManager.isUpdateScreenShowing) {
      _logger.i('Fetch pending transactions prevented while update screen is showing');
      return;
    }
    
    // Trigger a refresh to update the dashboard and transactions
    add(const HomeRefreshStarted());
  }

  void _onHomeOfferAccepted(HomeOfferAccepted event, Emitter<HomeState> emit) {
    _logger.i('Offer accepted notification received for credexId: ${event.credexId}');
    
    // Check if update screen is showing - if so, don't proceed with processing offer
    if (ServiceLocator.appStateManager.isUpdateScreenShowing) {
      _logger.i('Offer accepted processing prevented while update screen is showing');
      return;
    }
    
    // Add the credexId to processingCredexIds to show "Processing..." state
    // Don't trigger a refresh here since the notification service will handle that
    emit(state.copyWith(
      processingCredexIds: [...state.processingCredexIds, event.credexId],
    ));
  }

  Future<void> _loadLedgerData(Dashboard dashboard, {RefreshSource source = RefreshSource.userAction}) async {
    _logger.d('Loading ledger data for accounts (source: $source)');

    // Check if update screen is showing - if so, don't proceed with loading ledger data
    if (ServiceLocator.appStateManager.isUpdateScreenShowing) {
      _logger.i('Ledger data loading prevented while update screen is showing');
      return;
    }

    final Map<String, List<LedgerEntry>> accountLedgers = {};
    final List<LedgerEntry> allEntries = [];
    bool hasMoreEntries = false;
    final List<String> errors = [];

    try {
      final accounts = dashboard.accounts;
      
      // Phase 1: Load and display cached entries immediately
      _logger.d('Phase 1: Loading cached entries');
      for (final account in accounts) {
        // Load directly from cache for immediate display
        final cachedEntries = await databaseHelper.getLedgerEntries(account.accountID);
        if (cachedEntries.isNotEmpty) {
          _logger.d('Found ${cachedEntries.length} cached entries for account ${account.accountName}');
          accountLedgers[account.accountID] = cachedEntries;
          allEntries.addAll(cachedEntries);
          
          // Emit immediately to show cached data
          final uniqueEntries = _deduplicateAndSortEntries(allEntries);
          add(HomeLedgerLoaded(
            accountLedgers: accountLedgers,
            combinedEntries: uniqueEntries,
            hasMore: true,
            showCompletionToast: false,
          ));
        }
      }

      // Phase 2: Fetch new entries in background (skip for foreground refreshes)
      if (source != RefreshSource.foreground) {
        _logger.d('Phase 2: Fetching new entries from API');
        _totalAccounts = accounts.length;
        _processedAccounts = 0;

        for (final account in accounts) {
          final hasCachedEntries = await databaseHelper.hasLedgerEntries(account.accountID);
          final latestTimestamp = hasCachedEntries 
            ? await databaseHelper.getLatestLedgerTimestamp(account.accountID)
            : null;

          _logger.d('Fetching entries for ${account.accountName} (cached: $hasCachedEntries)');
          
          _processedAccounts++;
          
          // Add delay between accounts to prevent rate limiting
          if (_processedAccounts < _totalAccounts) {
            await Future.delayed(const Duration(milliseconds: 5000)); // Increased delay to 5 seconds
          }

          // Fetch new entries with retry logic
          bool success = false;
          int retryDelay = 5000; // Start with 5 seconds
          int retryCount = 0;
          const maxRetries = 3;

          while (!success && retryCount < maxRetries) {
            try {
              final result = await accountRepository.getLedger(
                accountId: account.accountID,
                afterTimestamp: latestTimestamp,
                limit: hasCachedEntries ? 10 : null, // No limit for initial load
              );

              await result.fold(
                (failure) async {
                  final userFriendlyMessage = ErrorTranslator.translateError(failure);
                  _logger.e('Failed to fetch new entries for account ${account.accountID}: ${failure.toString()}');
                  errors.add('Failed to load new entries for ${account.accountName}: $userFriendlyMessage');
                  success = true; // Don't retry on non-rate-limit failures
                },
                (entries) async {
                  if (entries.isNotEmpty) {
                    _logger.d('Received ${entries.length} new entries for ${account.accountName}');
                    
                    // Update or add to existing entries
                    if (accountLedgers.containsKey(account.accountID)) {
                      accountLedgers[account.accountID]!.addAll(entries);
                    } else {
                      accountLedgers[account.accountID] = entries;
                    }
                    allEntries.addAll(entries);
                    
                    // Check if we got all entries
                    hasMoreEntries = hasCachedEntries && entries.length >= 10;

                    // Emit update with new entries
                    final uniqueEntries = _deduplicateAndSortEntries(allEntries);
                    add(HomeLedgerLoaded(
                      accountLedgers: accountLedgers,
                      combinedEntries: uniqueEntries,
                      hasMore: hasMoreEntries,
                      showCompletionToast: _processedAccounts == _totalAccounts && errors.isEmpty,
                    ));
                  }
                  success = true;
                },
              );
            } catch (e) {
              if (e is RateLimitException) {
                retryCount++;
                if (retryCount < maxRetries) {
                  _logger.w('Rate limit hit (attempt $retryCount of $maxRetries), retrying in ${retryDelay}ms');
                  await Future.delayed(Duration(milliseconds: retryDelay));
                  retryDelay *= 2; // Exponential backoff
                } else {
                  _logger.e('Max retries reached for rate limit');
                  errors.add('Rate limit exceeded for ${account.accountName}');
                  success = true;
                }
              } else {
                final userFriendlyMessage = ErrorTranslator.translateError(e);
                _logger.e('Error fetching entries: $e');
                errors.add('Error loading entries for ${account.accountName}: $userFriendlyMessage');
                success = true;
              }
            }
          }
        }
      } else {
        _logger.d('Skipping API calls for foreground refresh - using cached data only');
        // Just use the cached data we already loaded
        if (allEntries.isNotEmpty) {
          final uniqueEntries = _deduplicateAndSortEntries(allEntries);
          add(HomeLedgerLoaded(
            accountLedgers: accountLedgers,
            combinedEntries: uniqueEntries,
            hasMore: true,
            showCompletionToast: true,
          ));
        } else {
          add(const HomeLedgerLoaded(
            accountLedgers: {},
            combinedEntries: [],
            hasMore: false,
            showCompletionToast: true,
          ));
        }
      }

      // Final error handling
      if (errors.isNotEmpty) {
        add(HomeErrorOccurred(errors.join('\n')));
      } else if (allEntries.isEmpty) {
        add(const HomeLedgerLoaded(
          accountLedgers: {},
          combinedEntries: [],
          hasMore: false,
          showCompletionToast: true,
        ));
      }
    } catch (e, stackTrace) {
      final userFriendlyMessage = ErrorTranslator.translateError(e);
      _logger.e('Error in _loadLedgerData: $e\n$stackTrace');
      add(HomeErrorOccurred('Failed to load ledger data: $userFriendlyMessage'));
    }
  }

  List<LedgerEntry> _deduplicateAndSortEntries(List<LedgerEntry> entries) {
    // Create a map using uniqueIdentifier as key to remove duplicates
    final uniqueEntries = <String, LedgerEntry>{};
    for (final entry in entries) {
      uniqueEntries[entry.uniqueIdentifier] = entry;
    }
    
    // Convert back to list and sort by timestamp
    final sortedEntries = uniqueEntries.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return sortedEntries;
  }
}
