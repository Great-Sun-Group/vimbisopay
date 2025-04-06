import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/vendor_profile_screen.dart';
import 'package:vimbisopay_app/presentation/widgets/settings_container.dart';
import 'package:vimbisopay_app/presentation/widgets/transactions_list.dart';

/// Vendor Registration Screen for the VimbisoPay app.
///
/// This screen allows users to create a vendor profile to sell products
/// in the marketplace.
class VendorRegistrationScreen extends StatefulWidget {
  /// The ID of the member creating a vendor profile.
  final String memberId;
  
  /// The user data for pre-populating fields (optional)
  final User? user;

  /// Creates a new [VendorRegistrationScreen] instance.
  const VendorRegistrationScreen({
    super.key,
    required this.memberId,
    this.user,
  });

  @override
  State<VendorRegistrationScreen> createState() => _VendorRegistrationScreenState();
}

class _VendorRegistrationScreenState extends State<VendorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  final MarketplaceRepository _marketplaceRepository = ServiceLocator.marketplaceRepository;

  @override
  void initState() {
    super.initState();
    _prepopulateFieldsFromUser();
  }

  void _prepopulateFieldsFromUser() {
    if (widget.user?.dashboard != null) {
      final dashboard = widget.user!.dashboard!;
      
      // Pre-populate business name with user's name if available
      if (dashboard.member.firstname.isNotEmpty && dashboard.member.lastname.isNotEmpty) {
        _businessNameController.text = '${dashboard.member.firstname} ${dashboard.member.lastname}';
      }
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Step 1: Enable vendor functionality
      final enableResult = await _marketplaceRepository.enableVendorFunctionality();
      
      final enableSuccess = await enableResult.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message ?? 'Failed to enable vendor functionality';
          });
          return false;
        },
        (success) => true,
      );
      
      if (!enableSuccess) {
        return;
      }
      
      // Step 2: Update member profile with vendor details
      // Use the business name as the vendorBio since that's what we have
      final updateResult = await _marketplaceRepository.updateMemberWithVendorDetails(
        vendorBio: _businessNameController.text,
      );
      
      final updateSuccess = await updateResult.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message ?? 'Failed to update member profile';
          });
          return false;
        },
        (success) => true,
      );
      
      if (!updateSuccess) {
        return;
      }
      
      // Step 3: Create the vendor profile in the local repository
      final result = await _marketplaceRepository.createVendor(
        memberId: widget.memberId,
        businessName: _businessNameController.text,
        description: _descriptionController.text,
        email: "", // Empty string since Contact Information section is removed
        phone: "", // Empty string since Contact Information section is removed
      );

      result.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message ?? 'Failed to create vendor profile';
          });
        },
        (vendor) {
          Logger.data('Vendor profile created: ${vendor.id}');
          
          if (!mounted) return;
          
          // Navigate directly to vendor profile screen without delay
          // This avoids the widget lifecycle issue
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VendorProfileScreen(
                vendorId: vendor.id,
                isOwner: true,
                showSuccessMessage: true, // Show success message on the next screen
              ),
            ),
          );
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
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
          'Become a Vendor',
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
            ? const Center(child: InlineLoadingAnimation(size: 80))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Introduction
                      const Text(
                        'Create your vendor profile to start selling in the marketplace.',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Error message
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
                      
                      // Business Information
                      SettingsContainer(
                        title: 'Business Information',
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Business Name
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
                                
                                // Business Description
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
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Terms and Conditions
                      SettingsContainer(
                        title: 'Terms and Conditions',
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'By creating a vendor profile, you agree to the Vimbiso Market Terms and Conditions for vendors.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () {
                                    // TODO: Show terms and conditions
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Terms and conditions coming soon'),
                                      ),
                                    );
                                  },
                                  child: const Text('View Terms and Conditions'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
                            'Create Vendor Profile',
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
              ),
      ),
    );
  }
}
