import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_event.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(const HomeState()) {
    on<HomePageChanged>(_onPageChanged);
    on<HomeDataLoaded>(_onDataLoaded);
    on<HomeLedgerLoaded>(_onLedgerLoaded);
    on<HomeErrorOccurred>(_onErrorOccurred);
    on<HomeLoadStarted>(_onLoadStarted);
    on<HomeRefreshStarted>(_onRefreshStarted);
    on<HomeLoadMoreStarted>(_onLoadMoreStarted);
  }

  void _onPageChanged(
    HomePageChanged event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(currentPage: event.page));
  }

  void _onLoadStarted(
    HomeLoadStarted event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(
      status: HomeStatus.loading,
      error: null,
    ));
  }

  void _onRefreshStarted(
    HomeRefreshStarted event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(
      status: HomeStatus.refreshing,
      error: null,
    ));
  }

  void _onLoadMoreStarted(
    HomeLoadMoreStarted event,
    Emitter<HomeState> emit,
  ) {
    if (!state.hasMoreEntries) return;
    
    emit(state.copyWith(
      status: HomeStatus.loadingMore,
      error: null,
    ));
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
      status: HomeStatus.success,
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
