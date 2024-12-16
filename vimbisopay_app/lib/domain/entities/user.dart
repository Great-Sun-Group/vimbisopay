class User {
  final String memberId;
  final String phone;
  final String token;

  const User({
    required this.memberId,
    required this.phone,
    required this.token,
  });

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'phone': phone,
      'token': token,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      memberId: map['memberId'] as String,
      phone: map['phone'] as String,
      token: map['token'] as String,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.memberId == memberId &&
        other.phone == phone &&
        other.token == token;
  }

  @override
  int get hashCode => Object.hash(memberId, phone, token);
}
