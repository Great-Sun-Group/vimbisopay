import 'package:vimbisopay_app/domain/entities/base_entity.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';

/// Entity representing a comprehensive credit report for a counterparty member
class CounterpartyCreditReport extends Entity {
  final String memberID;
  final String firstname;
  final String lastname;
  final String? memberHandle;
  final int memberTier;
  final String? profilePictureThumbnail;
  final CreditRating? creditRating;
  final List<CounterpartyAccount> accounts;
  final DateTime reportGeneratedAt;

  const CounterpartyCreditReport({
    required String id,
    required this.memberID,
    required this.firstname,
    required this.lastname,
    this.memberHandle,
    required this.memberTier,
    this.profilePictureThumbnail,
    this.creditRating,
    this.accounts = const [],
    required this.reportGeneratedAt,
  }) : super(id);

  /// Get the full display name of the member
  String get fullName => '$firstname $lastname';

  /// Get the member tier name
  String get tierName {
    switch (memberTier) {
      case 1:
        return 'Open';
      case 3:
        return 'Hustler';
      case 5:
        return 'Special';
      default:
        return 'Open';
    }
  }

  /// Check if the member has established credit history
  bool get hasCreditHistory {
    if (creditRating == null) return false;
    return creditRating!.redeemedTotalUSD > 0 ||
           creditRating!.outstandingTotalUSD > 0 ||
           creditRating!.defaultedTotalUSD > 0 ||
           creditRating!.writtenOffTotalUSD > 0;
  }

  /// Get total credit activity in USD
  double get totalCreditActivity {
    if (creditRating == null) return 0.0;
    return creditRating!.redeemedTotalUSD +
           creditRating!.outstandingTotalUSD +
           creditRating!.defaultedTotalUSD +
           creditRating!.writtenOffTotalUSD;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'memberID': memberID,
    'firstname': firstname,
    'lastname': lastname,
    'memberHandle': memberHandle,
    'memberTier': memberTier,
    'profilePictureThumbnail': profilePictureThumbnail,
    'creditRating': creditRating?.toMap(),
    'accounts': accounts.map((account) => account.toMap()).toList(),
    'reportGeneratedAt': reportGeneratedAt.toIso8601String(),
  };

  factory CounterpartyCreditReport.fromMap(Map<String, dynamic> map) {
    // Parse credit rating if available
    CreditRating? creditRating;
    if (map.containsKey('creditRating') && map['creditRating'] != null) {
      creditRating = CreditRating.fromMap(map['creditRating'] as Map<String, dynamic>);
    }

    // Parse accounts list
    List<CounterpartyAccount> accounts = [];
    if (map.containsKey('accounts') && map['accounts'] != null) {
      accounts = (map['accounts'] as List)
          .map((account) => CounterpartyAccount.fromMap(account as Map<String, dynamic>))
          .toList();
    }

    return CounterpartyCreditReport(
      id: map['memberID'] as String, // Use memberID as the entity ID
      memberID: map['memberID'] as String,
      firstname: map['firstname'] as String,
      lastname: map['lastname'] as String,
      memberHandle: map['memberHandle'] as String?,
      memberTier: map['memberTier'] as int,
      profilePictureThumbnail: map['profilePictureThumbnail'] as String?,
      creditRating: creditRating,
      accounts: accounts,
      reportGeneratedAt: map.containsKey('reportGeneratedAt') 
          ? DateTime.parse(map['reportGeneratedAt'] as String)
          : DateTime.now(),
    );
  }

  /// Factory constructor to create from DashboardMember
  factory CounterpartyCreditReport.fromDashboardMember(DashboardMember member) {
    return CounterpartyCreditReport(
      id: member.memberID,
      memberID: member.memberID,
      firstname: member.firstname,
      lastname: member.lastname,
      memberHandle: member.memberHandle,
      memberTier: member.memberTier,
      profilePictureThumbnail: member.profilePictureThumbnail,
      creditRating: member.creditRating,
      accounts: const [], // Will be populated separately
      reportGeneratedAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CounterpartyCreditReport &&
        other.memberID == memberID &&
        other.firstname == firstname &&
        other.lastname == lastname &&
        other.memberTier == memberTier &&
        other.creditRating == creditRating;
  }

  @override
  int get hashCode => Object.hash(
    memberID,
    firstname,
    lastname,
    memberTier,
    creditRating,
  );
}

/// Entity representing a counterparty's account information
class CounterpartyAccount {
  final String accountID;
  final String accountName;
  final String accountHandle;
  final String accountType;
  final String defaultDenom;
  final bool isOwnedAccount;

  const CounterpartyAccount({
    required this.accountID,
    required this.accountName,
    required this.accountHandle,
    required this.accountType,
    required this.defaultDenom,
    required this.isOwnedAccount,
  });

  Map<String, dynamic> toMap() => {
    'accountID': accountID,
    'accountName': accountName,
    'accountHandle': accountHandle,
    'accountType': accountType,
    'defaultDenom': defaultDenom,
    'isOwnedAccount': isOwnedAccount,
  };

  factory CounterpartyAccount.fromMap(Map<String, dynamic> map) {
    // Safe string extraction helper
    String safeStringExtract(String key, [String defaultValue = '']) {
      final value = map[key];
      if (value == null) return defaultValue;
      if (value is String) return value;
      return value.toString();
    }

    return CounterpartyAccount(
      accountID: safeStringExtract('accountID'),
      accountName: safeStringExtract('accountName'),
      accountHandle: safeStringExtract('accountHandle'),
      accountType: safeStringExtract('accountType', 'STANDARD'),
      defaultDenom: safeStringExtract('defaultDenom', 'USD'),
      isOwnedAccount: map['isOwnedAccount'] as bool? ?? true,
    );
  }

  /// Factory constructor to create from DashboardAccount
  factory CounterpartyAccount.fromDashboardAccount(DashboardAccount account) {
    return CounterpartyAccount(
      accountID: account.accountID,
      accountName: account.accountName,
      accountHandle: account.accountHandle,
      accountType: account.accountType ?? 'STANDARD',
      defaultDenom: account.defaultDenom,
      isOwnedAccount: account.isOwnedAccount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CounterpartyAccount &&
        other.accountID == accountID &&
        other.accountName == accountName &&
        other.accountHandle == accountHandle;
  }

  @override
  int get hashCode => Object.hash(accountID, accountName, accountHandle);
}
