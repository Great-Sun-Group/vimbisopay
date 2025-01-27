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
  final DashboardMember member;
  final List<DashboardAccount> accounts;

  CredexDashboard({
    required this.member,
    required this.accounts,
  });
}

class DashboardMember {
  final String memberID;
  final int memberTier;
  final String firstname;
  final String lastname;
  final String? memberHandle;
  final String defaultDenom;

  DashboardMember({
    required this.memberID,
    required this.memberTier,
    required this.firstname,
    required this.lastname,
    this.memberHandle,
    required this.defaultDenom,
  });
}

class DashboardAccount {
  final String accountID;
  final String accountName;
  final String accountHandle;
  final String accountType;
  final String defaultDenom;
  final bool isOwnedAccount;
  final SendOffersTo sendOffersTo;
  final BalanceData balanceData;
  final List<PendingOffer> pendingInData;
  final List<PendingOffer> pendingOutData;

  DashboardAccount({
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

  Map<String, dynamic> toMap() => {
    'lastname': lastname,
    'firstname': firstname,
    'memberID': memberID,
  };

  factory AuthUser.fromMap(Map<String, dynamic> map) => AuthUser(
    lastname: map['lastname'] as String,
    firstname: map['firstname'] as String,
    memberID: map['memberID'] as String,
  );
}

class BalanceData {
  final List<String> securedNetBalancesByDenom;
  final UnsecuredBalances unsecuredBalancesInDefaultDenom;
  final String netCredexAssetsInDefaultDenom;

  BalanceData({
    required this.securedNetBalancesByDenom,
    required this.unsecuredBalancesInDefaultDenom,
    required this.netCredexAssetsInDefaultDenom,
  });

  Map<String, dynamic> toMap() => {
    'securedNetBalancesByDenom': securedNetBalancesByDenom,
    'unsecuredBalancesInDefaultDenom': unsecuredBalancesInDefaultDenom.toMap(),
    'netCredexAssetsInDefaultDenom': netCredexAssetsInDefaultDenom,
  };

  factory BalanceData.fromMap(Map<String, dynamic> map) {
    final balanceData = map['balanceData'] ?? map;
    return BalanceData(
      securedNetBalancesByDenom: List<String>.from(balanceData['securedNetBalancesByDenom']),
      unsecuredBalancesInDefaultDenom: UnsecuredBalances.fromMap(balanceData['unsecuredBalancesInDefaultDenom']),
      netCredexAssetsInDefaultDenom: balanceData['netCredexAssetsInDefaultDenom'] as String,
    );
  }

  BalanceData copyWith({
    List<String>? securedNetBalancesByDenom,
    UnsecuredBalances? unsecuredBalancesInDefaultDenom,
    String? netCredexAssetsInDefaultDenom,
  }) {
    return BalanceData(
      securedNetBalancesByDenom: securedNetBalancesByDenom ?? this.securedNetBalancesByDenom,
      unsecuredBalancesInDefaultDenom: unsecuredBalancesInDefaultDenom ?? this.unsecuredBalancesInDefaultDenom,
      netCredexAssetsInDefaultDenom: netCredexAssetsInDefaultDenom ?? this.netCredexAssetsInDefaultDenom,
    );
  }
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

class PendingData {
  final bool success;
  final List<PendingOffer> data;
  final String message;

  PendingData({
    required this.success,
    required this.data,
    required this.message,
  });

  Map<String, dynamic> toMap() => {
    'success': success,
    'data': data.map((x) => x.toMap()).toList(),
    'message': message,
  };

  factory PendingData.fromMap(Map<String, dynamic> map) => PendingData(
    success: map['success'] as bool,
    data: List<PendingOffer>.from(
      (map['data'] as List).map((x) => PendingOffer.fromMap(x)),
    ),
    message: map['message'] as String,
  );
}

class PendingOffer {
  final String credexID;
  final String formattedInitialAmount;
  final String counterpartyAccountName;
  final bool secured;

  // Computed unique identifier that combines multiple fields
  String get uniqueIdentifier {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final amount = double.tryParse(formattedInitialAmount.replaceAll(RegExp(r'[^\d.-]'), '')) ?? 0.0;
    final type = secured ? 'secured' : 'unsecured';
    return '${counterpartyAccountName.replaceAll(' ', '')}_${timestamp}_${amount}_$type';
  }

  PendingOffer({
    required this.credexID,
    required this.formattedInitialAmount,
    required this.counterpartyAccountName,
    required this.secured,
  });

  Map<String, dynamic> toMap() => {
    'credexID': credexID,
    'formattedInitialAmount': formattedInitialAmount,
    'counterpartyAccountName': counterpartyAccountName,
    'secured': secured,
  };

  factory PendingOffer.fromMap(Map<String, dynamic> map) {
    // Parse and format the amount
    String formattedAmount;
    try {
      if (map.containsKey('initialAmount') && map['initialAmount'] != null) {
        double amount;
        if (map['initialAmount'] is String) {
          amount = double.parse(map['initialAmount']);
        } else if (map['initialAmount'] is num) {
          amount = (map['initialAmount'] as num).toDouble();
        } else {
          throw const FormatException('Invalid amount format');
        }
        
        // If formattedInitialAmount is missing or invalid, format the amount ourselves
        if (!map.containsKey('formattedInitialAmount') || 
            map['formattedInitialAmount'] == null || 
            map['formattedInitialAmount'].toString().isEmpty) {
          final sign = amount >= 0 ? '+' : '';
          final denomination = map['denomination'] ?? 'CXX'; // Fallback to CXX if denomination is missing
          formattedAmount = '$sign${amount.toStringAsFixed(2)} $denomination';
        } else {
          formattedAmount = map['formattedInitialAmount'].toString();
        }
      } else if (map.containsKey('formattedInitialAmount') && 
                 map['formattedInitialAmount'] != null && 
                 map['formattedInitialAmount'].toString().isNotEmpty) {
        formattedAmount = map['formattedInitialAmount'].toString();
      } else {
        formattedAmount = '0.00 CXX'; // Fallback if no amount information is available
      }
    } catch (e) {
      formattedAmount = '0.00 CXX'; // Fallback in case of any parsing errors
    }

    return PendingOffer(
      credexID: map['credexID'] as String,
      formattedInitialAmount: formattedAmount,
      counterpartyAccountName: map['counterpartyAccountName'] as String,
      secured: map['secured'] as bool,
    );
  }
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

  Map<String, dynamic> toMap() => {
    'memberID': memberID,
    'firstname': firstname,
    'lastname': lastname,
  };

  factory SendOffersTo.fromMap(Map<String, dynamic> map) => SendOffersTo(
    memberID: map['memberID'] as String,
    firstname: map['firstname'] as String,
    lastname: map['lastname'] as String,
  );
}
