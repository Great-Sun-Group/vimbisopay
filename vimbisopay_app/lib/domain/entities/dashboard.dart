import 'package:vimbisopay_app/domain/entities/base_entity.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart' as credex;
import 'package:flutter/foundation.dart' show listEquals;

enum MemberTierType {
  open(0, 10.0, false, true, false, false, false, false),    // Free tier
  hustler(1, 100.0, false, true, false, false, false, true); // $1 tier

  final int value;
  final double dailyLimit;
  final bool canIssueUnsecuredCredex;
  final bool canIssueSecuredCredex;
  final bool canCreateAdditionalAccounts;
  final bool canBeAddedToAccount;
  final bool canAddOthersToAccount;
  final bool canRequestRecurringPayments;

  const MemberTierType(
    this.value,
    this.dailyLimit,
    this.canIssueUnsecuredCredex,
    this.canIssueSecuredCredex,
    this.canCreateAdditionalAccounts,
    this.canBeAddedToAccount,
    this.canAddOthersToAccount,
    this.canRequestRecurringPayments,
  );
}

class MemberTier {
  final int low;
  final int high;
  late final MemberTierType type;

  MemberTier({
    required this.low,
    required this.high,
  }) {
    type = MemberTierType.values.firstWhere(
      (type) => type.value == high,
      orElse: () => MemberTierType.open,
    );
  }

  Map<String, dynamic> toMap() => {
    'low': low,
    'high': high,
  };

  factory MemberTier.fromMap(Map<String, dynamic> map) => MemberTier(
    low: map['low'] as int,
    high: map['high'] as int,
  );

  bool get canIssueSecuredCredex => type.canIssueSecuredCredex;
  double get dailySecuredCredexLimit => type.dailyLimit;
  bool get canIssueUnsecuredCredex => type.canIssueUnsecuredCredex;
  bool get canCreateAdditionalAccounts => type.canCreateAdditionalAccounts;
  bool get canBeAddedToAccount => type.canBeAddedToAccount;
  bool get canAddOthersToAccount => type.canAddOthersToAccount;
  bool get canRequestRecurringPayments => type.canRequestRecurringPayments;
}

class RemainingAvailable {
  final int low;
  final int high;

  const RemainingAvailable({
    required this.low,
    required this.high,
  });

  Map<String, dynamic> toMap() => {
    'low': low,
    'high': high,
  };

  factory RemainingAvailable.fromMap(Map<String, dynamic> map) => RemainingAvailable(
    low: map['low'] as int,
    high: map['high'] as int,
  );
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

  Map<String, dynamic> toMap() => {
    'totalPayables': totalPayables,
    'totalReceivables': totalReceivables,
    'netPayRec': netPayRec,
  };

  factory UnsecuredBalances.fromMap(Map<String, dynamic> map) => UnsecuredBalances(
    totalPayables: map['totalPayables'] as String,
    totalReceivables: map['totalReceivables'] as String,
    netPayRec: map['netPayRec'] as String,
  );
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

  Map<String, dynamic> toMap() => {
    'securedNetBalancesByDenom': securedNetBalancesByDenom,
    'unsecuredBalances': unsecuredBalances.toMap(),
    'netCredexAssetsInDefaultDenom': netCredexAssetsInDefaultDenom,
  };

  factory BalanceData.fromMap(Map<String, dynamic> map) => BalanceData(
    securedNetBalancesByDenom: List<String>.from(map['securedNetBalancesByDenom']),
    unsecuredBalances: UnsecuredBalances.fromMap(map['unsecuredBalances']),
    netCredexAssetsInDefaultDenom: map['netCredexAssetsInDefaultDenom'] as String,
  );
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

  Map<String, dynamic> toMap() => {
    'firstname': firstname,
    'lastname': lastname,
    'memberID': memberID,
  };

  factory AuthUser.fromMap(Map<String, dynamic> map) => AuthUser(
    firstname: map['firstname'] as String,
    lastname: map['lastname'] as String,
    memberID: map['memberID'] as String,
  );
}

class DashboardAccount {
  final String accountID;
  final String accountName;
  final String accountHandle;
  final String defaultDenom;
  final bool isOwnedAccount;
  final BalanceData balanceData;
  final credex.PendingData pendingInData;
  final credex.PendingData pendingOutData;
  final credex.SendOffersTo sendOffersTo;

