import 'package:vimbisopay_app/domain/entities/base_entity.dart';

/// Represents an asset marker in the marketplace.
///
/// An asset marker is a digital token that represents ownership of a product.
/// It is used to track ownership and transfers of products in the marketplace.
class AssetMarker extends Entity {
  /// The unique identifier for the asset marker.
  @override
  final String id;

  /// The ID of the product associated with this asset marker.
  final String productId;

  /// The ID of the current owner (member).
  final String ownerId;

  /// The ID of the creator (vendor).
  final String creatorId;

  /// The quantity of the asset.
  final int quantity;

  /// The status of the asset marker.
  final AssetMarkerStatus status;

  /// The date when the asset marker was created.
  final DateTime createdAt;

  /// The date when the asset marker was last updated.
  final DateTime updatedAt;

  /// The date when the asset marker was last transferred, if applicable.
  final DateTime? lastTransferredAt;

  /// Creates a new [AssetMarker] instance.
  AssetMarker({
    required this.id,
    required this.productId,
    required this.ownerId,
    required this.creatorId,
    required this.quantity,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.lastTransferredAt,
  }) : super(id);

  /// Creates an [AssetMarker] from a JSON map.
  factory AssetMarker.fromJson(Map<String, dynamic> json) {
    return AssetMarker(
      id: json['id'],
      productId: json['product_id'],
      ownerId: json['owner_id'],
      creatorId: json['creator_id'],
      quantity: json['quantity'],
      status: AssetMarkerStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => AssetMarkerStatus.active,
      ),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      lastTransferredAt: json['last_transferred_at'] != null
          ? DateTime.parse(json['last_transferred_at'])
          : null,
    );
  }

  /// Converts this [AssetMarker] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'owner_id': ownerId,
      'creator_id': creatorId,
      'quantity': quantity,
      'status': status.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_transferred_at': lastTransferredAt?.toIso8601String(),
    };
  }

  /// Checks if the asset marker is transferable.
  bool get isTransferable => status == AssetMarkerStatus.active;

  /// Creates a copy of this [AssetMarker] with the given fields replaced.
  AssetMarker copyWith({
    String? id,
    String? productId,
    String? ownerId,
    String? creatorId,
    int? quantity,
    AssetMarkerStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastTransferredAt,
  }) {
    return AssetMarker(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      ownerId: ownerId ?? this.ownerId,
      creatorId: creatorId ?? this.creatorId,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastTransferredAt: lastTransferredAt ?? this.lastTransferredAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AssetMarker &&
        other.id == id &&
        other.productId == productId &&
        other.ownerId == ownerId &&
        other.creatorId == creatorId &&
        other.quantity == quantity &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(
        id,
        productId,
        ownerId,
        creatorId,
        quantity,
        status,
      );
}

/// Represents the status of an asset marker.
enum AssetMarkerStatus {
  /// The asset marker is active and can be transferred.
  active,

  /// The asset marker is locked and cannot be transferred.
  locked,

  /// The asset marker has been consumed or used.
  consumed,

  /// The asset marker has been cancelled.
  cancelled,
}
