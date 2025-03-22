class SecurityEvent {
  final String type;
  final String description;
  final DateTime timestamp;
  final String? deviceInfo;

  const SecurityEvent({
    required this.type,
    required this.description,
    required this.timestamp,
    this.deviceInfo,
  });

  // Event types
  static const String pinChange = 'PIN_CHANGE';
  static const String passwordChange = 'PASSWORD_CHANGE';
  static const String biometricEnabled = 'BIOMETRIC_ENABLED';
  static const String biometricDisabled = 'BIOMETRIC_DISABLED';
  static const String loginSuccess = 'LOGIN_SUCCESS';
  static const String loginFailed = 'LOGIN_FAILED';
  static const String logout = 'LOGOUT';

  String get formattedTimestamp {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  String get eventIcon {
    switch (type) {
      case pinChange:
        return '🔐';
      case passwordChange:
        return '🔑';
      case biometricEnabled:
      case biometricDisabled:
        return '👆';
      case loginSuccess:
        return '✅';
      case loginFailed:
        return '❌';
      case logout:
        return '👋';
      default:
        return '📝';
    }
  }

  factory SecurityEvent.fromJson(Map<String, dynamic> json) {
    return SecurityEvent(
      type: json['type'] as String,
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      deviceInfo: json['deviceInfo'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'deviceInfo': deviceInfo,
    };
  }
}
