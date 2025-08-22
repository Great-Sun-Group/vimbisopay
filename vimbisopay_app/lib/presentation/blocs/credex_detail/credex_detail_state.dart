import 'package:equatable/equatable.dart';
import 'package:vimbisopay_app/domain/entities/credex_detail.dart';

enum CredexDetailStatus {
  initial,
  loading,
  success,
  error,
  accepting,
  declining,
  cancelling,
}

class CredexDetailState extends Equatable {
  final CredexDetailStatus status;
  final CredexDetail? credexDetail;
  final String? error;
  final String? message;
  final String? credexId;

  const CredexDetailState({
    this.status = CredexDetailStatus.initial,
    this.credexDetail,
    this.error,
    this.message,
    this.credexId,
  });

  CredexDetailState copyWith({
    CredexDetailStatus? status,
    CredexDetail? credexDetail,
    String? error,
    String? message,
    String? credexId,
  }) {
    return CredexDetailState(
      status: status ?? this.status,
      credexDetail: credexDetail ?? this.credexDetail,
      error: error,
      message: message,
      credexId: credexId ?? this.credexId,
    );
  }

  bool get isLoading => status == CredexDetailStatus.loading;
  bool get isAccepting => status == CredexDetailStatus.accepting;
  bool get isDeclining => status == CredexDetailStatus.declining;
  bool get isCancelling => status == CredexDetailStatus.cancelling;
  bool get isProcessing => isAccepting || isDeclining || isCancelling;
  bool get hasError => status == CredexDetailStatus.error;
  bool get hasData => credexDetail != null;

  @override
  List<Object?> get props => [
        status,
        credexDetail,
        error,
        message,
        credexId,
      ];
}
