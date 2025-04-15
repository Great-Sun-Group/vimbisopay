import 'package:equatable/equatable.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;
import 'package:vimbisopay_app/domain/entities/denomination.dart';

abstract class SendCredexEvent extends Equatable {
  const SendCredexEvent();
  
  @override
  List<Object?> get props => [];
}

class InitializeSendCredexEvent extends SendCredexEvent {
  final dashboard.DashboardAccount senderAccount;
  final String? recipientHandle;
  final String? recipientAccountId;
  
  const InitializeSendCredexEvent({
    required this.senderAccount,
    this.recipientHandle,
    this.recipientAccountId,
  });
  
  @override
  List<Object?> get props => [senderAccount, recipientHandle, recipientAccountId];
}

class VerifyRecipientEvent extends SendCredexEvent {
  final String handle;
  
  const VerifyRecipientEvent(this.handle);
  
  @override
  List<Object> get props => [handle];
}

class UpdateAmountEvent extends SendCredexEvent {
  final String amount;
  
  const UpdateAmountEvent(this.amount);
  
  @override
  List<Object> get props => [amount];
}

class UpdateDenominationEvent extends SendCredexEvent {
  final Denomination denomination;
  
  const UpdateDenominationEvent(this.denomination);
  
  @override
  List<Object> get props => [denomination];
}

class ChangeRecipientEvent extends SendCredexEvent {
  const ChangeRecipientEvent();
}

class ScanQRCodeEvent extends SendCredexEvent {
  final String? result;
  
  const ScanQRCodeEvent(this.result);
  
  @override
  List<Object?> get props => [result];
}

class SendCredexSubmitEvent extends SendCredexEvent {
  const SendCredexSubmitEvent();
}

class ClearErrorEvent extends SendCredexEvent {
  const ClearErrorEvent();
}

class UpdateStatusEvent extends SendCredexEvent {
  final String message;
  
  const UpdateStatusEvent(this.message);
  
  @override
  List<Object> get props => [message];
}

class UpdateCredexTypeEvent extends SendCredexEvent {
  final bool isSecured;
  
  const UpdateCredexTypeEvent(this.isSecured);
  
  @override
  List<Object> get props => [isSecured];
}

class UpdateDueDateEvent extends SendCredexEvent {
  final DateTime? dueDate;
  
  const UpdateDueDateEvent(this.dueDate);
  
  @override
  List<Object?> get props => [dueDate];
}
