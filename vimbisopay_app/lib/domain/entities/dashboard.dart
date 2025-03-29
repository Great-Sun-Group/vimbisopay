import 'package:vimbisopay_app/domain/entities/base_entity.dart';
import 'package:flutter/foundation.dart' show listEquals;

enum MemberTierType {
  open(1, 10.0, false, true, false, false, false, false),    // Free tier
  hustler(3, 100.0, false, true, false, false, false, true), // $1 tier
  special(5, 100.0, false, true, false, false, false, true); // Special tier

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
  // Map tier values with special handling for tier 5
  type = high == 5 ? MemberTierType.special : (high >= 3 ? MemberTierType.hustler : MemberTierType.open);
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

class DashboardInternalAccount {
  final String accountID;
  final String accountName;
  final String accountType;
  final String? profilePictureThumbnail;
  final SendOffersTo? sendOffersTo;
  final BalanceData? balanceData;
  final PendingData? pendingInData;
  final PendingData? pendingOutData;

  const DashboardInternalAccount({
    required this.accountID,
    required this.accountName,
    required this.accountType,
    this.profilePictureThumbnail,
    this.sendOffersTo,
    this.balanceData,
    this.pendingInData,
    this.pendingOutData,
  });

  Map<String, dynamic> toMap() => {
    'accountID': accountID,
    'accountName': accountName,
    'accountType': accountType,
    'profilePictureThumbnail': profilePictureThumbnail,
    'sendOffersTo': sendOffersTo?.toMap(),
    'balanceData': balanceData?.toMap(),
    'pendingInData': pendingInData?.toMap(),
    'pendingOutData': pendingOutData?.toMap(),
  };

  factory DashboardInternalAccount.fromMap(Map<String, dynamic> map) {
    // Handle balance data
    BalanceData? balanceData;
    if (map.containsKey('balanceData') && map['balanceData'] != null) {
      balanceData = BalanceData.fromMap(map['balanceData']);
    }
    
    // Handle send offers to
    SendOffersTo? sendOffersTo;
    if (map.containsKey('sendOffersTo') && map['sendOffersTo'] != null) {
      sendOffersTo = SendOffersTo.fromMap(map['sendOffersTo']);
    }
    
    // Handle pending in data
    PendingData? pendingInData;
    if (map.containsKey('pendingInData') && map['pendingInData'] != null) {
      pendingInData = PendingData.fromMap(map['pendingInData']);
    }
    
    // Handle pending out data
    PendingData? pendingOutData;
    if (map.containsKey('pendingOutData') && map['pendingOutData'] != null) {
      pendingOutData = PendingData.fromMap(map['pendingOutData']);
    }
    
    return DashboardInternalAccount(
      accountID: map['accountID'] as String,
      accountName: map['accountName'] as String,
      accountType: map['accountType'] as String,
      profilePictureThumbnail: map['profilePictureThumbnail'] as String?,
      sendOffersTo: sendOffersTo,
      balanceData: balanceData,
      pendingInData: pendingInData,
      pendingOutData: pendingOutData,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DashboardInternalAccount &&
        other.accountID == accountID &&
        other.accountName == accountName &&
        other.accountType == accountType &&
        other.profilePictureThumbnail == profilePictureThumbnail &&
        other.sendOffersTo == sendOffersTo &&
        other.balanceData == balanceData &&
        other.pendingInData == pendingInData &&
        other.pendingOutData == pendingOutData;
  }

  @override
  int get hashCode => Object.hash(
    accountID, 
    accountName, 
    accountType,
    profilePictureThumbnail,
    sendOffersTo,
    balanceData,
    pendingInData,
    pendingOutData,
  );
}

class Dashboard extends Entity {
  final DashboardMember member;
  final List<DashboardAccount> accounts;
  final List<DashboardInternalAccount> accountsInternal;
  final bool activateMarket;

  const Dashboard({
    required String id,
    required this.member,
    required this.accounts,
    this.accountsInternal = const [],
    this.activateMarket = false,
  }) : super(id);

  // Backward compatibility getters
  String? get firstname => member.firstname;
  String? get lastname => member.lastname;
  String? get defaultDenom => member.defaultDenom;
  MemberTier get memberTier => MemberTier(low: 0, high: member.memberTier);

