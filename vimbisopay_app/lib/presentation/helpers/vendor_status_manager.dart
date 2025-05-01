import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';

/// A helper class for managing vendor status in the marketplace.
class VendorStatusManager {
  final MarketplaceRepository _marketplaceRepository;
  final DatabaseHelper _databaseHelper;
  
  bool _isCheckingVendorStatus = false;
  bool _isVendor = false;
  String? _memberId;
  String? _vendorId;
  String? _personalAccountId;

  VendorStatusManager(this._marketplaceRepository, this._databaseHelper);

  /// Gets whether the current user is a vendor.
  bool get isVendor => _isVendor;

  /// Gets the vendor ID of the current user.
  String? get vendorId => _vendorId;

  /// Gets the personal account ID of the current user.
  String? get personalAccountId => _personalAccountId;

  /// Gets the member ID of the current user.
  String? get memberId => _memberId;

  /// Gets whether the vendor status is currently being checked.
  bool get isCheckingVendorStatus => _isCheckingVendorStatus;

  /// Checks if the current user is a vendor.
  Future<void> checkVendorStatus({
    required Function(bool) onCheckingStateChanged,
    required Function(bool, String?, String?, String?) onVendorStatusChanged,
  }) async {
    try {
      _isCheckingVendorStatus = true;
      onCheckingStateChanged(_isCheckingVendorStatus);

      // Get current user from database
      final user = await _databaseHelper.getUser();
      
      if (user == null) {
        Logger.state('No user found in database');
        _isCheckingVendorStatus = false;
        onCheckingStateChanged(_isCheckingVendorStatus);
        return;
      }
      
      _memberId = user.memberId;
      
      // Find the user's personal account ID
      if (user.dashboard != null && user.dashboard!.accounts.isNotEmpty) {
        // Try to find an account with accountType PERSONAL
        for (final account in user.dashboard!.accounts) {
          if (account.accountType == 'PERSONAL') {
            _personalAccountId = account.accountID;
            Logger.data('[MARKETPLACE] Found PERSONAL account: $_personalAccountId (${account.accountName})');
            break;
          }
        }
        
        // If no account with accountType PERSONAL found, try to find by name
        if (_personalAccountId == null) {
          for (final account in user.dashboard!.accounts) {
            if (account.accountName.toUpperCase().contains('PERSONAL')) {
              _personalAccountId = account.accountID;
              Logger.data('[MARKETPLACE] Found account with PERSONAL in name: $_personalAccountId (${account.accountName})');
              break;
            }
          }
        }
      }

      if (_memberId != null) {
        // Check if user is a vendor
        final isVendor = await _marketplaceRepository.isMemberVendor(_memberId!);

        _isVendor = isVendor;
        if (isVendor) {
          // If user is a vendor, set the vendor ID to the member ID
          _vendorId = _memberId; // Use member ID as vendor ID
        } else {
          _vendorId = null;
        }
        
        onVendorStatusChanged(_isVendor, _memberId, _vendorId, _personalAccountId);
      }
    } catch (e) {
      Logger.error('Error checking vendor status', e);
    } finally {
      _isCheckingVendorStatus = false;
      onCheckingStateChanged(_isCheckingVendorStatus);
    }
  }

  /// Checks if the user can become a vendor.
  bool canBecomeVendor(User? user) {
    // If there's no user, don't allow becoming a vendor as guest
    if (user == null) return false;
    
    // Check the activateMarket property directly on the User object
    // This property is set from either the User.activateMarket field or
    // from the Dashboard.activateMarket field for backward compatibility
    // activateMarket == false means we should prompt the user to become a vendor
    // activateMarket == true means the user is already a vendor
    return !user.activateMarket;
  }

  /// Gets the current user from the database.
  Future<User?> getUser() {
    return _databaseHelper.getUser();
  }
}
