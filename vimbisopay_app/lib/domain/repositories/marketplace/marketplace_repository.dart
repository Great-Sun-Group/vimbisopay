import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:dartz/dartz.dart';

/// Repository interface for marketplace operations.
///
/// This repository handles all marketplace-related operations, including
/// vendor management, product listings, and invoicing.
abstract class MarketplaceRepository {
  /// Enables vendor functionality for a member.
  ///
  /// When enabled, creates required internal accounts if they don't exist.
  /// Returns true if successful, or a [Failure] if an error occurs.
  Future<Either<Failure, bool>> enableVendorFunctionality();

  /// Updates a member's profile with vendor details.
  ///
  /// Returns true if successful, or a [Failure] if an error occurs.
  Future<Either<Failure, bool>> updateMemberWithVendorDetails({
    String? firstname,
    String? lastname,
    String? memberHandle,
    String? vendorBio,
  });
  
  /// Checks if a member is a vendor.
  ///
  /// Returns true if the member is a vendor, false otherwise.
  Future<bool> isMemberVendor(String memberId);

  /// Creates a new vendor.
  ///
  /// Returns the created [Vendor] if successful, or a [Failure] if an error occurs.
  Future<Either<Failure, Vendor>> createVendor({
    required String memberId,
    required String businessName,
    required String description,
    required String email,
    required String phone,
    String? profileImageUrl,
    String? bannerImageUrl,
  });

  /// Updates an existing vendor.
  ///
  /// Returns the updated [Vendor] if successful, or a [Failure] if an error occurs.
  Future<Either<Failure, Vendor>> updateVendor({
    required String id,
    String? businessName,
    String? description,
    String? email,
    String? phone,
    String? profileImageUrl,
    String? bannerImageUrl,
    bool? isActive,
  });

  /// Gets a product by ID.
  ///
  /// Returns a [Product] if found, or a [Failure] if an error occurs.
  Future<Either<Failure, Product>> getProduct(String id);


  /// Gets products by category.
  ///
  /// Returns a list of [Product]s if found, or a [Failure] if an error occurs.
  Future<Either<Failure, List<Product>>> getProductsByCategory(String category);

  /// Searches for products by query.
  ///
  /// Returns a list of [Product]s if found, or a [Failure] if an error occurs.
  Future<Either<Failure, List<Product>>> searchProducts(String query);

  /// Creates an internal account for a product.
  ///
  /// Returns the account ID if successful, or a [Failure] if an error occurs.
  Future<Either<Failure, String>> createInternalAccount({
    required String accountName,
    required String defaultDenom,
    required String accountType,
  });

  /// Creates a new product.
  ///
  /// Returns the created [Product] if successful, or a [Failure] if an error occurs.
  Future<Either<Failure, Product>> createProduct({
    required String vendorId,
    required String name,
    required String description,
    required int price,
    required String currency,
    required List<String> imageUrls,
    required String category,
    required List<String> tags,
    required bool isAvailable,
    String? accountId,
  });

  /// Updates an existing product.
  ///
  /// Returns the updated [Product] if successful, or a [Failure] if an error occurs.
  Future<Either<Failure, Product>> updateProduct({
    required String id,
    String? name,
    String? description,
    int? price,
    String? currency,
    List<String>? imageUrls,
    String? category,
    List<String>? tags,
    bool? isAvailable,
    String? accountId,
  });

  /// Gets an invoice by ID.
  ///
  /// Returns an [Invoice] if found, or a [Failure] if an error occurs.
  Future<Either<Failure, Invoice>> getInvoice(String id);

  /// Gets invoices by buyer ID.
  ///
  /// Returns a list of [Invoice]s if found, or a [Failure] if an error occurs.
  Future<Either<Failure, List<Invoice>>> getInvoicesByBuyer(String buyerId);

  /// Gets invoices by vendor ID.
  ///
  /// Returns a list of [Invoice]s if found, or a [Failure] if an error occurs.
  Future<Either<Failure, List<Invoice>>> getInvoicesByVendor(String vendorId);

  /// Creates a new invoice.
  ///
  /// Returns the created [Invoice] if successful, or a [Failure] if an error occurs.
  Future<Either<Failure, Invoice>> createInvoice({
    required String buyerId,
    required String vendorId,
    required List<InvoiceLineItem> lineItems,
    required int totalAmount,
    required String currency,
    required String paymentMethod,
    String? notes,
  });

  /// Updates an existing invoice.
  ///
  /// Returns the updated [Invoice] if successful, or a [Failure] if an error occurs.
  Future<Either<Failure, Invoice>> updateInvoice({
    required String id,
    InvoiceStatus? status,
    String? notes,
    DateTime? paidAt,
  });
  
  /// Creates a Credex offer for an invoice payment.
  ///
  /// Returns the updated [Invoice] if successful, or a [Failure] if an error occurs.
  Future<Either<Failure, Invoice>> createCredexOffer({
    required String invoiceId,
    required String accountId,
    required int amount,
    String? note,
  });

  /// Gets an asset marker by ID.
  ///
  /// Returns an [AssetMarker] if found, or a [Failure] if an error occurs.
  Future<Either<Failure, AssetMarker>> getAssetMarker(String id);

  /// Gets asset markers by product ID.
  ///
  /// Returns a list of [AssetMarker]s if found, or a [Failure] if an error occurs.
  Future<Either<Failure, List<AssetMarker>>> getAssetMarkersByProduct(
      String productId);

  /// Gets asset markers by owner ID.
  ///
  /// Returns a list of [AssetMarker]s if found, or a [Failure] if an error occurs.
  Future<Either<Failure, List<AssetMarker>>> getAssetMarkersByOwner(
      String ownerId);

  /// Creates a new asset marker.
  ///
  /// Returns the created [AssetMarker] if successful, or a [Failure] if an error occurs.
  Future<Either<Failure, AssetMarker>> createAssetMarker({
    required String productId,
    required String ownerId,
    required String creatorId,
    required int quantity,
    required AssetMarkerStatus status,
  });

  /// Updates an existing asset marker.
  ///
  /// Returns the updated [AssetMarker] if successful, or a [Failure] if an error occurs.
  Future<Either<Failure, AssetMarker>> updateAssetMarker({
    required String id,
    String? ownerId,
    int? quantity,
    AssetMarkerStatus? status,
    DateTime? lastTransferredAt,
  });

  /// Transfers an asset marker to a new owner.
  ///
  /// Returns the updated [AssetMarker] if successful, or a [Failure] if an error occurs.
  Future<Either<Failure, AssetMarker>> transferAssetMarker({
    required String id,
    required String newOwnerId,
  });
  
  /// Uploads a profile image and optimizes it.
  ///
  /// Returns a map of asset IDs if successful, or a [Failure] if an error occurs.
  /// The map contains keys: 'originalAssetID', 'asset200ID', and 'asset600ID'.
  Future<Either<Failure, Map<String, String>>> uploadProfileImage({
    required String imagePath,
    required String drAccountId,
    String? crAccountId,
  });

  /// Updates a member's profile pictures with the given asset IDs.
  ///
  /// Returns true if successful, or a [Failure] if an error occurs.
  Future<Either<Failure, bool>> updateProfilePictures({
    required String sourceId,
    required String originalAssetId,
    required String thumbnailAssetId,
    required String asset200Id,
    required String asset600Id,
  });
}
