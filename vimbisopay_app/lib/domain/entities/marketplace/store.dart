import 'package:vimbisopay_app/domain/entities/base_entity.dart';

/// Represents a store in the marketplace.
///
/// A store is a place where vendors sell their products.
/// Each store has information like name, description, and location.
class Store extends Entity {
  /// The unique identifier for the store.
  final String id;

  /// The name of the store.
  final String name;

  /// The handle (unique identifier) of the store.
  final String handle;

  /// A description of the store.
  final String description;

  /// Whether the store is currently open.
  final bool isOpen;

  /// The latitude of the store's location.
  final double? latitude;

  /// The longitude of the store's location.
  final double? longitude;

  /// Creates a new [Store] instance.
  Store({
    required this.id,
    required this.name,
    required this.handle,
    required this.description,
    required this.isOpen,
    this.latitude,
    this.longitude,
  }) : super(id);

  /// Creates a [Store] from a JSON map.
  factory Store.fromJson(Map<String, dynamic> json) {
    // Extract location data if available
    double? latitude;
    double? longitude;
    if (json.containsKey('location') && json['location'] is Map<String, dynamic>) {
      final location = json['location'] as Map<String, dynamic>;
      latitude = (location['latitude'] as num?)?.toDouble();
      longitude = (location['longitude'] as num?)?.toDouble();
    }

    return Store(
      id: json['id'] ?? '',
      name: json['storeName'] ?? '',
      handle: json['storeHandle'] ?? '',
      description: json['storeDescription'] ?? '',
      isOpen: json['storeOpen'] ?? false,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Converts this [Store] to a JSON map.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'id': id,
      'storeName': name,
      'storeHandle': handle,
      'storeDescription': description,
      'storeOpen': isOpen,
    };

    // Add location if both latitude and longitude are available
    if (latitude != null && longitude != null) {
      json['location'] = {
        'latitude': latitude,
        'longitude': longitude,
      };
    }

    return json;
  }

  /// Creates a copy of this [Store] with the given fields replaced.
  Store copyWith({
    String? id,
    String? name,
    String? handle,
    String? description,
    bool? isOpen,
    double? latitude,
    double? longitude,
  }) {
    return Store(
      id: id ?? this.id,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      description: description ?? this.description,
      isOpen: isOpen ?? this.isOpen,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Store &&
        other.id == id &&
        other.name == name &&
        other.handle == handle &&
        other.isOpen == isOpen;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        handle,
        isOpen,
      );
}
