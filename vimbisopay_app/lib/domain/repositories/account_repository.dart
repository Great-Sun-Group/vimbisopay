import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/domain/entities/account.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/entities/credex_request.dart';
import 'package:vimbisopay_app/domain/entities/recurring_request.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart';
import 'package:vimbisopay_app/domain/entities/recurring_response.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/domain/entities/otp_verification_response.dart';

abstract class AccountRepository {
  Future<Either<Failure, User>> loginV2({
    required String phone,
    String? password,
    String? passwordHash,
  });

  @Deprecated('Use loginV2 instead')
  Future<Either<Failure, User>> login({
    required String phone,
    String? password,
    String? passwordHash,
  });

  Future<Either<Failure, bool>> onboardMember({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
  });

  Future<Either<Failure, User?>> getCurrentUser();
  
  Future<Either<Failure, bool>> saveUser(User user);
  
  Future<Either<Failure, Map<String, double>>> getBalances();
  
  /// Retrieves ledger entries for a specific account.
  /// 
  /// If [afterTimestamp] is provided, only returns entries after that timestamp.
  /// This is used for incremental updates to avoid fetching the entire ledger.
  /// 
  /// [limit] can be used to paginate results.
  Future<Either<Failure, List<LedgerEntry>>> getLedger({
    required String accountId,
    DateTime? afterTimestamp,
    int? limit,
  });

  @Deprecated('Use getLedger with afterTimestamp instead')
  Future<Either<Failure, Map<String, dynamic>>> getLedgerLegacy({
    required String accountId,
    int? startRow,
    int? numRows,
  });

  Future<Either<Failure, Account>> getAccountByHandle(String handle);

  Future<Either<Failure, CredexResponse>> createCredex(CredexRequest request);

  Future<Either<Failure, bool>> acceptCredexBulk(List<String> credexIds);

  Future<Either<Failure, bool>> acceptCredex(String credexId);

  Future<Either<Failure, bool>> cancelCredex(String credexId);

  Future<Either<Failure, bool>> registerNotificationToken(String token);

  Future<Either<Failure, RecurringResponse>> createRecurring(RecurringRequest request);

  /// Request an OTP for a specific purpose
  /// 
  /// [phone] The phone number to send the OTP to
  /// [purpose] The purpose of the OTP (e.g. 'PASSWORD_RESET')
  Future<Either<Failure, bool>> requestOtp({
    required String phone,
    required String purpose,
  });

  /// Verify an OTP using a token
  /// 
  /// [token] The v1 token to use for verification
  /// [otp] The OTP code to verify
  /// [memberId] The member ID to verify the OTP for
  Future<Either<Failure, OtpVerificationResponse>> verifyOtp({
    required String token,
    required String otp,
    required String memberId,
  });

  /// Set the initial password for a user
  /// 
  /// [token] The v1 token to use for authentication
  /// [memberId] The member ID to set the password for
  /// [phone] The phone number associated with the account
  /// [password] The password to set
  Future<Either<Failure, User>> setInitialPassword({
    required String token,
    required String memberId,
    required String phone,
    required String password,
  });
}
