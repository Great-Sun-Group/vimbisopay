class CredexResponseV2 {
  final String message;
  final CredexDataV2 data;

  CredexResponseV2({
    required this.message,
    required this.data,
  });

  factory CredexResponseV2.fromMap(Map<String, dynamic> map) => CredexResponseV2(
    message: map['message'] as String,
    data: CredexDataV2.fromMap(map['data'] as Map<String, dynamic>),
  );
}

class CredexDataV2 {
  final CredexActionV2 action;
  final CredexDashboardV2 dashboard;

  CredexDataV2({
    required this.action,
    required this.dashboard,
  });

  factory CredexDataV2.fromMap(Map<String, dynamic> map) => CredexDataV2(
    action: CredexActionV2.fromMap(map['action'] as Map<String, dynamic>),
    dashboard: CredexDashboardV2.fromMap(map['dashboard'] as Map<String, dynamic>),
  );
}

class CredexActionV2 {
  final String id;
  final String type;
  final String timestamp;
  final String actor;
  final CredexActionDetailsV2 details;

  CredexActionV2({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.actor,
    required this.details,
  });

  factory CredexActionV2.fromMap(Map<String, dynamic> map) => CredexActionV2(
    id: map['id'] as String,
    type: map['type'] as String,
    timestamp: map['timestamp'] as String,
    actor: map['actor'] as String,
    details: CredexActionDetailsV2.fromMap(map['details'] as Map<String, dynamic>),
  );
}

class CredexActionDetailsV2 {
  final String amount;
  final String denomination;
  final bool securedCredex;
  final String receiverAccountID;
  final String receiverAccountName;

  CredexActionDetailsV2({
    required this.amount,
    required this.denomination,
    required this.securedCredex,
    required this.receiverAccountID,
    required this.receiverAccountName,
  });

  factory CredexActionDetailsV2.fromMap(Map<String, dynamic> map) => CredexActionDetailsV2(
    amount: map['amount'] as String,
    denomination: map['denomination'] as String,
    securedCredex: map['securedCredex'] as bool,
    receiverAccountID: map['receiverAccountID'] as String,
    receiverAccountName: map['receiverAccountName'] as String,
  );
}

class CredexDashboardV2 {
  final CredexMemberV2 member;
  final List<CredexAccountV2> accounts;

  CredexDashboardV2({
    required this.member,
    required this.accounts,
  });

  factory CredexDashboardV2.fromMap(Map<String, dynamic> map) => CredexDashboardV2(
    member: CredexMemberV2.fromMap(map['member'] as Map<String, dynamic>),
    accounts: List<CredexAccountV2>.from(
      (map['accounts'] as List).map((x) => CredexAccountV2.fromMap(x as Map<String, dynamic>)),
    ),
  );
}

class CredexMemberV2 {
  final String memberID;
  final int memberTier;
  final String firstname;
  final String lastname;
  final String? memberHandle;
  final String defaultDenom;

  CredexMemberV2({
    required this.memberID,
    required this.memberTier,
    required this.firstname,
    required this.lastname,
    this.memberHandle,
    required this.defaultDenom,
  });

  factory CredexMemberV2.fromMap(Map<String, dynamic> map) => CredexMemberV2(
    memberID: map['memberID'] as String,
    memberTier: map['memberTier'] as int,
    firstname: map['firstname'] as String,
    lastname: map['lastname'] as String,
    memberHandle: map['memberHandle'] as String?,
    defaultDenom: map['defaultDenom'] as String,
  );
}

class CredexAccountV2 {
  final String accountID;
  final String accountName;
  final String accountHandle;
  final String accountType;
  final String defaultDenom;
  final bool isOwnedAccount;
  final CredexSendOffersToV2 sendOffersTo;
  final CredexBalanceDataV2 balanceData;
  final List<CredexPendingOfferV2> pendingInData;
  final List<CredexPendingOfferV2> pendingOutData;

