import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/ui_utils.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_event.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_state.dart';
import 'package:vimbisopay_app/presentation/constants/home_constants.dart';
import 'package:vimbisopay_app/presentation/screens/auth_screen.dart';
import 'package:vimbisopay_app/presentation/screens/settings_screen.dart';
import 'package:vimbisopay_app/presentation/widgets/account_card.dart';
import 'package:vimbisopay_app/presentation/widgets/home_action_buttons.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_animation.dart';
import 'package:vimbisopay_app/presentation/widgets/page_indicator.dart';
import 'package:vimbisopay_app/presentation/widgets/transactions_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  final AccountRepository _accountRepository = AccountRepositoryImpl();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  late final HomeBloc _homeBloc;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
    WidgetsBinding.instance.addObserver(this);
    _homeBloc = HomeBloc();
    _loadInitialData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isAuthenticating && mounted) {
      _refreshData();
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.8) {
        _loadMoreLedger();
      }
    });
  }

  Future<void> _loadInitialData() async {
    _homeBloc.add(const HomeLoadStarted());

    try {
      final user = await _databaseHelper.getUser();
      if (user != null) {
        // Get dashboard first to get accounts
        final dashboardResult = await _accountRepository.getMemberDashboardByPhone(user.phone);
        
        await dashboardResult.fold(
          (failure) async {
            _homeBloc.add(HomeErrorOccurred(failure.message));
          },
          (dashboard) async {
            if (dashboard.accounts.isEmpty) {
              _homeBloc.add(const HomeErrorOccurred('No accounts found'));
              return;
            }

            // Extract pending transactions from the first account's dashboard data
            List<PendingOffer> pendingInTransactions = [];
            List<PendingOffer> pendingOutTransactions = [];
            
            if (dashboard.accounts.isNotEmpty) {
              final firstAccount = dashboard.accounts.first;
              pendingInTransactions = firstAccount.pendingInData.data;
              pendingOutTransactions = firstAccount.pendingOutData.data;
            }

            _homeBloc.add(HomeDataLoaded(
              dashboard: dashboard,
              user: user,
              pendingInTransactions: pendingInTransactions,
              pendingOutTransactions: pendingOutTransactions,
            ));

            // Get ledger for all accounts
            final Map<String, List<LedgerEntry>> accountLedgers = {};
            bool hasMoreEntries = false;

            for (final account in dashboard.accounts) {
              final ledgerResult = await _accountRepository.getLedger(
                accountId: account.accountID,
                startRow: 0,
                numRows: HomeConstants.ledgerPageSize,
              );

              ledgerResult.fold(
                (failure) => _homeBloc.add(HomeErrorOccurred(failure.message)),
                (response) {
                  final data = response['data'] as Map<String, dynamic>;
                  final dashboardData = data['dashboard'] as Map<String, dynamic>;
                  final ledger = dashboardData['ledger'] as List;
                  final pagination = dashboardData['pagination'] as Map<String, dynamic>;

                  final entries = ledger
                      .map((entry) => LedgerEntry.fromJson(
                            entry as Map<String, dynamic>,
                            accountId: account.accountID,
                            accountName: account.accountName,
                          ))
                      .toList();
                  
                  accountLedgers[account.accountID] = entries;
                  hasMoreEntries = hasMoreEntries || (pagination['hasMore'] as bool? ?? false);
                },
              );
            }

            // Combine and sort all entries
            final combinedEntries = _updateCombinedLedger(accountLedgers);

            _homeBloc.add(HomeLedgerLoaded(
              accountLedgers: accountLedgers,
              combinedEntries: combinedEntries,
              hasMore: hasMoreEntries,
            ));
          },
        );
      }
    } catch (e) {
      _homeBloc.add(const HomeErrorOccurred('Failed to load data'));
    }
  }

  Future<void> _refreshData() async {
    _homeBloc.add(const HomeRefreshStarted());

    try {
      final user = await _databaseHelper.getUser();
      if (user != null) {
        // Get dashboard first to get accounts
        final dashboardResult = await _accountRepository.getMemberDashboardByPhone(user.phone);
        
        await dashboardResult.fold(
          (failure) async {
            _homeBloc.add(HomeErrorOccurred(failure.message));
          },
          (dashboard) async {
            if (dashboard.accounts.isEmpty) {
              _homeBloc.add(const HomeErrorOccurred('No accounts found'));
              return;
            }

            // Extract pending transactions from the first account's dashboard data
            List<PendingOffer> pendingInTransactions = [];
            List<PendingOffer> pendingOutTransactions = [];
            
            if (dashboard.accounts.isNotEmpty) {
              final firstAccount = dashboard.accounts.first;
              pendingInTransactions = firstAccount.pendingInData.data;
              pendingOutTransactions = firstAccount.pendingOutData.data;
            }

            _homeBloc.add(HomeDataLoaded(
              dashboard: dashboard,
              user: user,
              pendingInTransactions: pendingInTransactions,
              pendingOutTransactions: pendingOutTransactions,
            ));

            // Get ledger for all accounts
            final Map<String, List<LedgerEntry>> accountLedgers = {};
            bool hasMoreEntries = false;

            for (final account in dashboard.accounts) {
              final ledgerResult = await _accountRepository.getLedger(
                accountId: account.accountID,
                startRow: 0,
                numRows: HomeConstants.ledgerPageSize,
              );

              ledgerResult.fold(
                (failure) => _homeBloc.add(HomeErrorOccurred(failure.message)),
                (response) {
                  final data = response['data'] as Map<String, dynamic>;
                  final dashboardData = data['dashboard'] as Map<String, dynamic>;
                  final ledger = dashboardData['ledger'] as List;
                  final pagination = dashboardData['pagination'] as Map<String, dynamic>;

                  final entries = ledger
                      .map((entry) => LedgerEntry.fromJson(
                            entry as Map<String, dynamic>,
                            accountId: account.accountID,
                            accountName: account.accountName,
                          ))
                      .toList();
                  
                  accountLedgers[account.accountID] = entries;
                  hasMoreEntries = hasMoreEntries || (pagination['hasMore'] as bool? ?? false);
                },
              );
            }

            // Combine and sort all entries
            final combinedEntries = _updateCombinedLedger(accountLedgers);

            _homeBloc.add(HomeLedgerLoaded(
              accountLedgers: accountLedgers,
              combinedEntries: combinedEntries,
              hasMore: hasMoreEntries,
            ));
          },
        );
      }
    } catch (e) {
      _homeBloc.add(const HomeErrorOccurred('Failed to refresh data'));
    }
  }

  Future<void> _loadMoreLedger() async {
    final state = _homeBloc.state;
    if (state.dashboard == null || !state.hasMoreEntries) return;
    
    _homeBloc.add(const HomeLoadMoreStarted());

    try {
      final Map<String, List<LedgerEntry>> updatedLedgers = Map.from(state.accountLedgers);
      bool hasMoreEntries = false;

      for (final account in state.dashboard!.accounts) {
        final startRow = state.accountLedgers[account.accountID]?.length ?? 0;
        
        final result = await _accountRepository.getLedger(
          accountId: account.accountID,
          startRow: startRow,
          numRows: HomeConstants.ledgerPageSize,
        );

        result.fold(
          (failure) => _homeBloc.add(HomeErrorOccurred(failure.message)),
          (response) {
            final data = response['data'] as Map<String, dynamic>;
            final dashboardData = data['dashboard'] as Map<String, dynamic>;
            final ledger = dashboardData['ledger'] as List;
            final pagination = dashboardData['pagination'] as Map<String, dynamic>;

            final entries = ledger
                .map((entry) => LedgerEntry.fromJson(
                      entry as Map<String, dynamic>,
                      accountId: account.accountID,
                      accountName: account.accountName,
                    ))
                .toList();
            
            updatedLedgers.update(
              account.accountID,
              (list) => list..addAll(entries),
              ifAbsent: () => entries,
            );
            
            hasMoreEntries = hasMoreEntries || (pagination['hasMore'] as bool? ?? false);
          },
        );
      }

      final combinedEntries = _updateCombinedLedger(updatedLedgers);

      _homeBloc.add(HomeLedgerLoaded(
        accountLedgers: updatedLedgers,
        combinedEntries: combinedEntries,
        hasMore: hasMoreEntries,
      ));
    } catch (e) {
      _homeBloc.add(const HomeErrorOccurred('Failed to load more entries'));
    }
  }

  List<LedgerEntry> _updateCombinedLedger(Map<String, List<LedgerEntry>> accountLedgers) {
    final allEntries = accountLedgers.values.expand((entries) => entries).toList();
    allEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allEntries;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _homeBloc.close();
    super.dispose();
  }

  PreferredSize _buildAppBar(HomeState state) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(HomeConstants.appBarHeight),
      child: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        leadingWidth: 80,
        toolbarHeight: HomeConstants.appBarHeight,
        leading: _buildUserAvatar(state),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _navigateToSettings(),
              tooltip: 'Settings',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(HomeState state) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 12.0,
        top: 12.0,
        bottom: 12.0,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: state.dashboard != null
                ? Text(
                    UIUtils.getInitials(
                      state.dashboard!.firstname,
                      state.dashboard!.lastname,
                    ),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : const Icon(
                    Icons.person_outline,
                    color: AppColors.primary,
                  ),
          ),
          if (state.user != null) _buildTierBadge(state),
        ],
      ),
    );
  }

  Widget _buildTierBadge(HomeState state) {
    return Positioned(
      right: -8,
      bottom: -8,
      child: Container(
        padding: const EdgeInsets.only(
          left: 8,
          right: 8,
          top: 4,
          bottom: 6,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.surface,
            width: 2,
          ),
        ),
        child: Text(
          state.user!.tier.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAccountsSection(HomeState state) {
    return Column(
      children: [
        const SizedBox(height: HomeConstants.defaultPadding),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * HomeConstants.accountCardHeight,
          ),
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => _homeBloc.add(HomePageChanged(index)),
            itemCount: state.dashboard!.accounts.length,
            itemBuilder: (context, index) => AccountCard(
              account: state.dashboard!.accounts[index],
            ),
          ),
        ),
        if (state.dashboard!.accounts.length > 1)
          Padding(
            padding: const EdgeInsets.all(HomeConstants.defaultPadding),
            child: PageIndicator(
              count: state.dashboard!.accounts.length,
              currentPage: state.currentPage,
            ),
          ),
      ],
    );
  }

  Widget _buildScrollableContent(HomeState state) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            if (state.dashboard != null) _buildAccountsSection(state),
            const TransactionsList(),
          ],
        ),
      ),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _homeBloc,
      child: BlocConsumer<HomeBloc, HomeState>(
        listener: (context, state) async {
          if (state.status == HomeStatus.loading && 
              state.user != null && 
              !_isAuthenticating) {
            _isAuthenticating = true;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AuthScreen(user: state.user!),
              ),
            );
            _isAuthenticating = false;
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: _buildAppBar(state),
            body: SafeArea(
              child: state.isInitialLoading
                  ? const LoadingAnimation(size: 100)
                  : _buildScrollableContent(state),
            ),
            bottomNavigationBar: HomeActionButtons(
              accounts: state.dashboard?.accounts,
              onSendTap: () {
                // TODO: Implement send money
              },
              accountRepository: _accountRepository,
            ),
          );
        },
      ),
    );
  }
}
