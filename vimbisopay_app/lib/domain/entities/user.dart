import 'package:vimbisopay_app/domain/entities/dashboard.dart';

class User {
  final String memberId;
  final String phone;
  final String token;
  final String? password;  // Added password field as optional
  final Dashboard? dashboard;  // Optional since it might not be available during local storage retrieval

  const User({
    required this.memberId,
    required this.phone,
    required this.token,
    this.password,
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
      'password': password,
      'dashboard': dashboard?.toMap(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      memberId: map['memberId'] as String,
      phone: map['phone'] as String,
      token: map['token'] as String,
      password: map['password'] as String?,
      dashboard: map['dashboard'] != null 
          ? Dashboard.fromMap(map['dashboard'] as Map<String, dynamic>)
          : null,
    );
  }

  User copyWith({
    String? memberId,
    String? phone,
    String? token,
    String? password,
    Dashboard? dashboard,
  }) {
    return User(
      memberId: memberId ?? this.memberId,
      phone: phone ?? this.phone,
      token: token ?? this.token,
      password: password ?? this.password,
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
        other.password == password &&
        other.dashboard == dashboard;
  }

  @override
  int get hashCode => Object.hash(memberId, phone, token, password, dashboard);
}
