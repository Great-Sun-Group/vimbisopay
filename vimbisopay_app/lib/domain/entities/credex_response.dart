class CredexResponse {
  final String message;
  final CredexData data;

  CredexResponse({
    required this.message,
    required this.data,
  });
}

class CredexData {
  final CredexAction action;
  final CredexDashboard dashboard;

  CredexData({
    required this.action,
    required this.dashboard,
  });
}

class CredexAction {
  final String id;
  final String type;
  final String timestamp;
  final String actor;
  final CredexActionDetails details;

  CredexAction({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.actor,
    required this.details,
  });
}

class CredexActionDetails {
  final String amount;
  final String denomination;
  final bool securedCredex;
  final String receiverAccountID;
  final String receiverAccountName;

  CredexActionDetails({
    required this.amount,
    required this.denomination,
    required this.securedCredex,
    required this.receiverAccountID,
    required this.receiverAccountName,
  });
}

class CredexDashboard {
  final bool success;
  final CredexDashboardData data;
  final String message;

  CredexDashboard({
    required this.success,
    required this.data,
    required this.message,
  });
}

class CredexDashboardData {
  final String accountID;
  final String accountName;
  final String accountHandle;
  final String defaultDenom;
  final bool isOwnedAccount;
  final List<AuthUser> authFor;
  final BalanceData balanceData;
  final PendingData pendingInData;
  final PendingData pendingOutData;
  final SendOffersTo sendOffersTo;

  CredexDashboardData({
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
}

class AuthUser {
  final String lastname;
  final String firstname;
  final String memberID;

  AuthUser({
    required this.lastname,
    required this.firstname,
    required this.memberID,
  });
}

class BalanceData {
  final bool success;
  final BalanceDataDetails data;
  final String message;

  BalanceData({
    required this.success,
    required this.data,
    required this.message,
  });
}

class BalanceDataDetails {
  final List<String> securedNetBalancesByDenom;
  final UnsecuredBalances unsecuredBalancesInDefaultDenom;
  final String netCredexAssetsInDefaultDenom;

  BalanceDataDetails({
    required this.securedNetBalancesByDenom,
    required this.unsecuredBalancesInDefaultDenom,
    required this.netCredexAssetsInDefaultDenom,
  });
}

class UnsecuredBalances {
  final String totalPayables;
  final String totalReceivables;
  final String netPayRec;

  UnsecuredBalances({
    required this.totalPayables,
    required this.totalReceivables,
    required this.netPayRec,
  });
}

class PendingData {
  final bool success;
  final List<PendingOffer> data;
  final String message;

  PendingData({
    required this.success,
    required this.data,
    required this.message,
  });
}

class PendingOffer {
  final String credexID;
  final String formattedInitialAmount;
  final String counterpartyAccountName;
  final bool secured;

  PendingOffer({
    required this.credexID,
    required this.formattedInitialAmount,
    required this.counterpartyAccountName,
    required this.secured,
  });
}

class SendOffersTo {
  final String memberID;
  final String firstname;
  final String lastname;

  SendOffersTo({
    required this.memberID,
    required this.firstname,
    required this.lastname,
  });
}
