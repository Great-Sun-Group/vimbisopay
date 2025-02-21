class OtpVerificationResponse {
  final String id;
  final String type;
  final String timestamp;
  final String actor;
  final OtpVerificationDetails details;

  OtpVerificationResponse({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.actor,
    required this.details,
  });

  factory OtpVerificationResponse.fromJson(Map<String, dynamic> json) {
    final action = json['data']['action'];
    return OtpVerificationResponse(
      id: action['id'],
      type: action['type'],
      timestamp: action['timestamp'],
      actor: action['actor'],
      details: OtpVerificationDetails.fromJson(action['details']),
    );
  }
}

class OtpVerificationDetails {
  final String memberId;
  final bool otpVerified;
  final String resetToken;
  final String purpose;
  final int expiresIn;

  OtpVerificationDetails({
    required this.memberId,
    required this.otpVerified,
    required this.resetToken,
    required this.purpose,
    required this.expiresIn,
  });

  factory OtpVerificationDetails.fromJson(Map<String, dynamic> json) {
    return OtpVerificationDetails(
      memberId: json['memberID'],
      otpVerified: json['otpVerified'],
      resetToken: json['resetToken'],
      purpose: json['purpose'],
      expiresIn: json['expiresIn'],
    );
  }
}
