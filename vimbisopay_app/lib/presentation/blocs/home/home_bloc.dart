import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_event.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(const HomeState()) {
    on<HomePageChanged>(_onPageChanged);
    on<HomeDataLoaded>(_onDataLoaded);
    on<HomeLedgerLoaded>(_onLedgerLoaded);
    on<HomeErrorOccurred>(_onErrorOccurred);
  }

  void _onPageChanged(
    HomePageChanged event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(currentPage: event.page));
  }

  void _onDataLoaded(
    HomeDataLoaded event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(
      status: HomeStatus.success,
      dashboard: event.dashboard,
      user: event.user,
      error: null,
    ));
  }

  void _onLedgerLoaded(
    HomeLedgerLoaded event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(
      accountLedgers: event.accountLedgers,
      combinedLedgerEntries: event.combinedEntries,
      hasMoreEntries: event.hasMore,
      error: null,
    ));
  }

  void _onErrorOccurred(
    HomeErrorOccurred event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(
      status: HomeStatus.error,
      error: event.message,
    ));
  }
}
