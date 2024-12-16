class User {
  final String memberId;
  final String phone;
  final String token;
  final String tier;

  const User({
    required this.memberId,
    required this.phone,
    required this.token,
    this.tier = 'free', // Default to free tier
  });

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'phone': phone,
      'token': token,
      'tier': tier,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      memberId: map['memberId'] as String,
      phone: map['phone'] as String,
      token: map['token'] as String,
      tier: (map['tier'] as String?) ?? 'free', // Default to free if not present
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.memberId == memberId &&
        other.phone == phone &&
        other.token == token &&
        other.tier == tier;
  }

  @override
  int get hashCode => Object.hash(memberId, phone, token, tier);
}
