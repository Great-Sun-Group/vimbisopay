import 'package:equatable/equatable.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';

enum HomeStatus {
  initial,
  loading,
  loadingMore,
  success,
  error,
}

class HomeState extends Equatable {
  final HomeStatus status;
  final Dashboard? dashboard;
  final User? user;
  final Map<String, List<LedgerEntry>> accountLedgers;
  final List<LedgerEntry> combinedLedgerEntries;
  final bool hasMoreEntries;
  final String? error;
  final int currentPage;

  const HomeState({
    this.status = HomeStatus.initial,
    this.dashboard,
    this.user,
    this.accountLedgers = const {},
    this.combinedLedgerEntries = const [],
    this.hasMoreEntries = true,
    this.error,
    this.currentPage = 0,
  });

  HomeState copyWith({
    HomeStatus? status,
    Dashboard? dashboard,
    User? user,
    Map<String, List<LedgerEntry>>? accountLedgers,
    List<LedgerEntry>? combinedLedgerEntries,
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
      hasMoreEntries: hasMoreEntries ?? this.hasMoreEntries,
      error: error ?? this.error,
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
        hasMoreEntries,
        error,
        currentPage,
      ];
}
