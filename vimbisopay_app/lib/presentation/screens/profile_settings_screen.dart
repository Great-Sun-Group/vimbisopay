import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/theme/app_spacing.dart';
import 'package:vimbisopay_app/core/theme/app_text_styles.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/presentation/widgets/initials_avatar.dart';
import 'package:vimbisopay_app/presentation/widgets/settings_container.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  bool _isLoading = true;
  String? _error;
  User? _user;
  
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

          ],
        ),
      ),
    );
  }

}
