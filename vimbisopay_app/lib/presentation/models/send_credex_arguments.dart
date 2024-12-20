import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';

class SendCredexArguments {
  final DashboardAccount senderAccount;
  final AccountRepository accountRepository;
  final HomeBloc homeBloc;

  SendCredexArguments({
    required this.senderAccount,
    required this.accountRepository,
    required this.homeBloc,
  });
}
