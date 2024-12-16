import 'package:vimbisopay_app/domain/entities/base_entity.dart';

class MemberTier {
  final int low;
  final int high;

  const MemberTier({
    required this.low,
    required this.high,
  });
}

class UnsecuredBalances {
  final String totalPayables;
  final String totalReceivables;
  final String netPayRec;

  const UnsecuredBalances({
    required this.totalPayables,
    required this.totalReceivables,
    required this.netPayRec,
  });
}

class BalanceData {
  final List<String> securedNetBalancesByDenom;
  final UnsecuredBalances unsecuredBalances;
  final String netCredexAssetsInDefaultDenom;

  const BalanceData({
    required this.securedNetBalancesByDenom,
    required this.unsecuredBalances,
    required this.netCredexAssetsInDefaultDenom,
  });
}

class AuthUser {
  final String firstname;
  final String lastname;
  final String memberID;

  const AuthUser({
    required this.firstname,
    required this.lastname,
    required this.memberID,
  });
}

class DashboardAccount {
  final String accountID;
  final String accountName;
  final String accountHandle;
  final String defaultDenom;
  final bool isOwnedAccount;
  final List<AuthUser> authFor;
  final BalanceData balanceData;

  const DashboardAccount({
    required this.accountID,
    required this.accountName,
    required this.accountHandle,
    required this.defaultDenom,
    required this.isOwnedAccount,
    required this.authFor,
    required this.balanceData,
  });
}

class Dashboard extends Entity {
  final String memberHandle;
  final String firstname;
  final String lastname;
  final String defaultDenom;
  final MemberTier memberTier;
  final String? remainingAvailableUSD;
  final List<DashboardAccount> accounts;

  const Dashboard({
    required String id,
    required this.memberHandle,
    required this.firstname,
    required this.lastname,
    required this.defaultDenom,
    required this.memberTier,
    this.remainingAvailableUSD,
    required this.accounts,
  }) : super(id);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Dashboard &&
        other.id == id &&
        other.memberHandle == memberHandle &&
        other.firstname == firstname &&
        other.lastname == lastname &&
        other.defaultDenom == defaultDenom;
  }

  @override
  int get hashCode => Object.hash(id, memberHandle, firstname, lastname, defaultDenom);
}
