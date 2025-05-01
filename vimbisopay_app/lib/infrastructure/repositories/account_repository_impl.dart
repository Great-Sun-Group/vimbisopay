import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/infrastructure/services/password_service.dart';
import 'package:vimbisopay_app/infrastructure/repositories/base_account_repository.dart';

// Import mixins
import 'package:vimbisopay_app/infrastructure/repositories/mixins/account_repository_auth_mixin.dart';
import 'package:vimbisopay_app/infrastructure/repositories/mixins/account_repository_ledger_mixin.dart';
import 'package:vimbisopay_app/infrastructure/repositories/mixins/account_repository_otp_mixin.dart';
import 'package:vimbisopay_app/infrastructure/repositories/mixins/account_repository_credex_mixin.dart';

/// Implementation of the AccountRepository interface
/// 
/// This class is split into multiple mixins to make it more manageable:
/// - AccountRepositoryAuthMixin: Authentication methods
/// - AccountRepositoryLedgerMixin: Ledger and account methods
/// - AccountRepositoryOtpMixin: OTP and password methods
/// - AccountRepositoryCredexMixin: Credex and recurring payment methods
class AccountRepositoryImpl extends BaseAccountRepository with 
    AccountRepositoryAuthMixin,
    AccountRepositoryLedgerMixin,
    AccountRepositoryOtpMixin,
    AccountRepositoryCredexMixin
    implements AccountRepository {

  AccountRepositoryImpl({
    required PasswordService passwordService,
    DatabaseHelper? databaseHelper,
    http.Client? httpClient,
  }) : super(
         passwordService: passwordService,
         databaseHelper: databaseHelper ?? DatabaseHelper(),
         httpClient: httpClient ?? http.Client(),
       );

  // For testing
  @visibleForTesting
  static AccountRepositoryImpl createForTesting({
    required PasswordService passwordService,
    DatabaseHelper? databaseHelper,
    http.Client? httpClient,
  }) {
    return AccountRepositoryImpl(
      passwordService: passwordService,
      databaseHelper: databaseHelper,
      httpClient: httpClient,
    );
  }
}
