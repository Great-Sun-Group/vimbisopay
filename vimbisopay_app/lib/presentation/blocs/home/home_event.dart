import 'package:equatable/equatable.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/domain/entities/credex_request.dart';

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

class HomeLoadPendingTransactions extends HomeEvent {
  final List<PendingOffer> pendingInTransactions;
  final List<PendingOffer> pendingOutTransactions;
  const HomeLoadPendingTransactions({
    this.pendingInTransactions = const [],
    this.pendingOutTransactions = const [],
  });
}

class HomeDataLoaded extends HomeEvent {
  final Dashboard dashboard;
  final List<PendingOffer> pendingInTransactions;
  final List<PendingOffer> pendingOutTransactions;
  final bool keepLoading;

  const HomeDataLoaded({
    required this.dashboard,
    this.pendingInTransactions = const [],
    this.pendingOutTransactions = const [],
    this.keepLoading = false,
  });

  @override
  List<Object> get props => [
        dashboard,
        pendingInTransactions,
        pendingOutTransactions,
        keepLoading,
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

class HomeAcceptCredexBulkStarted extends HomeEvent {
  final List<String> credexIds;

  const HomeAcceptCredexBulkStarted(this.credexIds);

  @override
  List<Object> get props => [credexIds];
}

class HomeAcceptCredexBulkCompleted extends HomeEvent {
  const HomeAcceptCredexBulkCompleted();
}

class HomeCancelCredexStarted extends HomeEvent {
  final String credexId;

  const HomeCancelCredexStarted(this.credexId);

  @override
  List<Object> get props => [credexId];
}

class HomeCancelCredexCompleted extends HomeEvent {
  const HomeCancelCredexCompleted();
}

class CreateCredexEvent extends HomeEvent {
  final CredexRequest request;

  const CreateCredexEvent(this.request);

  @override
  List<Object> get props => [request];
}

class HomeFetchPendingTransactions extends HomeEvent {
  final List<PendingOffer> pendingInTransactions;
  final List<PendingOffer> pendingOutTransactions;
  const HomeFetchPendingTransactions({
    this.pendingInTransactions = const [],
    this.pendingOutTransactions = const [],
  });
}

class HomeRegisterNotificationToken extends HomeEvent {
  final String token;

  const HomeRegisterNotificationToken(this.token);

  @override
  List<Object> get props => [token];
}
