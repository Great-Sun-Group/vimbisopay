class SecurityEvent {
  final String id;
  final String eventIcon;
  final String description;
  final DateTime timestamp;
  final String? deviceInfo;
  final String? ipAddress;
  final String? location;
  final String eventType;

  const SecurityEvent({
    required this.id,
    required this.eventIcon,
    required this.description,
    required this.timestamp,
    this.deviceInfo,
    this.ipAddress,
    this.location,
    required this.eventType,
  });

  String get formattedTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventIcon': eventIcon,
      'description': description,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'deviceInfo': deviceInfo,
      'ipAddress': ipAddress,
      'location': location,
      'eventType': eventType,
    };
  }

  factory SecurityEvent.fromMap(Map<String, dynamic> map) {
    return SecurityEvent(
      id: map['id'] as String,
      eventIcon: map['eventIcon'] as String,
      description: map['description'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      deviceInfo: map['deviceInfo'] as String?,
      ipAddress: map['ipAddress'] as String?,
      location: map['location'] as String?,
      eventType: map['eventType'] as String,
    );
  }

  SecurityEvent copyWith({
    String? id,
    String? eventIcon,
    String? description,
    DateTime? timestamp,
    String? deviceInfo,
    String? ipAddress,
    String? location,
    String? eventType,
  }) {
    return SecurityEvent(
      id: id ?? this.id,
      eventIcon: eventIcon ?? this.eventIcon,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      ipAddress: ipAddress ?? this.ipAddress,
      location: location ?? this.location,
      eventType: eventType ?? this.eventType,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SecurityEvent &&
        other.id == id &&
        other.eventIcon == eventIcon &&
        other.description == description &&
        other.timestamp == timestamp &&
        other.deviceInfo == deviceInfo &&
        other.ipAddress == ipAddress &&
        other.location == location &&
        other.eventType == eventType;
  }

  @override
  int get hashCode => Object.hash(
        id,
        eventIcon,
        description,
        timestamp,
        deviceInfo,
        ipAddress,
        location,
        eventType,
      );

  @override
  String toString() {
    return '''SecurityEvent {
  id: $id,
  eventIcon: $eventIcon,
  description: $description,
  timestamp: $timestamp,
  deviceInfo: $deviceInfo,
  ipAddress: $ipAddress,
  location: $location,
  eventType: $eventType
}''';
  }
}

// Common security event types
class SecurityEventType {
  static const String login = 'login';
  static const String logout = 'logout';
  static const String passwordChange = 'password_change';
  static const String pinChange = 'pin_change';
  static const String accountLocked = 'account_locked';
  static const String accountUnlocked = 'account_unlocked';
  static const String suspiciousActivity = 'suspicious_activity';
  static const String deviceRegistered = 'device_registered';
  static const String deviceRemoved = 'device_removed';
  static const String twoFactorEnabled = 'two_factor_enabled';
  static const String twoFactorDisabled = 'two_factor_disabled';
}

// Common security event icons
class SecurityEventIcons {
  static const String login = '🔐';
  static const String logout = '🚪';
  static const String passwordChange = '🔑';
  static const String pinChange = '🔢';
  static const String accountLocked = '🔒';
  static const String accountUnlocked = '🔓';
  static const String suspiciousActivity = '⚠️';
  static const String deviceRegistered = '📱';
  static const String deviceRemoved = '📵';
  static const String twoFactorEnabled = '🛡️';
  static const String twoFactorDisabled = '🚫';
}
