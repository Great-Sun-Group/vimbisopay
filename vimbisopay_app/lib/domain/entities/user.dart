import 'package:vimbisopay_app/domain/entities/dashboard.dart';

class User {
  final String memberId;
  final String phone;
  final String token;
  final String? passwordHash;  // Hashed password
  final String? passwordSalt;  // Salt used for hashing
  final DateTime? passwordChanged;  // When the password was last changed
  final Dashboard? dashboard;  // Optional since it might not be available during local storage retrieval

  const User({
    required this.memberId,
    required this.phone,
    required this.token,
    this.passwordHash,
    this.passwordSalt,
    this.passwordChanged,
    this.dashboard,
  });

  MemberTier? get tier => dashboard?.memberTier;
  
  String get tierName {
    final tierType = tier?.type ?? MemberTierType.open;
    return tierType.name;
  }

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'phone': phone,
      'token': token,
      'password_hash': passwordHash,
      'password_salt': passwordSalt,
      'password_changed': passwordChanged?.millisecondsSinceEpoch,
      'dashboard': dashboard?.toMap(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      memberId: map['memberId'] as String,
      phone: map['phone'] as String,
      token: map['token'] as String,
      passwordHash: map['password_hash'] as String?,
      passwordSalt: map['password_salt'] as String?,
      passwordChanged: map['password_changed'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['password_changed'] as int)
          : null,
      dashboard: map['dashboard'] != null 
          ? Dashboard.fromMap(map['dashboard'] as Map<String, dynamic>)
          : null,
    );
  }

  User copyWith({
    String? memberId,
    String? phone,
    String? token,
    String? passwordHash,
    String? passwordSalt,
    DateTime? passwordChanged,
    Dashboard? dashboard,
  }) {
    return User(
      memberId: memberId ?? this.memberId,
      phone: phone ?? this.phone,
      token: token ?? this.token,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      passwordChanged: passwordChanged ?? this.passwordChanged,
      dashboard: dashboard ?? this.dashboard,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.memberId == memberId &&
        other.phone == phone &&
        other.token == token &&
        other.passwordHash == passwordHash &&
        other.passwordSalt == passwordSalt &&
        other.passwordChanged == passwordChanged &&
        other.dashboard == dashboard;
  }

  @override
  int get hashCode => Object.hash(
        memberId,
        phone,
        token,
        passwordHash,
        passwordSalt,
        passwordChanged,
        dashboard,
      );
}
