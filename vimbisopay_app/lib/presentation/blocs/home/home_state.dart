import 'package:equatable/equatable.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart';

enum HomeStatus {
  initial,
  loading,
  loadingMore,
  refreshing,
  success,
  error,
}

class HomeState extends Equatable {
  final HomeStatus status;
  final Dashboard? dashboard;
  final User? user;
  final Map<String, List<LedgerEntry>> accountLedgers;
  final List<LedgerEntry> combinedLedgerEntries;
  final List<PendingOffer> pendingInTransactions;
  final List<PendingOffer> pendingOutTransactions;
  final bool hasMoreEntries;
  final String? error;
  final int currentPage;

  const HomeState({
    this.status = HomeStatus.initial,
    this.dashboard,
    this.user,
    this.accountLedgers = const {},
    this.combinedLedgerEntries = const [],
    this.pendingInTransactions = const [],
    this.pendingOutTransactions = const [],
    this.hasMoreEntries = true,
    this.error,
    this.currentPage = 0,
  });

  bool get isInitialLoading => status == HomeStatus.loading && combinedLedgerEntries.isEmpty;
  bool get isRefreshing => status == HomeStatus.refreshing;
  bool get isLoadingMore => status == HomeStatus.loadingMore;
  bool get hasError => error != null;
  bool get hasPendingTransactions => pendingInTransactions.isNotEmpty || pendingOutTransactions.isNotEmpty;

  HomeState copyWith({
    HomeStatus? status,
    Dashboard? dashboard,
    User? user,
    Map<String, List<LedgerEntry>>? accountLedgers,
    List<LedgerEntry>? combinedLedgerEntries,
    List<PendingOffer>? pendingInTransactions,
    List<PendingOffer>? pendingOutTransactions,
    bool? hasMoreEntries,
    String? error,
    int? currentPage,
  }) {
    return HomeState(
      status: status ?? this.status,
      dashboard: dashboard ?? this.dashboard,
      user: user ?? this.user,
      accountLedgers: accountLedgers ?? this.accountLedgers,
      combinedLedgerEntries: combinedLedgerEntries ?? this.combinedLedgerEntries,
      pendingInTransactions: pendingInTransactions ?? this.pendingInTransactions,
      pendingOutTransactions: pendingOutTransactions ?? this.pendingOutTransactions,
      hasMoreEntries: hasMoreEntries ?? this.hasMoreEntries,
      error: error,  // Intentionally not using ?? to allow setting to null
      currentPage: currentPage ?? this.currentPage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        dashboard,
        user,
        accountLedgers,
        combinedLedgerEntries,
        pendingInTransactions,
        pendingOutTransactions,
        hasMoreEntries,
        error,
        currentPage,
      ];
}
