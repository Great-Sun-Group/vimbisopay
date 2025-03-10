import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/services/feature_flag_service.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/vendor_profile_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/vendor_registration_screen.dart';
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

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  User? _user;
  late final AnimationController _spinController;
  
  bool _isVendor = false;
  bool _isCheckingVendorStatus = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
    _loadUserData();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
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

      Logger.state('Attempting to read User from Provider');
      final user = context.read<User>();
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
    if (_user == null) return;
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      final marketplaceRepository = ServiceLocator.marketplaceRepository;
      final result = await marketplaceRepository.getVendorByMemberId(_user!.memberId);
      
      setState(() {
        _isLoading = false;
      });
      
      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message ?? 'Failed to load vendor profile'),
              backgroundColor: Colors.red,
            ),
          );
        },
        (vendor) {
          Navigator.pushNamed(
            context,
            '/vendor-profile',
            arguments: {
              'vendorId': vendor.id,
              'isOwner': true,
            },
          );
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                      Center(
                        child: MemberTierBadge(
                          tierType: _user?.dashboard?.memberTier.type ?? MemberTierType.open,
                          onUpgrade: _user?.dashboard?.memberTier.type == MemberTierType.open
                              ? () async {
                                  try {
                                    final sourceAccountId = _user?.dashboard?.member.memberID;
                                    if (sourceAccountId != null) {
                                      // Show loading dialog
                                      if (!context.mounted) return;
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) => LoadingDialog(
                                          spinController: _spinController,
                                          message: 'Upgrading membership...',
                                        ),
                                      );

                                      await context.read<UpgradeMemberTier>()(sourceAccountId);
                                      
                                      // Dismiss loading dialog
                                      if (!context.mounted) return;
                                      Navigator.pop(context);

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Membership upgrade initiated successfully'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                      _loadUserData(); // Refresh to show updated status
                                    }
                                  } catch (e) {
                                    // Dismiss loading dialog
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to upgrade membership: ${e.toString()}'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                }
                              : null,
                        ),
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
  
  Widget _buildMarketplaceSection() {
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
              else if (_isVendor)
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
              else
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
