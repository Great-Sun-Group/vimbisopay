import 'package:vimbisopay_app/domain/entities/base_entity.dart';

/// Represents a vendor in the marketplace.
///
/// A vendor is a member who sells products or services in the marketplace.
/// Each vendor has a profile with business information, ratings, and product listings.
class Vendor extends Entity {
  /// The unique identifier for the vendor.
  final String id;

  /// The member ID associated with this vendor.
  final String memberId;

  /// The business name of the vendor.
  final String businessName;

  /// A description of the vendor's business.
  final String description;

  /// Contact email for the vendor.
  final String email;

  /// Contact phone number for the vendor.
  final String phone;

  /// URL to the vendor's profile image.
  final String? profileImageUrl;

  /// URL to the vendor's banner image.
  final String? bannerImageUrl;

  /// The vendor's average rating (0-5).
  final double rating;

  /// The number of ratings received.
  final int ratingCount;

  /// Whether the vendor is currently active.
  final bool isActive;

  /// The date when the vendor was created.
  final DateTime createdAt;

  /// The date when the vendor was last updated.
  final DateTime updatedAt;

  /// Creates a new [Vendor] instance.
  Vendor({
    required this.id,
    required this.memberId,
    required this.businessName,
    required this.description,
    required this.email,
    required this.phone,
    this.profileImageUrl,
    this.bannerImageUrl,
    required this.rating,
    required this.ratingCount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  }) : super(id);

  /// Creates a [Vendor] from a JSON map.
  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id'],
      memberId: json['member_id'],
      businessName: json['business_name'],
      description: json['description'],
      email: json['email'],
      phone: json['phone'],
      profileImageUrl: json['profile_image_url'],
      bannerImageUrl: json['banner_image_url'],
      rating: (json['rating'] as num).toDouble(),
      ratingCount: json['rating_count'],
      isActive: json['is_active'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  /// Converts this [Vendor] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'member_id': memberId,
      'business_name': businessName,
      'description': description,
      'email': email,
      'phone': phone,
      'profile_image_url': profileImageUrl,
      'banner_image_url': bannerImageUrl,
      'rating': rating,
      'rating_count': ratingCount,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Returns a formatted display name for the vendor.
  String get displayName => businessName;

  /// Returns a formatted rating string (e.g., "4.5 (42 reviews)").
  String get ratingDisplay => '$rating (${ratingCount} reviews)';

  /// Creates a copy of this [Vendor] with the given fields replaced.
  Vendor copyWith({
    String? id,
    String? memberId,
    String? businessName,
    String? description,
    String? email,
    String? phone,
    String? profileImageUrl,
    String? bannerImageUrl,
    double? rating,
    int? ratingCount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vendor(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      businessName: businessName ?? this.businessName,
      description: description ?? this.description,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Vendor &&
        other.id == id &&
        other.memberId == memberId &&
        other.businessName == businessName &&
        other.email == email &&
        other.phone == phone &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(
        id,
        memberId,
        businessName,
        email,
        phone,
        isActive,
      );
}
