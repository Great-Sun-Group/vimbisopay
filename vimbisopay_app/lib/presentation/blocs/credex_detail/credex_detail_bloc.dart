import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/presentation/blocs/credex_detail/credex_detail_event.dart';
import 'package:vimbisopay_app/presentation/blocs/credex_detail/credex_detail_state.dart';

class CredexDetailBloc extends Bloc<CredexDetailEvent, CredexDetailState> {
  final AccountRepository accountRepository;

  CredexDetailBloc({
    required this.accountRepository,
  }) : super(const CredexDetailState()) {
    on<CredexDetailLoadStarted>(_onLoadStarted);
    on<CredexDetailRefreshStarted>(_onRefreshStarted);
    on<CredexDetailAcceptStarted>(_onAcceptStarted);
    on<CredexDetailDeclineStarted>(_onDeclineStarted);
    on<CredexDetailCancelStarted>(_onCancelStarted);
  }

  Future<void> _onLoadStarted(
    CredexDetailLoadStarted event,
    Emitter<CredexDetailState> emit,
  ) async {
    Logger.data('[CREDEX_DETAIL_BLOC] Loading credex detail for ID: ${event.credexId}');
    
    emit(state.copyWith(
      status: CredexDetailStatus.loading,
      credexId: event.credexId,
      error: null,
      message: null,
    ));

    try {
      final result = await accountRepository.getCredexDetail(
        credexId: event.credexId,
      );

      result.fold(
        (failure) {
          Logger.error('[CREDEX_DETAIL_BLOC] Failed to load credex detail', failure.message);
          emit(state.copyWith(
            status: CredexDetailStatus.error,
            error: failure.message,
          ));
        },
        (credexDetail) {
          Logger.data('[CREDEX_DETAIL_BLOC] Successfully loaded credex detail');
          emit(state.copyWith(
            status: CredexDetailStatus.success,
            credexDetail: credexDetail,
            error: null,
          ));
        },
      );
    } catch (e, stackTrace) {
      Logger.error('[CREDEX_DETAIL_BLOC] Unexpected error loading credex detail', e, stackTrace);
      emit(state.copyWith(
        status: CredexDetailStatus.error,
        error: 'An unexpected error occurred while loading credex details',
      ));
    }
  }

  Future<void> _onRefreshStarted(
    CredexDetailRefreshStarted event,
    Emitter<CredexDetailState> emit,
  ) async {
    Logger.data('[CREDEX_DETAIL_BLOC] Refreshing credex detail for ID: ${event.credexId}');
    
    // Keep current data while refreshing
    emit(state.copyWith(
      status: CredexDetailStatus.loading,
      error: null,
      message: null,
    ));

    try {
      final result = await accountRepository.getCredexDetail(
        credexId: event.credexId,
      );

      result.fold(
        (failure) {
          Logger.error('[CREDEX_DETAIL_BLOC] Failed to refresh credex detail', failure.message);
          emit(state.copyWith(
            status: CredexDetailStatus.error,
            error: failure.message,
          ));
        },
        (credexDetail) {
          Logger.data('[CREDEX_DETAIL_BLOC] Successfully refreshed credex detail');
          emit(state.copyWith(
            status: CredexDetailStatus.success,
            credexDetail: credexDetail,
            error: null,
            message: 'Credex details updated',
          ));
        },
      );
    } catch (e, stackTrace) {
      Logger.error('[CREDEX_DETAIL_BLOC] Unexpected error refreshing credex detail', e, stackTrace);
      emit(state.copyWith(
        status: CredexDetailStatus.error,
        error: 'An unexpected error occurred while refreshing credex details',
      ));
    }
  }

  Future<void> _onAcceptStarted(
    CredexDetailAcceptStarted event,
    Emitter<CredexDetailState> emit,
  ) async {
    Logger.data('[CREDEX_DETAIL_BLOC] Accepting credex: ${event.credexId}');
    
    emit(state.copyWith(
      status: CredexDetailStatus.accepting,
      error: null,
      message: null,
    ));

    try {
      final result = await accountRepository.acceptCredex(event.credexId);

      result.fold(
        (failure) {
          Logger.error('[CREDEX_DETAIL_BLOC] Failed to accept credex', failure.message);
          emit(state.copyWith(
            status: CredexDetailStatus.error,
            error: failure.message,
          ));
        },
        (success) {
          Logger.data('[CREDEX_DETAIL_BLOC] Successfully accepted credex');
          emit(state.copyWith(
            status: CredexDetailStatus.success,
            message: 'Credex accepted successfully',
          ));
          
          // Refresh the credex details to get updated status
          add(CredexDetailRefreshStarted(event.credexId));
        },
      );
    } catch (e, stackTrace) {
      Logger.error('[CREDEX_DETAIL_BLOC] Unexpected error accepting credex', e, stackTrace);
      emit(state.copyWith(
        status: CredexDetailStatus.error,
        error: 'An unexpected error occurred while accepting the credex',
      ));
    }
  }

  Future<void> _onDeclineStarted(
    CredexDetailDeclineStarted event,
    Emitter<CredexDetailState> emit,
  ) async {
    Logger.data('[CREDEX_DETAIL_BLOC] Declining credex: ${event.credexId}');
    
    emit(state.copyWith(
      status: CredexDetailStatus.declining,
      error: null,
      message: null,
    ));

    try {
      final result = await accountRepository.declineCredex(event.credexId);

      result.fold(
        (failure) {
          Logger.error('[CREDEX_DETAIL_BLOC] Failed to decline credex', failure.message);
          emit(state.copyWith(
            status: CredexDetailStatus.error,
            error: failure.message,
          ));
        },
        (success) {
          Logger.data('[CREDEX_DETAIL_BLOC] Successfully declined credex');
          emit(state.copyWith(
            status: CredexDetailStatus.success,
            message: 'Credex declined successfully',
          ));
          
          // Refresh the credex details to get updated status
          add(CredexDetailRefreshStarted(event.credexId));
        },
      );
    } catch (e, stackTrace) {
      Logger.error('[CREDEX_DETAIL_BLOC] Unexpected error declining credex', e, stackTrace);
      emit(state.copyWith(
        status: CredexDetailStatus.error,
        error: 'An unexpected error occurred while declining the credex',
      ));
    }
  }

  Future<void> _onCancelStarted(
    CredexDetailCancelStarted event,
    Emitter<CredexDetailState> emit,
  ) async {
    Logger.data('[CREDEX_DETAIL_BLOC] Cancelling credex: ${event.credexId}');
    
    emit(state.copyWith(
      status: CredexDetailStatus.cancelling,
      error: null,
      message: null,
    ));

    try {
      final result = await accountRepository.cancelCredex(event.credexId);

      result.fold(
        (failure) {
          Logger.error('[CREDEX_DETAIL_BLOC] Failed to cancel credex', failure.message);
          emit(state.copyWith(
            status: CredexDetailStatus.error,
            error: failure.message,
          ));
        },
        (success) {
          Logger.data('[CREDEX_DETAIL_BLOC] Successfully cancelled credex');
          emit(state.copyWith(
            status: CredexDetailStatus.success,
            message: 'Credex cancelled successfully',
          ));
          
          // Refresh the credex details to get updated status
          add(CredexDetailRefreshStarted(event.credexId));
        },
      );
    } catch (e, stackTrace) {
      Logger.error('[CREDEX_DETAIL_BLOC] Unexpected error cancelling credex', e, stackTrace);
      emit(state.copyWith(
        status: CredexDetailStatus.error,
        error: 'An unexpected error occurred while cancelling the credex',
      ));
    }
  }
}
