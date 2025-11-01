import 'package:vimbisopay_app/domain/entities/dashboard.dart';

/// Centralized service for managing dashboard data and providing account-related queries.
/// This service acts as a single source of truth for account ownership, types, and dashboard data.
class DashboardService {
  static final DashboardService _instance = DashboardService._internal();
  factory DashboardService() => _instance;
  DashboardService._internal();

  static DashboardService get instance => _instance;
  static DashboardService get I => _instance;

  Dashboard? _currentDashboard;

  /// Update the centralized dashboard data
  /// Should be called whenever dashboard data is refreshed from any API call
  void updateDashboard(Dashboard? dashboard) {
    _currentDashboard = dashboard;
  }

  /// Clear the current dashboard data
  /// Useful for logout or when dashboard becomes stale
  void clearDashboard() {
    _currentDashboard = null;
  }

  /// Get the current dashboard data
  Dashboard? get dashboard => _currentDashboard;

  /// Check if dashboard data is available
  bool get hasDashboardData => _currentDashboard != null;



  /// Check if a specific account is owned by the current member
  bool isAccountOwned(String accountId) {
    if (_currentDashboard == null) return false;

    return _currentDashboard!.accounts
        .any((account) => account.accountID == accountId && account.isOwnedAccount);
  }

  /// Get a specific account by ID
  DashboardAccount? getAccountById(String accountId) {
    if (_currentDashboard == null) return null;

    try {
      return _currentDashboard!.accounts.firstWhere(
        (account) => account.accountID == accountId,
      );
    } catch (e) {
      return null;
    }
  }



  /// Get current member information
  DashboardMember? get currentMember => _currentDashboard?.member;

  /// Get current member ID
  String? get currentMemberId => _currentDashboard?.member.memberID;

  /// Get all accounts (owned and unowned by current member)
  List<DashboardAccount> get allAccounts => _currentDashboard?.accounts ?? [];

  /// Get count of owned accounts
  int get ownedAccountsCount => _currentDashboard?.accounts
      .where((account) => account.isOwnedAccount)
      .length ?? 0;
}
