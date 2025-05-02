import 'package:vimbisopay_app/domain/entities/dashboard.dart';

class User {
  final String memberId;
  final String phone;
  final String token;
  final bool otpVerified;  // Whether OTP verification is complete
  final String? version;  // API version (v1, v2)
  final String? authMethod;  // Authentication method (phone_only, etc)
  // Deprecated: These fields are kept for backward compatibility but are no longer used
  final String? passwordHash;  // Deprecated: Hashed password (no longer used)
  final DateTime? passwordChanged;  // Deprecated: When the password was last changed (no longer used)
  final Dashboard? dashboard;  // Optional since it might not be available during local storage retrieval
  final bool activateMarket;  // Whether the user is already a vendor in the marketplace
  final bool storeOpen;  // Whether the vendor's store is currently open
  final double? latitude;  // The vendor's current location (latitude)
  final double? longitude;  // The vendor's current location (longitude)

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
    this.activateMarket = false,
    this.storeOpen = false,
    this.latitude,
    this.longitude,
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
      'activate_market': activateMarket,
      'store_open': storeOpen,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    // Get dashboard if available
    final dashboardMap = map['dashboard'] as Map<String, dynamic>?;
    final dashboard = dashboardMap != null ? Dashboard.fromMap(dashboardMap) : null;
    
    // Check for activateMarket in the map or in the dashboard for backward compatibility
    bool activateMarket = false;
    if (map.containsKey('activate_market')) {
      activateMarket = map['activate_market'] as bool? ?? false;
    } else if (dashboard != null && dashboardMap!.containsKey('activateMarket')) {
      activateMarket = dashboardMap['activateMarket'] as bool? ?? false;
    }
    
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
      dashboard: dashboard,
      activateMarket: activateMarket,
      storeOpen: map['store_open'] as bool? ?? false,
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
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
    bool? activateMarket,
    bool? storeOpen,
    double? latitude,
    double? longitude,
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
      activateMarket: activateMarket ?? this.activateMarket,
      storeOpen: storeOpen ?? this.storeOpen,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
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
        other.dashboard == dashboard &&
        other.activateMarket == activateMarket &&
        other.storeOpen == storeOpen &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(
        memberId,
        phone,
        token,
        passwordHash,
        passwordChanged,
        dashboard,
        activateMarket,
        storeOpen,
        latitude,
        longitude,
      );

  @override
  String toString() {
    return '''User {
  memberId: $memberId,
  phone: $phone,
  otpVerified: $otpVerified,
  version: $version,
  authMethod: $authMethod,
  passwordHash: ${passwordHash != null ? '[REDACTED]' : 'null'},
  passwordChanged: $passwordChanged,
  dashboard: ${dashboard != null ? '[Dashboard Present]' : 'null'},
  activateMarket: $activateMarket,
  storeOpen: $storeOpen,
  location: ${latitude != null && longitude != null ? '($latitude, $longitude)' : 'null'}
}''';
  }
}
