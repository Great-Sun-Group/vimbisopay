import 'package:equatable/equatable.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';

enum HomeStatus {
  initial,
  loading,
  success,
  error,
  refreshing,
  loadingMore,
  acceptingCredex,
}

class HomeState extends Equatable {
  final HomeStatus status;
  final Dashboard? dashboard;
  final Map<String, List<LedgerEntry>> accountLedgers;
  final List<LedgerEntry> combinedLedgerEntries;
  final List<PendingOffer> pendingInTransactions;
  final List<PendingOffer> pendingOutTransactions;
  final List<String> processingCredexIds;
  final bool hasMoreEntries;
  final int currentPage;
  final String? error;

  const HomeState({
    this.status = HomeStatus.initial,
    this.dashboard,
    this.accountLedgers = const {},
    this.combinedLedgerEntries = const [],
    this.pendingInTransactions = const [],
    this.pendingOutTransactions = const [],
    this.processingCredexIds = const [],
    this.hasMoreEntries = false,
    this.currentPage = 0,
    this.error,
  });

  bool get isInitialLoading => status == HomeStatus.loading && dashboard == null;
  bool get isRefreshing => status == HomeStatus.refreshing;
  bool get isLoadingMore => status == HomeStatus.loadingMore;
  bool get isAcceptingCredex => status == HomeStatus.acceptingCredex;
  bool get hasError => status == HomeStatus.error;

  bool get hasPendingTransactions => 
      pendingInTransactions.isNotEmpty || pendingOutTransactions.isNotEmpty;

  bool isProcessingTransaction(String credexId) => 
      processingCredexIds.contains(credexId);

  HomeState copyWith({
    HomeStatus? status,
    Dashboard? dashboard,
    Map<String, List<LedgerEntry>>? accountLedgers,
    List<LedgerEntry>? combinedLedgerEntries,
    List<PendingOffer>? pendingInTransactions,
    List<PendingOffer>? pendingOutTransactions,
    List<String>? processingCredexIds,
    bool? hasMoreEntries,
    int? currentPage,
    String? error,
  }) {
    return HomeState(
      status: status ?? this.status,
      dashboard: dashboard ?? this.dashboard,
      accountLedgers: accountLedgers ?? this.accountLedgers,
      combinedLedgerEntries: combinedLedgerEntries ?? this.combinedLedgerEntries,
      pendingInTransactions: pendingInTransactions ?? this.pendingInTransactions,
      pendingOutTransactions: pendingOutTransactions ?? this.pendingOutTransactions,
      processingCredexIds: processingCredexIds ?? this.processingCredexIds,
      hasMoreEntries: hasMoreEntries ?? this.hasMoreEntries,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        status,
        dashboard,
        accountLedgers,
        combinedLedgerEntries,
        pendingInTransactions,
        pendingOutTransactions,
        processingCredexIds,
        hasMoreEntries,
        currentPage,
        error,
      ];
}