  CredexAccountV2({
    required this.accountID,
    required this.accountName,
    required this.accountHandle,
    required this.accountType,
    required this.defaultDenom,
    required this.isOwnedAccount,
    required this.sendOffersTo,
    required this.balanceData,
    required this.pendingInData,
    required this.pendingOutData,
  });

  factory CredexAccountV2.fromMap(Map<String, dynamic> map) => CredexAccountV2(
    accountID: map['accountID'] as String,
    accountName: map['accountName'] as String,
    accountHandle: map['accountHandle'] as String,
    accountType: map['accountType'] as String,
    defaultDenom: map['defaultDenom'] as String,
    isOwnedAccount: map['isOwnedAccount'] as bool,
    sendOffersTo: CredexSendOffersToV2.fromMap(map['sendOffersTo'] as Map<String, dynamic>),
    balanceData: CredexBalanceDataV2.fromMap(map['balanceData'] as Map<String, dynamic>),
    pendingInData: List<CredexPendingOfferV2>.from(
      (map['pendingInData'] as List).map((x) => CredexPendingOfferV2.fromMap(x as Map<String, dynamic>)),
    ),
    pendingOutData: List<CredexPendingOfferV2>.from(
      (map['pendingOutData'] as List).map((x) => CredexPendingOfferV2.fromMap(x as Map<String, dynamic>)),
    ),
  );
}

class CredexBalanceDataV2 {
  final List<String> securedNetBalancesByDenom;
  final CredexUnsecuredBalancesV2 unsecuredBalancesInDefaultDenom;
  final String netCredexAssetsInDefaultDenom;

  CredexBalanceDataV2({
    required this.securedNetBalancesByDenom,
    required this.unsecuredBalancesInDefaultDenom,
    required this.netCredexAssetsInDefaultDenom,
  });

  factory CredexBalanceDataV2.fromMap(Map<String, dynamic> map) => CredexBalanceDataV2(
    securedNetBalancesByDenom: List<String>.from(map['securedNetBalancesByDenom'] as List),
    unsecuredBalancesInDefaultDenom: CredexUnsecuredBalancesV2.fromMap(
      map['unsecuredBalancesInDefaultDenom'] as Map<String, dynamic>,
    ),
    netCredexAssetsInDefaultDenom: map['netCredexAssetsInDefaultDenom'] as String,
  );
}

class CredexUnsecuredBalancesV2 {
  final String totalPayables;
  final String totalReceivables;
  final String netPayRec;

  CredexUnsecuredBalancesV2({
    required this.totalPayables,
    required this.totalReceivables,
    required this.netPayRec,
  });

  factory CredexUnsecuredBalancesV2.fromMap(Map<String, dynamic> map) => CredexUnsecuredBalancesV2(
    totalPayables: map['totalPayables'] as String,
    totalReceivables: map['totalReceivables'] as String,
    netPayRec: map['netPayRec'] as String,
  );
}

class CredexPendingOfferV2 {
  final String credexID;
  final String formattedInitialAmount;
  final String counterpartyAccountName;
  final bool secured;

  CredexPendingOfferV2({
    required this.credexID,
    required this.formattedInitialAmount,
    required this.counterpartyAccountName,
    required this.secured,
  });

  factory CredexPendingOfferV2.fromMap(Map<String, dynamic> map) => CredexPendingOfferV2(
    credexID: map['credexID'] as String,
    formattedInitialAmount: map['formattedInitialAmount'] as String,
    counterpartyAccountName: map['counterpartyAccountName'] as String,
    secured: map['secured'] as bool,
  );
}

class CredexSendOffersToV2 {
  final String memberID;
  final String firstname;
  final String lastname;

  CredexSendOffersToV2({
    required this.memberID,
    required this.firstname,
    required this.lastname,
  });

  factory CredexSendOffersToV2.fromMap(Map<String, dynamic> map) => CredexSendOffersToV2(
    memberID: map['memberID'] as String,
    firstname: map['firstname'] as String,
    lastname: map['lastname'] as String,
  );
}