  // Permission getters based on member tier
  bool get canIssueSecuredCredex => member.memberTier >= 3;
  double get dailySecuredCredexLimit => memberTier.dailySecuredCredexLimit;
  bool get canIssueUnsecuredCredex => member.memberTier >= 3;
  bool get canCreateAdditionalAccounts => member.memberTier >= 3;
  bool get canBeAddedToAccount => member.memberTier >= 3;
  bool get canAddOthersToAccount => member.memberTier >= 3;
  bool get canRequestRecurringPayments => member.memberTier >= 3;

  Map<String, dynamic> toMap() => {
    'id': id,
    'member': member.toMap(),
    'accounts': accounts.map((account) => account.toMap()).toList(),
    'accountsInternal': accountsInternal.map((account) => account.toMap()).toList(),
    'activateMarket': activateMarket,
  };

  factory Dashboard.fromMap(Map<String, dynamic> map) {
    List<DashboardInternalAccount> internalAccounts = [];
    if (map.containsKey('accountsInternal') && map['accountsInternal'] != null) {
      internalAccounts = (map['accountsInternal'] as List)
          .map((account) => DashboardInternalAccount.fromMap(account))
          .toList();
    }
    
    return Dashboard(
      id: map['member']['memberID'] as String,
      member: DashboardMember.fromMap(map['member']),
      accounts: (map['accounts'] as List).map((account) => DashboardAccount.fromMap(account)).toList(),
      accountsInternal: internalAccounts,
      activateMarket: map['activateMarket'] as bool? ?? false,
    );
  }