  const DashboardAccount({
    required this.accountID,
    required this.accountName,
    required this.accountHandle,
    required this.defaultDenom,
    required this.isOwnedAccount,
    required this.balanceData,
    required this.pendingInData,
    required this.pendingOutData,
    required this.sendOffersTo,
  });

  Map<String, dynamic> toMap() => {
    'accountID': accountID,
    'accountName': accountName,
    'accountHandle': accountHandle,
    'defaultDenom': defaultDenom,
    'isOwnedAccount': isOwnedAccount,
    'balanceData': balanceData.toMap(),
    'pendingInData': pendingInData.toMap(),
    'pendingOutData': pendingOutData.toMap(),
    'sendOffersTo': {
      'memberID': sendOffersTo.memberID,
      'firstname': sendOffersTo.firstname,
      'lastname': sendOffersTo.lastname,
    },
  };

  factory DashboardAccount.fromMap(Map<String, dynamic> map) => DashboardAccount(
    accountID: map['accountID'] as String,
    accountName: map['accountName'] as String,
    accountHandle: map['accountHandle'] as String,
    defaultDenom: map['defaultDenom'] as String,
    isOwnedAccount: map['isOwnedAccount'] as bool,
    balanceData: BalanceData.fromMap(map['balanceData']),
    pendingInData: credex.PendingData.fromMap(map['pendingInData']),
    pendingOutData: credex.PendingData.fromMap(map['pendingOutData']),
    sendOffersTo: credex.SendOffersTo(
      memberID: map['sendOffersTo']['memberID'] as String,
      firstname: map['sendOffersTo']['firstname'] as String,
      lastname: map['sendOffersTo']['lastname'] as String,
    ),
  );
}

class Dashboard extends Entity {
  final DashboardMember member;
  final List<DashboardAccount> accounts;

  const Dashboard({
    required String id,
    required this.member,
    required this.accounts,
  }) : super(id);

  // Backward compatibility getters
  String? get firstname => member.firstname;
  String? get lastname => member.lastname;
  String? get defaultDenom => member.defaultDenom;
  MemberTier get memberTier => MemberTier(low: 0, high: member.memberTier);
  RemainingAvailable get remainingAvailableUSD => RemainingAvailable(low: 0, high: 0);

  // Permission getters based on member tier
  bool get canIssueSecuredCredex => member.memberTier >= 5;
  double get dailySecuredCredexLimit => 100.0;
  bool get canIssueUnsecuredCredex => member.memberTier >= 5;
  bool get canCreateAdditionalAccounts => member.memberTier >= 5;
  bool get canBeAddedToAccount => member.memberTier >= 5;
  bool get canAddOthersToAccount => member.memberTier >= 5;
  bool get canRequestRecurringPayments => member.memberTier >= 5;

  Map<String, dynamic> toMap() => {
    'id': id,
    'member': member.toMap(),
    'accounts': accounts.map((account) => account.toMap()).toList(),
  };

  factory Dashboard.fromMap(Map<String, dynamic> map) => Dashboard(
    id: map['member']['memberID'] as String,
    member: DashboardMember.fromMap(map['member']),
    accounts: (map['accounts'] as List).map((account) => DashboardAccount.fromMap(account)).toList(),
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Dashboard &&
        other.id == id &&
        other.member == member &&
        listEquals(accounts, other.accounts);
  }

  @override
  int get hashCode => Object.hash(id, member, Object.hashAll(accounts));
}

class DashboardMember {
  final String memberID;
  final int memberTier;
  final String firstname;
  final String lastname;
  final String? memberHandle;
  final String defaultDenom;

  const DashboardMember({
    required this.memberID,
    required this.memberTier,
    required this.firstname,
    required this.lastname,
    this.memberHandle,
    required this.defaultDenom,
  });

  Map<String, dynamic> toMap() => {
    'memberID': memberID,
    'memberTier': memberTier,
    'firstname': firstname,
    'lastname': lastname,
    'memberHandle': memberHandle,
    'defaultDenom': defaultDenom,
  };

  factory DashboardMember.fromMap(Map<String, dynamic> map) => DashboardMember(
    memberID: map['memberID'] as String,
    memberTier: map['memberTier'] as int,
    firstname: map['firstname'] as String,
    lastname: map['lastname'] as String,
    memberHandle: map['memberHandle'] as String?,
    defaultDenom: map['defaultDenom'] as String,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DashboardMember &&
        other.memberID == memberID &&
        other.memberTier == memberTier;
  }

  @override
  int get hashCode => Object.hash(memberID, memberTier);
}
