import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vimbisopay_app/infrastructure/services/security_service.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/presentation/screens/auth_screen.dart';
import 'package:vimbisopay_app/presentation/screens/settings_screen.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';
import 'package:vimbisopay_app/application/usecases/get_member_dashboard.dart';
import 'package:vimbisopay_app/application/usecases/get_ledger.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final SecurityService _securityService = SecurityService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final AccountRepository _accountRepository = AccountRepositoryImpl();
  late final GetMemberDashboard _getMemberDashboard;
  late final GetLedger _getLedger;
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  final DateFormat _dateFormat = DateFormat('MMM d, y h:mm a');
  
  bool _isCheckingAuth = false;
  bool _isLoadingDashboard = false;
  bool _isLoadingLedger = false;
  bool _isLoadingMoreLedger = false;
  bool _hasMoreLedgerEntries = true;
  Dashboard? _dashboard;
  User? _user;
  String? _error;
  Map<String, List<LedgerEntry>> _accountLedgers = {};
  List<LedgerEntry>? _combinedLedgerEntries;
  int _currentPage = 0;
  static const int _ledgerPageSize = 20;

  @override
  void initState() {
    super.initState();
    _getMemberDashboard = GetMemberDashboard(_accountRepository);
    _getLedger = GetLedger(_accountRepository);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    _checkAuthentication();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8 &&
        _hasMoreLedgerEntries &&
        !_isLoadingMoreLedger) {
      _loadMoreLedgerEntries();
    }
  }

  Future<void> _loadMoreLedgerEntries() async {
    if (_isLoadingMoreLedger || _dashboard == null || !_hasMoreLedgerEntries) return;

    setState(() {
      _isLoadingMoreLedger = true;
    });

    try {
      final futures = _dashboard!.accounts.map((account) async {
        final startRow = _accountLedgers[account.accountID]?.length ?? 0;
        final result = await _getLedger.execute(GetLedgerParams(
          accountId: account.accountID,
          startRow: startRow,
          numRows: _ledgerPageSize,
        ));

        return result.fold(
          (failure) => null,
          (response) {
            final data = response['data'];
            final dashboard = data['dashboard'];
            final List<dynamic> newEntries = dashboard['ledger'];
            final pagination = dashboard['pagination'];
            
            return {
              'accountId': account.accountID,
              'entries': newEntries.map((entry) => LedgerEntry.fromJson(entry)).toList(),
              'hasMore': pagination['hasMore'] ?? false,
            };
          },
        );
      });

      final results = await Future.wait(futures);
      bool hasMore = false;

      if (mounted) {
        setState(() {
          for (final result in results) {
            if (result != null) {
              final accountId = result['accountId'] as String;
              final entries = result['entries'] as List<LedgerEntry>;
              final accountHasMore = result['hasMore'] as bool;
              
              _accountLedgers.update(
                accountId,
                (list) => list..addAll(entries),
                ifAbsent: () => entries,
              );
              
              hasMore = hasMore || accountHasMore;
            }
          }

          _hasMoreLedgerEntries = hasMore;
          _isLoadingMoreLedger = false;
          _updateCombinedLedger();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load more ledger entries';
          _isLoadingMoreLedger = false;
        });
      }
    }
  }

  void _updateCombinedLedger() {
    final allEntries = _accountLedgers.values.expand((entries) => entries).toList();
    allEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _combinedLedgerEntries = allEntries;
  }

  Future<void> _checkAuthentication() async {
    if (_isCheckingAuth) return;
    
    setState(() {
      _isCheckingAuth = true;
      _error = null;
    });

    try {
      final requiresAuth = await _securityService.requiresAuthentication();
      if (requiresAuth && mounted) {
        final user = await _databaseHelper.getUser();
        if (user != null && mounted) {
          setState(() => _user = user);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AuthScreen(user: user),
            ),
          );
          _fetchDashboard();
        } else if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        final user = await _databaseHelper.getUser();
        if (user != null && mounted) {
          setState(() => _user = user);
          _fetchDashboard();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    }
  }

  Future<void> _fetchDashboard() async {
    if (!mounted) return;

    setState(() {
      _isLoadingDashboard = true;
      _error = null;
    });

    try {
      final user = await _databaseHelper.getUser();
      if (user != null) {
        final result = await _getMemberDashboard.execute(user.phone);
        
        result.fold(
          (failure) {
            if (mounted) {
              setState(() {
                _error = failure.message;
                _isLoadingDashboard = false;
              });
            }
          },
          (dashboard) {
            if (mounted) {
              setState(() {
                _dashboard = dashboard;
                _isLoadingDashboard = false;
              });
              _fetchLedger();
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load dashboard';
          _isLoadingDashboard = false;
        });
      }
    }
  }

  Future<void> _fetchLedger() async {
    if (!mounted || _dashboard == null) return;

    setState(() {
      _isLoadingLedger = true;
      _accountLedgers.clear();
    });

    try {
      final futures = _dashboard!.accounts.map((account) async {
        final result = await _getLedger.execute(GetLedgerParams(
          accountId: account.accountID,
          startRow: 0,
          numRows: _ledgerPageSize,
        ));

        return result.fold(
          (failure) => null,
          (response) {
            final data = response['data'];
            final dashboard = data['dashboard'];
            final List<dynamic> ledger = dashboard['ledger'];
            final pagination = dashboard['pagination'];
            
            return {
              'accountId': account.accountID,
              'entries': ledger.map((entry) => LedgerEntry.fromJson(entry)).toList(),
              'hasMore': pagination['hasMore'] ?? false,
            };
          },
        );
      });

      final results = await Future.wait(futures);
      bool hasMore = false;

      if (mounted) {
        setState(() {
          for (final result in results) {
            if (result != null) {
              final accountId = result['accountId'] as String;
              final entries = result['entries'] as List<LedgerEntry>;
              final accountHasMore = result['hasMore'] as bool;
              
              _accountLedgers[accountId] = entries;
              hasMore = hasMore || accountHasMore;
            }
          }

          _hasMoreLedgerEntries = hasMore;
          _isLoadingLedger = false;
          _updateCombinedLedger();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load ledger';
          _isLoadingLedger = false;
        });
      }
    }
  }

  void _onSettingsTap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _retryFetch() {
    _fetchDashboard();
  }

  String _getInitials(String firstname, String lastname) {
    return '${firstname.isNotEmpty ? firstname[0] : ''}${lastname.isNotEmpty ? lastname[0] : ''}'.toUpperCase();
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required VoidCallback onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerSection() {
    if (_error != null) {
      return _buildEmptyState(
        icon: Icons.error_outline_rounded,
        message: 'Unable to load transactions.\nPlease check your connection and try again.',
        onRetry: _retryFetch,
      );
    }

    if (_isLoadingLedger) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_combinedLedgerEntries == null || _combinedLedgerEntries!.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_rounded,
        message: 'No transactions yet.\nYour transaction history will appear here.',
        onRetry: _retryFetch,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: _combinedLedgerEntries!.length + (_isLoadingMoreLedger ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _combinedLedgerEntries!.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                );
              }

              final entry = _combinedLedgerEntries![index];
              final isNegative = entry.amount < 0;
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isNegative 
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  child: Icon(
                    isNegative ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isNegative ? Colors.red : Colors.green,
                  ),
                ),
                title: Text(
                  entry.description,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.counterpartyAccountName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      _dateFormat.format(entry.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                trailing: Text(
                  entry.formattedAmount,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isNegative ? Colors.red : Colors.green,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  PreferredSize _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        leadingWidth: 80,
        toolbarHeight: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0, top: 12.0, bottom: 12.0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: _dashboard != null 
                  ? Text(
                      _getInitials(_dashboard!.firstname, _dashboard!.lastname),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : Icon(
                      Icons.person_outline,
                      color: AppColors.primary,
                    ),
              ),
              if (_user != null)
                Positioned(
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
                      _user!.tier.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _onSettingsTap,
              tooltip: 'Settings',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(DashboardAccount account) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      account.accountName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Tier Limit',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\$10 USD/day',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text(
                    '@',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      account.accountHandle,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Net Balance',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            account.balanceData.netCredexAssetsInDefaultDenom,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Receivables',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    account.balanceData.unsecuredBalances.totalReceivables,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Payables',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    account.balanceData.unsecuredBalances.totalPayables,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  // TODO: Implement send money
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.payments_outlined,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Send',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  // TODO: Implement receive money
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Receive',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = 72.0;
    final safePadding = MediaQuery.of(context).padding;
    final availableHeight = screenHeight - appBarHeight - safePadding.top - safePadding.bottom;
    final viewPagerHeight = availableHeight * 0.45;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.1),
            Colors.black,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (_isCheckingAuth || _isLoadingDashboard)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                )
              else if (_error != null)
                Expanded(
                  child: _buildEmptyState(
                    icon: Icons.cloud_off_rounded,
                    message: 'Unable to connect to our servers.\nPlease check your connection and try again.',
                    onRetry: _retryFetch,
                  ),
                )
              else if (_dashboard != null)
                Expanded(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        controller: _scrollController,
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            SizedBox(
                              height: viewPagerHeight,
                              child: PageView.builder(
                                controller: _pageController,
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentPage = index;
                                  });
                                },
                                itemCount: _dashboard!.accounts.length,
                                itemBuilder: (context, index) {
                                  return _buildAccountCard(_dashboard!.accounts[index]);
                                },
                              ),
                            ),
                            if (_dashboard!.accounts.length > 1)
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    _dashboard!.accounts.length,
                                    (index) => Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _currentPage == index
                                            ? AppColors.primary
                                            : AppColors.primary.withOpacity(0.2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_isLoadingLedger)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                  ),
                                ),
                              )
                            else
                              _buildLedgerSection(),
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _buildActionButtons(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