  // Factory constructor for creating from Credex response
  factory Dashboard.fromCredexResponse(Map<String, dynamic> data) {
    final dashboardData = data['dashboard'];
    
    List<DashboardInternalAccount> internalAccounts = [];
    if (dashboardData.containsKey('accountsInternal') && dashboardData['accountsInternal'] != null) {
      internalAccounts = (dashboardData['accountsInternal'] as List)
          .map((account) => DashboardInternalAccount.fromMap(account))
          .toList();
    }
    
    return Dashboard(
      id: dashboardData['member']['memberID'],
      member: DashboardMember.fromMap(dashboardData['member']),
      accounts: (dashboardData['accounts'] as List).map((account) => 
        DashboardAccount.fromMap(account)
      ).toList(),
      accountsInternal: internalAccounts,
      activateMarket: dashboardData['activateMarket'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Dashboard &&
        other.id == id &&
        other.member == member &&
        listEquals(accounts, other.accounts) &&
        listEquals(accountsInternal, other.accountsInternal) &&
        other.activateMarket == activateMarket;
  }

  @override
  int get hashCode => Object.hash(
        id, 
        member, 
        Object.hashAll(accounts), 
        Object.hashAll(accountsInternal), 
        activateMarket
      );
}

class DashboardMember {
  final String memberID;
  final int memberTier;
  final String firstname;
  final String lastname;
  final String? memberHandle;
  final String defaultDenom;
  final String? profilePictureThumbnail;

  const DashboardMember({
    required this.memberID,
    required this.memberTier,
    required this.firstname,
    required this.lastname,
    this.memberHandle,
    required this.defaultDenom,
    this.profilePictureThumbnail,
  });

  Map<String, dynamic> toMap() => {
    'memberID': memberID,
    'memberTier': memberTier,
    'firstname': firstname,
    'lastname': lastname,
    'memberHandle': memberHandle,
    'defaultDenom': defaultDenom,
    'profilePictureThumbnail': profilePictureThumbnail,
  };

  factory DashboardMember.fromMap(Map<String, dynamic> map) => DashboardMember(
    memberID: map['memberID'] as String,
    memberTier: map['memberTier'] as int,
    firstname: map['firstname'] as String,
    lastname: map['lastname'] as String,
    memberHandle: map['memberHandle'] as String?,
    defaultDenom: map['defaultDenom'] as String,
    profilePictureThumbnail: map['profilePictureThumbnail'] as String?,
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

class PendingData {
  final bool success;
  final List<PendingOffer> data;
  final String message;

  const PendingData({
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
      (map['data'] as List? ?? []).map((x) => PendingOffer.fromMap(x)),
    ),
    message: map['message'] as String,
  );
}

class DashboardAccount {
  final String accountID;
  final String accountName;
  final String accountHandle;
  final String defaultDenom;
  final bool isOwnedAccount;
  final BalanceData balanceData;
  final PendingData pendingInData;
  final PendingData pendingOutData;
  final SendOffersTo sendOffersTo;
  final String? accountType;

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
    this.accountType,
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
    'sendOffersTo': sendOffersTo.toMap(),
    'accountType': accountType,
  };

  factory DashboardAccount.fromMap(Map<String, dynamic> map) => DashboardAccount(
    accountID: map['accountID'] as String,
    accountName: map['accountName'] as String,
    accountHandle: map['accountHandle'] as String,
    defaultDenom: map['defaultDenom'] as String,
    isOwnedAccount: map['isOwnedAccount'] as bool,
    balanceData: BalanceData.fromMap(map['balanceData']),
    pendingInData: PendingData.fromMap(map['pendingInData']),
    pendingOutData: PendingData.fromMap(map['pendingOutData']),
    sendOffersTo: SendOffersTo.fromMap(map['sendOffersTo']),
    accountType: map['accountType'] as String?,
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

  factory BalanceData.fromMap(Map<String, dynamic> map) {
    final balanceData = map['balanceData'] ?? map;
    return BalanceData(
      securedNetBalancesByDenom: List<String>.from(balanceData['securedNetBalancesByDenom']),
      unsecuredBalances: UnsecuredBalances.fromMap(balanceData['unsecuredBalancesInDefaultDenom']),
      netCredexAssetsInDefaultDenom: balanceData['netCredexAssetsInDefaultDenom'] as String,
    );
  }
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

class PendingOffer {
  final String credexID;
  final String formattedInitialAmount;
  final String counterpartyAccountName;
  final bool secured;
  final DateTime? dueDate;

  String get uniqueIdentifier {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final amount = double.tryParse(formattedInitialAmount.replaceAll(RegExp(r'[^\d.-]'), '')) ?? 0.0;
    final type = secured ? 'secured' : 'unsecured';
    return '${counterpartyAccountName.replaceAll(' ', '')}_${timestamp}_${amount}_$type';
  }

  const PendingOffer({
    required this.credexID,
    required this.formattedInitialAmount,
    required this.counterpartyAccountName,
    required this.secured,
    this.dueDate,
  });

  Map<String, dynamic> toMap() => {
    'credexID': credexID,
    'formattedInitialAmount': formattedInitialAmount,
    'counterpartyAccountName': counterpartyAccountName,
    'secured': secured,
    'dueDate': dueDate?.toIso8601String(),
  };

  factory PendingOffer.fromMap(Map<String, dynamic> map) {
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
        
        if (!map.containsKey('formattedInitialAmount') || 
            map['formattedInitialAmount'] == null || 
            map['formattedInitialAmount'].toString().isEmpty) {
          final sign = amount >= 0 ? '+' : '';
          final denomination = map['denomination'] ?? 'CXX';
          formattedAmount = '$sign${amount.toStringAsFixed(2)} $denomination';
        } else {
          formattedAmount = map['formattedInitialAmount'].toString();
        }
      } else if (map.containsKey('formattedInitialAmount') && 
                 map['formattedInitialAmount'] != null && 
                 map['formattedInitialAmount'].toString().isNotEmpty) {
        formattedAmount = map['formattedInitialAmount'].toString();
      } else {
        formattedAmount = '0.00 CXX';
      }
    } catch (e) {
      formattedAmount = '0.00 CXX';
    }

    // Parse due date if available
    DateTime? dueDate;
    if (map.containsKey('dueDate') && map['dueDate'] != null) {
      try {
        if (map['dueDate'] is String) {
          dueDate = DateTime.parse(map['dueDate'] as String);
        }
      } catch (e) {
        // Ignore parsing errors and leave dueDate as null
      }
    }

    return PendingOffer(
      credexID: map['credexID'] as String,
      formattedInitialAmount: formattedAmount,
      counterpartyAccountName: map['counterpartyAccountName'] as String,
      secured: map['secured'] as bool,
      dueDate: dueDate,
    );
  }
}

class SendOffersTo {
  final String memberID;
  final String firstname;
  final String lastname;

  const SendOffersTo({
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
