import 'package:equatable/equatable.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class HomePageChanged extends HomeEvent {
  final int page;

  const HomePageChanged(this.page);

  @override
  List<Object> get props => [page];
}

class HomeLoadStarted extends HomeEvent {
  const HomeLoadStarted();
}

class HomeRefreshStarted extends HomeEvent {
  const HomeRefreshStarted();
}

class HomeLoadMoreStarted extends HomeEvent {
  const HomeLoadMoreStarted();
}

class HomeDataLoaded extends HomeEvent {
  final Dashboard dashboard;
  final User user;
  final List<PendingOffer> pendingInTransactions;
  final List<PendingOffer> pendingOutTransactions;

  const HomeDataLoaded({
    required this.dashboard,
    required this.user,
    this.pendingInTransactions = const [],
    this.pendingOutTransactions = const [],
  });

  @override
  List<Object> get props => [
    dashboard, 
    user, 
    pendingInTransactions, 
    pendingOutTransactions
  ];
}

class HomeLedgerLoaded extends HomeEvent {
  final Map<String, List<LedgerEntry>> accountLedgers;
  final List<LedgerEntry> combinedEntries;
  final bool hasMore;

  const HomeLedgerLoaded({
    required this.accountLedgers,
    required this.combinedEntries,
    required this.hasMore,
  });

  @override
  List<Object> get props => [accountLedgers, combinedEntries, hasMore];
}

class HomeErrorOccurred extends HomeEvent {
  final String? message;

  const HomeErrorOccurred([this.message]);

  @override
  List<Object?> get props => [message];
}