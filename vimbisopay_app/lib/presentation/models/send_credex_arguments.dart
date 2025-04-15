import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';

/// Arguments for the SendCredexScreen.
/// 
/// This class encapsulates all the parameters needed to initialize the SendCredexScreen,
/// making it easier to pass them around and extend in the future.
class SendCredexArguments {
  /// The sender's account information.
  final dashboard.DashboardAccount senderAccount;
  
  /// Repository for account-related operations.
  final AccountRepository accountRepository;
  
  /// BLoC for home screen state management.
  final HomeBloc homeBloc;
  
  /// Helper for database operations.
  final DatabaseHelper databaseHelper;
  
  /// Optional recipient handle (username).
  final String? recipientHandle;
  
  /// Optional recipient account ID.
  final String? recipientAccountId;

  /// Creates a new instance of SendCredexArguments.
  /// 
  /// The [senderAccount], [accountRepository], [homeBloc], and [databaseHelper] are required.
  /// The [recipientHandle] and [recipientAccountId] are optional and can be used to pre-fill
  /// the recipient information.
  SendCredexArguments({
    required this.senderAccount,
    required this.accountRepository,
    required this.homeBloc,
    required this.databaseHelper,
    this.recipientHandle,
    this.recipientAccountId,
  });
  
  /// Creates a copy of this SendCredexArguments with the given fields replaced with new values.
  SendCredexArguments copyWith({
    dashboard.DashboardAccount? senderAccount,
    AccountRepository? accountRepository,
    HomeBloc? homeBloc,
    DatabaseHelper? databaseHelper,
    String? recipientHandle,
    String? recipientAccountId,
  }) {
    return SendCredexArguments(
      senderAccount: senderAccount ?? this.senderAccount,
      accountRepository: accountRepository ?? this.accountRepository,
      homeBloc: homeBloc ?? this.homeBloc,
      databaseHelper: databaseHelper ?? this.databaseHelper,
      recipientHandle: recipientHandle ?? this.recipientHandle,
      recipientAccountId: recipientAccountId ?? this.recipientAccountId,
    );
  }
}
