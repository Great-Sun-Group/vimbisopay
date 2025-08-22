import 'package:equatable/equatable.dart';

abstract class CredexDetailEvent extends Equatable {
  const CredexDetailEvent();

  @override
  List<Object?> get props => [];
}

class CredexDetailLoadStarted extends CredexDetailEvent {
  final String credexId;

  const CredexDetailLoadStarted(this.credexId);

  @override
  List<Object?> get props => [credexId];
}

class CredexDetailRefreshStarted extends CredexDetailEvent {
  final String credexId;

  const CredexDetailRefreshStarted(this.credexId);

  @override
  List<Object?> get props => [credexId];
}

class CredexDetailAcceptStarted extends CredexDetailEvent {
  final String credexId;

  const CredexDetailAcceptStarted(this.credexId);

  @override
  List<Object?> get props => [credexId];
}

class CredexDetailDeclineStarted extends CredexDetailEvent {
  final String credexId;

  const CredexDetailDeclineStarted(this.credexId);

  @override
  List<Object?> get props => [credexId];
}

class CredexDetailCancelStarted extends CredexDetailEvent {
  final String credexId;

  const CredexDetailCancelStarted(this.credexId);

  @override
  List<Object?> get props => [credexId];
}
