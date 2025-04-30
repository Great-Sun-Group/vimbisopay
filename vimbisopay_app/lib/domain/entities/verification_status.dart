class VerificationStatus {
  final bool verified;
  final DateTime? verifiedAt;
  final String? verificationToken;
  final int? expiresIn;

  VerificationStatus({
    required this.verified,
    this.verifiedAt,
    this.verificationToken,
    this.expiresIn,
  });

  @override
  String toString() {
    return 'VerificationStatus{verified: $verified, verifiedAt: $verifiedAt, verificationToken: ${verificationToken != null ? '[REDACTED]' : 'null'}, expiresIn: $expiresIn}';
  }
}
