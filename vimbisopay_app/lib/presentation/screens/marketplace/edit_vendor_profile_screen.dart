import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/vendor.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

/// Edit Vendor Profile Screen for the VimbisoPay app.
///
/// This screen allows vendors to edit their profile information.
class EditVendorProfileScreen extends StatefulWidget {
  /// The ID of the vendor to edit.
  final String vendorId;

  /// Creates a new [EditVendorProfileScreen] instance.
  const EditVendorProfileScreen({
    super.key,
    required this.vendorId,
  });

  @override
  State<EditVendorProfileScreen> createState() => _EditVendorProfileScreenState();
}

class _EditVendorProfileScreenState extends State<EditVendorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isLoading = true;
  String? _errorMessage;
  Vendor? _vendor;
  String? _profileImageUrl;
  File? _selectedImageFile;
  bool _isUploadingImage = false;
  
  final MarketplaceRepository _marketplaceRepository = ServiceLocator.marketplaceRepository;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadVendorData();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadVendorData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current user
      final currentUser = await ServiceLocator.databaseHelper.getUser();
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load user data';
        });
        return;
      }

      // Set profile image URL if available
      if (currentUser.dashboard?.member.profilePictureThumbnail != null) {
        _profileImageUrl = currentUser.dashboard!.member.profilePictureThumbnail;
        Logger.data('[EDIT_VENDOR] Found profile image URL: $_profileImageUrl');
      }
      
      // Find the user's personal account ID and name
      String businessName = 'My Business';
      if (currentUser.dashboard != null && currentUser.dashboard!.accounts.isNotEmpty) {
        // Try to find an account with accountType PERSONAL
        for (final account in currentUser.dashboard!.accounts) {
          if (account.accountType == 'PERSONAL') {
            businessName = account.accountName;
            Logger.data('[EDIT_VENDOR] Found PERSONAL account: ${account.accountID} (${account.accountName})');
            break;
          }
        }
        
        // If no account with accountType PERSONAL found, try to find by name
        if (businessName == 'My Business') {
          for (final account in currentUser.dashboard!.accounts) {
            if (account.accountName.toUpperCase().contains('PERSONAL')) {
              businessName = account.accountName;
              Logger.data('[EDIT_VENDOR] Found account with PERSONAL in name: ${account.accountID} (${account.accountName})');
              break;
            }
          }
        }
      }
      
      // If still not found, use the user's first name as fallback
      if (businessName == 'My Business' && currentUser.dashboard?.member.firstname != null) {
        businessName = currentUser.dashboard!.member.firstname;
        Logger.data('[EDIT_VENDOR] Using first name as business name: $businessName');
      }

      // Create a vendor object from the current user
      final vendor = Vendor(
        id: widget.vendorId,
        memberId: currentUser.memberId,
        businessName: businessName,
        description: '', // Will be populated from form or previous data
        email: '', // Will be populated from form or previous data
        phone: currentUser.phone,
        profileImageUrl: _profileImageUrl,
        rating: 0,
        ratingCount: 0,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Populate form fields with vendor data
      // If we have existing data in the controllers, keep it
      if (_businessNameController.text.isEmpty) {
        _businessNameController.text = vendor.businessName;
      }
      
      // Phone is always updated from the current user
      _phoneController.text = vendor.phone;
      
      setState(() {
        _isLoading = false;
        _vendor = vendor;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred: $e';
      });
    }
  }

  Future<void> _selectImage() async {
    try {
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );
      
      if (source == null) return;
      
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (pickedFile == null) return;
      
      setState(() {
        _selectedImageFile = File(pickedFile.path);
      });
      
      // Upload the image
      await _uploadImage();
      
    } catch (e) {
      Logger.error('[EDIT_VENDOR] Error selecting image', e);
      setState(() {
        _errorMessage = 'Failed to select image: $e';
      });
    }
  }
  
  Future<void> _uploadImage() async {
    if (_selectedImageFile == null) return;
    
    setState(() {
      _isUploadingImage = true;
    });
    
    try {
      // Get user to find digital asset account
      final user = await ServiceLocator.databaseHelper.getUser();
      if (user == null) {
        throw Exception('User not found');
      }
      
      Logger.data('[EDIT_VENDOR] User found, checking dashboard');
      if (user.dashboard == null) {
        throw Exception('User dashboard is null');
      }
      
      Logger.data('[EDIT_VENDOR] Dashboard found, checking accountsInternal');
      if (user.dashboard!.accountsInternal == null || user.dashboard!.accountsInternal.isEmpty) {
        Logger.error('[EDIT_VENDOR] accountsInternal is null or empty', user.dashboard?.toMap());
        throw Exception('Internal accounts not found. Please log out and log in again.');
      }
      
      // Log available account types for debugging
      final accountTypes = user.dashboard!.accountsInternal.map((a) => '${a.accountName}: ${a.accountType} (${a.accountID})').join(', ');
      Logger.data('[EDIT_VENDOR] Available internal accounts: $accountTypes');
      
      // Try to find OPERATIONS account in the internal accounts list
      String? digitalAssetAccountId;
      
      try {
        // First try to find by type OPERATIONS
        final operationsAccount = user.dashboard!.accountsInternal.firstWhere(
          (account) => account.accountType == 'OPERATIONS',
          orElse: () => throw Exception('No account with type OPERATIONS'),
        );
        digitalAssetAccountId = operationsAccount.accountID;
        Logger.data('[EDIT_VENDOR] Found OPERATIONS account: ${operationsAccount.accountName} (${operationsAccount.accountID})');
      } catch (e) {
        Logger.error('[EDIT_VENDOR] Error finding OPERATIONS account', e);
        
        // Fallback to original behavior: try to find DIGITAL_ASSET account
        try {
          final digitalAssetAccount = user.dashboard!.accountsInternal.firstWhere(
            (account) => account.accountType == 'DIGITAL_ASSET',
            orElse: () => throw Exception('No account with type DIGITAL_ASSET'),
          );
          digitalAssetAccountId = digitalAssetAccount.accountID;
          Logger.data('[EDIT_VENDOR] Found DIGITAL_ASSET account: ${digitalAssetAccount.accountName} (${digitalAssetAccount.accountID})');
        } catch (e) {
          Logger.error('[EDIT_VENDOR] Error finding DIGITAL_ASSET account', e);
          
          // Fallback: try to find by name
          try {
            final profilePicturesAccount = user.dashboard!.accountsInternal.firstWhere(
              (account) => account.accountName == 'Profile Pictures',
              orElse: () => throw Exception('No account named Profile Pictures'),
            );
            digitalAssetAccountId = profilePicturesAccount.accountID;
            Logger.data('[EDIT_VENDOR] Found account by name: ${profilePicturesAccount.accountName} (${profilePicturesAccount.accountID})');
          } catch (e) {
            Logger.error('[EDIT_VENDOR] Error finding account by name', e);
            
            // Last resort: use the first account in the list
            if (user.dashboard!.accountsInternal.isNotEmpty) {
              digitalAssetAccountId = user.dashboard!.accountsInternal.first.accountID;
              Logger.data('[EDIT_VENDOR] Using first available account: ${user.dashboard!.accountsInternal.first.accountName} (${user.dashboard!.accountsInternal.first.accountID})');
            } else {
              throw Exception('No internal accounts available');
            }
          }
        }
      }
      
      if (digitalAssetAccountId == null) {
        throw Exception('Could not determine account ID for image upload');
      }
      
      // Upload image
      Logger.data('[EDIT_VENDOR] Uploading image to account: $digitalAssetAccountId (Account Type: ${_getAccountTypeById(user, digitalAssetAccountId)})');
      final uploadResult = await _marketplaceRepository.uploadProfileImage(
        imagePath: _selectedImageFile!.path,
        drAccountId: digitalAssetAccountId,
      );
      
      await uploadResult.fold(
        (failure) {
          throw Exception(failure.message ?? 'Failed to upload image');
        },
        (assetIds) async {
          // Update profile pictures
          final updateResult = await _marketplaceRepository.updateProfilePictures(
            sourceId: digitalAssetAccountId!,
            originalAssetId: assetIds['originalAssetID']!,
            thumbnailAssetId: assetIds['originalAssetID']!,
            asset200Id: assetIds['asset200ID']!,
            asset600Id: assetIds['asset600ID']!,
          );
          
          await updateResult.fold(
            (failure) {
              throw Exception(failure.message ?? 'Failed to update profile pictures');
            },
            (success) async {
              // Refresh user data to get updated profile picture URL
              final updatedUser = await ServiceLocator.databaseHelper.getUser();
              if (updatedUser?.dashboard?.member.profilePictureThumbnail != null) {
                setState(() {
                  _profileImageUrl = updatedUser!.dashboard!.member.profilePictureThumbnail;
                });
              }
            },
          );
        },
      );
    } catch (e) {
      Logger.error('[EDIT_VENDOR] Error uploading image', e);
      setState(() {
        _errorMessage = 'Failed to upload image: $e';
      });
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  /// Helper method to get account type by ID
  String _getAccountTypeById(dynamic user, String accountId) {
    try {
      if (user?.dashboard?.accountsInternal != null) {
        for (final account in user.dashboard!.accountsInternal) {
          if (account.accountID == accountId) {
            return account.accountType;
          }
        }
      }
      
      // If not found in internal accounts, check regular accounts
      if (user?.dashboard?.accounts != null) {
        for (final account in user.dashboard!.accounts) {
          if (account.accountID == accountId) {
            return account.accountType;
          }
        }
      }
    } catch (e) {
      Logger.error('[EDIT_VENDOR] Error getting account type', e);
    }
    
    return 'Unknown';
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LoadingDialog(
        message: 'Updating vendor profile...',
      ),
    );

    try {
      // Update vendor details with updateMemberWithVendorDetails only
      final updateMemberResult = await _marketplaceRepository.updateMemberWithVendorDetails(
        vendorBio: _descriptionController.text,
      );
      
      // Dismiss loading dialog
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading dialog
      
      // Check result and navigate back
      updateMemberResult.fold(
        (failure) {
          // Show error message
          setState(() {
            _errorMessage = failure.message ?? 'Failed to update vendor profile';
          });
        },
        (_) {
          // Navigate back with success result
          Navigator.pop(context, {
            'success': true,
            'message': 'Vendor profile updated successfully',
          });
        },
      );
    } catch (e) {
      // Dismiss loading dialog
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading dialog
      
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Edit Vendor Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null && _vendor == null
                ? _buildErrorView()
                : _buildForm(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.errorRed,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.errorRed,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadVendorData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Profile Image
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      // Profile image
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.grey200,
                        backgroundImage: _selectedImageFile != null
                            ? FileImage(_selectedImageFile!)
                            : (_profileImageUrl != null
                                ? CachedNetworkImageProvider(_profileImageUrl!) as ImageProvider
                                : null),
                        child: _isUploadingImage
                            ? const CircularProgressIndicator()
                            : (_profileImageUrl == null && _selectedImageFile == null
                                ? const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: AppColors.grey,
                                  )
                                : null),
                      ),
                      
                      // Edit button overlay
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _selectImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Profile Image',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'This image will be used for your vendor profile',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGray,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Business Information
            const Text(
              'Business Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _businessNameController,
              decoration: const InputDecoration(
                labelText: 'Business Name',
                hintText: 'Enter your business name',
                prefixIcon: Icon(Icons.business),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your business name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Business Description',
                hintText: 'Describe your business',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            const SizedBox(height: 32),
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitForm,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
