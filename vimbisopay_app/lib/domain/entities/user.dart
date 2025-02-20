import 'package:vimbisopay_app/domain/entities/dashboard.dart';

class User {
  final String memberId;
  final String phone;
  final String token;
  final bool otpVerified;  // Whether OTP verification is complete
  final String? version;  // API version (v1, v2)
  final String? authMethod;  // Authentication method (phone_only, etc)
  final String? passwordHash;  // Hashed password
  final DateTime? passwordChanged;  // When the password was last changed
  final Dashboard? dashboard;  // Optional since it might not be available during local storage retrieval

  const User({
    required this.memberId,
    required this.phone,
    required this.token,
    this.otpVerified = false,
    this.version,
    this.authMethod,
    this.passwordHash,
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
      'otp_verified': otpVerified,
      'version': version,
      'auth_method': authMethod,
      'password_hash': passwordHash,
      'password_changed': passwordChanged?.millisecondsSinceEpoch,
      'dashboard': dashboard?.toMap(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      memberId: map['memberId'] as String,
      phone: map['phone'] as String,
      token: map['token'] as String,
      otpVerified: map['otp_verified'] as bool? ?? false,
      version: map['version'] as String?,
      authMethod: map['auth_method'] as String?,
      passwordHash: map['password_hash'] as String?,
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
    bool? otpVerified,
    String? version,
    String? authMethod,
    String? passwordHash,
    DateTime? passwordChanged,
    Dashboard? dashboard,
  }) {
    return User(
      memberId: memberId ?? this.memberId,
      phone: phone ?? this.phone,
      token: token ?? this.token,
      otpVerified: otpVerified ?? this.otpVerified,
      version: version ?? this.version,
      authMethod: authMethod ?? this.authMethod,
      passwordHash: passwordHash ?? this.passwordHash,
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
        other.otpVerified == otpVerified &&
        other.version == version &&
        other.authMethod == authMethod &&
        other.passwordHash == passwordHash &&
        other.passwordChanged == passwordChanged &&
        other.dashboard == dashboard;
  }

  @override
  int get hashCode => Object.hash(
        memberId,
        phone,
        token,
        passwordHash,
        passwordChanged,
        dashboard,
      );
}
