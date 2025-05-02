import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/widgets/initials_avatar.dart';
import 'package:vimbisopay_app/presentation/widgets/settings_container.dart';
import 'package:vimbisopay_app/presentation/widgets/member_tier_badge.dart';
import 'package:vimbisopay_app/application/usecases/upgrade_member_tier.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  bool _isLoading = true;
  String? _error;
  User? _user;
  bool _isVendor = false;
  bool _isCheckingVendorStatus = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final stopwatch = Stopwatch()..start();
    Logger.lifecycle('Starting profile data load');
    
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      Logger.state('Set loading state to true');

      Logger.state('Attempting to read User from database');
      final user = await ServiceLocator.databaseHelper.getUser();
      
      if (user == null) {
        Logger.error('User data is null');
        throw Exception('User data not available. Please log in again.');
      }
      
      Logger.data('User data retrieved - MemberId: ${user.memberId}, Phone: ${user.phone}');
      
      // Validate dashboard data
      if (user.dashboard == null) {
        Logger.error('Dashboard data is null');
        throw Exception('Profile data not available. Please try again later.');
      }
      
      final dashboard = user.dashboard!;
      Logger.data('''Dashboard validation successful:
        FirstName: ${dashboard.firstname}
        LastName: ${dashboard.lastname}
        MemberHandle: ${dashboard.member.memberHandle ?? 'Missing member handle'}
        Raw MemberHandle Value: ${dashboard.member.memberHandle}
        MemberHandle Type: ${dashboard.member.memberHandle?.runtimeType}
        MemberTier: ${dashboard.memberTier.type.name}
      ''');

      if (dashboard.member.memberHandle == null) {
        Logger.state('Member handle is null in dashboard data');
      } else if (dashboard.member.memberHandle!.isEmpty) {
        Logger.state('Member handle is empty string in dashboard data');
      } else {
        Logger.state('Member handle found: ${dashboard.member.memberHandle}');
      }
      
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
        Logger.state('Profile data loaded and state updated');
      }

      // Check if the user is a vendor
      _checkVendorStatus(user.memberId);

      stopwatch.stop();
      Logger.performance('Profile data load completed in ${stopwatch.elapsedMilliseconds}ms');
      
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to load profile data',
        e,
        stackTrace
      );
      
      if (mounted) {
        setState(() {
          _error = e is ProviderNotFoundException 
              ? 'User session not found. Please log in again.'
              : e.toString();
          _isLoading = false;
        });
        Logger.state('Error state set: $_error');
      }
    }
  }

  Future<void> _checkVendorStatus(String memberId) async {
    try {
      setState(() {
        _isCheckingVendorStatus = true;
      });

      final marketplaceRepository = ServiceLocator.marketplaceRepository;
      final isVendor = await marketplaceRepository.isMemberVendor(memberId);

      if (mounted) {
        setState(() {
          _isVendor = isVendor;
          _isCheckingVendorStatus = false;
        });
      }
    } catch (e) {
      Logger.error('Error checking vendor status', e);
      if (mounted) {
        setState(() {
          _isVendor = false;
          _isCheckingVendorStatus = false;
        });
      }
    }
  }

  void _navigateToVendorRegistration() {
    if (_user == null) return;
    
    Navigator.pushNamed(
      context,
      '/vendor-registration',
      arguments: {
        'memberId': _user!.memberId,
      },
    ).then((_) {
      // Refresh vendor status when returning from registration
      if (_user != null) {
        _checkVendorStatus(_user!.memberId);
      }
    });
  }

  void _navigateToVendorProfile() async {
    // if (_user == null) return;
    
    // try {
    //   setState(() {
    //     _isLoading = true;
    //   });
      
    //   final marketplaceRepository = ServiceLocator.marketplaceRepository;
    //   final result = await marketplaceRepository.getVendorByMemberId(_user!.memberId);
      
    //   setState(() {
    //     _isLoading = false;
    //   });
      
    //   result.fold(
    //     (failure) {
    //       ScaffoldMessenger.of(context).showSnackBar(
    //         SnackBar(
    //           content: Text(
    //             failure.message ?? 'Failed to load vendor profile',
    //             style: const TextStyle(color: AppColors.lightCream),
    //           ),
    //           backgroundColor: AppColors.errorRed,
    //         ),
    //       );
    //     },
    //     (vendor) {
    //       Navigator.push(
    //         context,
    //         MaterialPageRoute(
    //           builder: (context) => VendorProfileScreen(
    //             vendorId: vendor.id,
    //             isOwner: true,
    //           ),
    //         ),
    //       ).then((_) {
    //         // Refresh vendor status when returning from profile
    //         if (_user != null) {
    //           _checkVendorStatus(_user!.memberId);
    //         }
    //       });
    //     },
    //   );
    // } catch (e) {
    //   setState(() {
    //     _isLoading = false;
    //   });
      
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text(
    //         'An error occurred: $e',
    //         style: const TextStyle(color: AppColors.lightCream),
    //       ),
    //       backgroundColor: AppColors.errorRed,
    //     ),
    //   );
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Profile Settings',
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
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadUserData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
            // Profile Avatar Section
            Center(
              child: InitialsAvatar(
                firstName: _user?.dashboard?.firstname ?? '',
                lastName: _user?.dashboard?.lastname ?? '',
              ),
            ),
            const SizedBox(height: 32),

            // Profile Information Section
            SettingsContainer(
              title: 'Profile Information',
              children: [
                SettingsListTile(
                  title: 'First Name',
                  subtitle: _user?.dashboard?.firstname ?? 'Not set',
                  icon: Icons.person_outline,
                ),
                SettingsListTile(
                  title: 'Last Name',
                  subtitle: _user?.dashboard?.lastname ?? 'Not set',
                  icon: Icons.person_outline,
                ),
                SettingsListTile(
                  title: 'Member Handle',
                  subtitle: _user?.dashboard?.member.memberHandle != null
                      ? '@${_user!.dashboard!.member.memberHandle}'
                      : 'Not set',
                  icon: Icons.alternate_email,
                ),
                SettingsListTile(
                  title: 'Phone Number',
                  subtitle: _user?.phone ?? 'Not set',
                  icon: Icons.phone_outlined,
                  showDivider: false,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Membership Status Section
            SettingsContainer(
              title: 'Membership Status',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          MemberTierBadge(
                            tierType: _user?.dashboard?.memberTier.type ?? MemberTierType.open,
                          ),
                          if (_user?.dashboard?.memberTier.type == MemberTierType.open) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () async {
                                try {
                                  // Find the personal account ID (owned account)
                                  final personalAccount = _user?.dashboard?.accounts.firstWhere(
                                    (account) => account.isOwnedAccount,
                                    orElse: () => _user!.dashboard!.accounts.first,
                                  );
                                  
                                  final sourceAccountId = personalAccount?.accountID;
                                  Logger.data('[UPGRADE_MEMBERSHIP] Using account ID: $sourceAccountId (isOwnedAccount: ${personalAccount?.isOwnedAccount})');
                                  
                                  if (sourceAccountId != null) {
                                    // Show loading dialog
                                    if (!context.mounted) return;
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => const LoadingDialog(
                                        message: 'Upgrading membership...',
                                      ),
                                    );

                                    // Create UpgradeMemberTier instance using accountRepository from ServiceLocator
                                    final upgradeMemberTier = UpgradeMemberTier(ServiceLocator.accountRepository);
                                    await upgradeMemberTier(sourceAccountId);
                                    
                                    // Dismiss loading dialog
                                    if (!context.mounted) return;
                                    Navigator.pop(context);

                                    // Use post-frame callback to ensure widget tree is stable
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (context.mounted) {
                                        try {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Membership upgrade initiated successfully'),
                                              backgroundColor: AppColors.success,
                                            ),
                                          );
                                        } catch (snackBarError) {
                                          Logger.error('Error showing success snackbar', snackBarError);
                                        }
                                      }
                                    });
                                    
                                    _loadUserData(); // Refresh to show updated status
                                  }
                                } catch (e) {
                                  // Log the actual error for debugging
                                  Logger.error('Failed to upgrade membership', e);
                                  
                                  // Dismiss loading dialog
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    
                                    // Default error message
                                    String userFriendlyMessage = 'Unable to upgrade membership at this time. Please try again later.';
                                    
                                    // Check for specific error codes
                                    final errorMessage = e.toString();
                                    if (errorMessage.contains('INSUFFICIENT_SECURED_BALANCE')) {
                                      userFriendlyMessage = 'You don\'t have enough secured balance to upgrade. Your maximum securable balance is too low for this upgrade.';
                                      Logger.data('[UPGRADE_MEMBERSHIP] Detected INSUFFICIENT_SECURED_BALANCE error');
                                    }
                                    
                                    // Use post-frame callback to ensure widget tree is stable
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (context.mounted) {
                                        try {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                userFriendlyMessage,
                                                style: const TextStyle(color: AppColors.lightCream),
                                              ),
                                              backgroundColor: AppColors.error,
                                            ),
                                          );
                                        } catch (snackBarError) {
                                          Logger.error('Error showing error snackbar', snackBarError);
                                        }
                                      }
                                    });
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.upgrade,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Upgrade',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (_user?.dashboard?.memberTier.type == MemberTierType.open) ...[
                        const Text(
                          'Hustler Benefits',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildBenefitItem(Icons.all_inclusive, 'Issue secured and unsecured credex without limits'),
                        const SizedBox(height: 12),
                        _buildBenefitItem(Icons.manage_accounts, 'Manage accounts'),
                        const SizedBox(height: 12),
                        _buildBenefitItem(Icons.attach_money, '\$1.00 monthly membership fee'),
                      ] else if (_user?.dashboard?.memberTier.type == MemberTierType.hustler) ...[
                        const Text(
                          'Active Hustler Benefits',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildBenefitItem(Icons.check_circle, 'Issue secured and unsecured credex without limits', isActive: true),
                        const SizedBox(height: 12),
                        _buildBenefitItem(Icons.check_circle, 'Manage accounts', isActive: true),
                        const SizedBox(height: 12),
                        _buildBenefitItem(Icons.check_circle, '\$1.00 monthly membership fee', isActive: true),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Marketplace Settings Section (only if feature flag is enabled)
            if (ServiceLocator.featureFlagService.isMarketplaceEnabled()) ...[
              _buildMarketplaceSection(),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
  
  // Check if the user is allowed to become a vendor
  bool _canBecomeVendor(User? user) {
    // If there's no user, don't allow becoming a vendor
    if (user == null) return false;
    
    // Check the activateMarket property directly on the User object
    // This property is set from either the User.activateMarket field or
    // from the Dashboard.activateMarket field for backward compatibility
    // activateMarket == false means we should prompt the user to become a vendor
    // activateMarket == true means the user is already a vendor
    return !user.activateMarket;
  }
  
  // Get user from database if not available from provider
  Future<User?> _getUserFromDatabase() async {
    try {
      Logger.state('Getting user from database');
      return await ServiceLocator.databaseHelper.getUser();
    } catch (e) {
      Logger.error('Error getting user from database', e);
      return null;
    }
  }

  Widget _buildMarketplaceSection() {
    // If user is already a vendor, show vendor profile management
    if (_isVendor) {
      return _buildMarketplaceSectionContent(isVendor: true, canBecomeVendor: false);
    }
    
    // If user is null or we're not sure if they can become a vendor, check from database
    if (_user == null) {
      return FutureBuilder<User?>(
        future: _getUserFromDatabase(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final user = snapshot.data;
          final canBecomeVendor = _canBecomeVendor(user);
          
          return _buildMarketplaceSectionContent(
            isVendor: false,
            canBecomeVendor: canBecomeVendor,
          );
        },
      );
    }
    
    // Use the user from state
    final canBecomeVendor = _canBecomeVendor(_user);
    return _buildMarketplaceSectionContent(
      isVendor: false,
      canBecomeVendor: canBecomeVendor,
    );
  }
  
  Widget _buildMarketplaceSectionContent({
    required bool isVendor,
    required bool canBecomeVendor,
  }) {
    return SettingsContainer(
      title: 'Marketplace Settings',
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sell your products and services in the Vimbiso Marketplace.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              
              if (_isCheckingVendorStatus)
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              else if (isVendor)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.storefront,
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text(
                    'Manage Vendor Profile',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Edit your business information and products',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _navigateToVendorProfile,
                )
              else if (canBecomeVendor)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add_business,
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text(
                    'Become a Vendor',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Create a vendor profile to sell in the marketplace',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _navigateToVendorRegistration,
                )
              else
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.textGray.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: AppColors.textGray,
                    ),
                  ),
                  title: const Text(
                    'Marketplace Access',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textGray,
                    ),
                  ),
                  subtitle: const Text(
                    'You currently don\'t have access to become a vendor',
                    style: TextStyle(
                      color: AppColors.textGray,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitItem(IconData icon, String text, {bool isActive = false}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isActive ? AppColors.success : AppColors.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isActive ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
