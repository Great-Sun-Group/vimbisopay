import 'package:vimbisopay_app/domain/entities/base_entity.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart' as credex;

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
  final List<AuthUser> authFor;
  final BalanceData balanceData;
  final credex.PendingData pendingInData;
  final credex.PendingData pendingOutData;
  final AuthUser sendOffersTo;

  const DashboardAccount({
    required this.accountID,
    required this.accountName,
    required this.accountHandle,
    required this.defaultDenom,
    required this.isOwnedAccount,
    required this.authFor,
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
    'authFor': authFor.map((x) => x.toMap()).toList(),
    'balanceData': balanceData.toMap(),
    'pendingInData': pendingInData.toMap(),
    'pendingOutData': pendingOutData.toMap(),
    'sendOffersTo': sendOffersTo.toMap(),
  };

  factory DashboardAccount.fromMap(Map<String, dynamic> map) => DashboardAccount(
    accountID: map['accountID'] as String,
    accountName: map['accountName'] as String,
    accountHandle: map['accountHandle'] as String,
    defaultDenom: map['defaultDenom'] as String,
    isOwnedAccount: map['isOwnedAccount'] as bool,
    authFor: List<AuthUser>.from(
      (map['authFor'] as List).map((x) => AuthUser.fromMap(x)),
    ),
    balanceData: BalanceData.fromMap(map['balanceData']),
    pendingInData: credex.PendingData.fromMap(map['pendingInData']),
    pendingOutData: credex.PendingData.fromMap(map['pendingOutData']),
    sendOffersTo: AuthUser.fromMap(map['sendOffersTo']),
  );
}

class Dashboard extends Entity {
  final MemberTier memberTier;
  final RemainingAvailable remainingAvailableUSD;
  final List<DashboardAccount> accounts;
  // Keep these for backward compatibility with UI
  final String? firstname;
  final String? lastname;
  final String? defaultDenom;

  const Dashboard({
    required String id,
    required this.memberTier,
    required this.remainingAvailableUSD,
    required this.accounts,
    this.firstname,
    this.lastname,
    this.defaultDenom,
  }) : super(id);

  bool get canIssueSecuredCredex => memberTier.canIssueSecuredCredex;
  double get dailySecuredCredexLimit => memberTier.dailySecuredCredexLimit;
  bool get canIssueUnsecuredCredex => memberTier.canIssueUnsecuredCredex;
  bool get canCreateAdditionalAccounts => memberTier.canCreateAdditionalAccounts;
  bool get canBeAddedToAccount => memberTier.canBeAddedToAccount;
  bool get canAddOthersToAccount => memberTier.canAddOthersToAccount;
  bool get canRequestRecurringPayments => memberTier.canRequestRecurringPayments;

  Map<String, dynamic> toMap() => {
    'id': id,
    'memberTier': memberTier.toMap(),
    'remainingAvailableUSD': remainingAvailableUSD.toMap(),
    'accounts': accounts.map((x) => x.toMap()).toList(),
    'firstname': firstname,
    'lastname': lastname,
    'defaultDenom': defaultDenom,
  };

  factory Dashboard.fromMap(Map<String, dynamic> map) => Dashboard(
    id: map['id'] as String,
    memberTier: MemberTier.fromMap(map['memberTier']),
    remainingAvailableUSD: RemainingAvailable.fromMap(map['remainingAvailableUSD']),
    accounts: List<DashboardAccount>.from(
      (map['accounts'] as List).map((x) => DashboardAccount.fromMap(x)),
    ),
    firstname: map['firstname'] as String?,
    lastname: map['lastname'] as String?,
    defaultDenom: map['defaultDenom'] as String?,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Dashboard &&
        other.id == id &&
        other.memberTier.low == memberTier.low &&
        other.memberTier.high == memberTier.high;
  }

  @override
  int get hashCode => Object.hash(id, memberTier.low, memberTier.high);
}
