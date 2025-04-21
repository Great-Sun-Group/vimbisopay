import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/config/feature_flags.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/helpers/marketplace_debug_helper.dart';
import 'package:vimbisopay_app/presentation/widgets/debug/debug_card.dart';
import 'package:vimbisopay_app/presentation/widgets/debug/debug_section.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Tab for managing feature flags in the debug screen.
class FeatureFlagsTab extends StatefulWidget {
  const FeatureFlagsTab({super.key});

  @override
  State<FeatureFlagsTab> createState() => _FeatureFlagsTabState();
}

class _FeatureFlagsTabState extends State<FeatureFlagsTab> {
  bool _isLoading = false;
  String _statusMessage = '';
  bool _marketplaceEnabled = false;
  bool _debugFeaturesEnabled = false;
  String _marketplaceDefaultValue = 'Unknown';
  String _marketplaceRemoteValue = 'Unknown';
  String _debugFeaturesDefaultValue = 'Unknown';
  String _debugFeaturesRemoteValue = 'Unknown';
  bool _hasMarketplaceOverride = false;
  bool? _marketplaceOverrideValue;
  bool _hasDebugFeaturesOverride = false;
  bool? _debugFeaturesOverrideValue;

  @override
  void initState() {
    super.initState();
    _loadCurrentValues();
  }

  Future<void> _loadCurrentValues() async {
    // Get the remote config instance directly
    final remoteConfig = FirebaseRemoteConfig.instance;
    final featureFlagService = ServiceLocator.featureFlagService;
    
    setState(() {
      // Marketplace feature
      _marketplaceEnabled = featureFlagService.isMarketplaceEnabled();
      _marketplaceDefaultValue = FeatureFlags.defaults[FeatureFlags.enableMarketplace].toString();
      _marketplaceRemoteValue = remoteConfig.getValue(FeatureFlags.enableMarketplace).asBool().toString();
      _hasMarketplaceOverride = featureFlagService.hasMarketplaceOverride();
      _marketplaceOverrideValue = featureFlagService.getMarketplaceOverrideValue();
      
      // Debug features
      _debugFeaturesEnabled = featureFlagService.isDebugFeaturesEnabled();
      _debugFeaturesDefaultValue = FeatureFlags.defaults[FeatureFlags.enableDebugFeatures].toString();
      _debugFeaturesRemoteValue = remoteConfig.getValue(FeatureFlags.enableDebugFeatures).asBool().toString();
      _hasDebugFeaturesOverride = featureFlagService.hasDebugFeaturesOverride();
      _debugFeaturesOverrideValue = featureFlagService.getDebugFeaturesOverrideValue();
    });
  }

  Future<void> _forceRefresh() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Refreshing Remote Config...';
    });

    try {
      final refreshed = await ServiceLocator.featureFlagService.forceRefresh();
      // Get the remote config instance directly
      final remoteConfig = FirebaseRemoteConfig.instance;
      final featureFlagService = ServiceLocator.featureFlagService;
      
      setState(() {
        _isLoading = false;
        _statusMessage = refreshed 
            ? 'Remote Config refreshed successfully!' 
            : 'Failed to refresh Remote Config.';
        
        // Reload all values
        _loadCurrentValues();
      });
      
      Logger.data('Force refresh result: $refreshed');
      Logger.data('Marketplace feature enabled after refresh: $_marketplaceEnabled');
      Logger.data('Debug features enabled after refresh: $_debugFeaturesEnabled');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error refreshing Remote Config: $e';
      });
      Logger.error('Error refreshing Remote Config', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DebugCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Marketplace Feature',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Switch(
                        value: _marketplaceEnabled,
                        onChanged: _isLoading ? null : (value) async {
                          setState(() {
                            _isLoading = true;
                            _statusMessage = 'Setting local override...';
                          });
                          
                          try {
                            final result = await ServiceLocator.featureFlagService.setMarketplaceOverride(value);
                            
                            setState(() {
                              _isLoading = false;
                              _statusMessage = result
                                  ? 'Local override set successfully!'
                                  : 'Failed to set local override.';
                              _marketplaceEnabled = value;
                              _hasMarketplaceOverride = true;
                              _marketplaceOverrideValue = value;
                            });
                          } catch (e) {
                            setState(() {
                              _isLoading = false;
                              _statusMessage = 'Error setting local override: $e';
                            });
                          }
                        },
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        _marketplaceEnabled ? 'Enabled' : 'Disabled',
                        style: TextStyle(
                          fontSize: 14,
                          color: _marketplaceEnabled
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                      if (_hasMarketplaceOverride) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.yellowPrimary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.yellowPrimary,
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'Local Override',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.yellowPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_hasMarketplaceOverride) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Clear Override'),
                      onPressed: _isLoading ? null : () async {
                        setState(() {
                          _isLoading = true;
                          _statusMessage = 'Clearing local override...';
                        });
                        
                        try {
                          final result = await ServiceLocator.featureFlagService.clearMarketplaceOverride();
                          
                          // Get the remote config value
                          final remoteConfig = FirebaseRemoteConfig.instance;
                          final remoteValue = remoteConfig.getBool(FeatureFlags.enableMarketplace);
                          
                          setState(() {
                            _isLoading = false;
                            _statusMessage = result
                                ? 'Local override cleared successfully!'
                                : 'Failed to clear local override.';
                            _marketplaceEnabled = remoteValue;
                            _hasMarketplaceOverride = false;
                            _marketplaceOverrideValue = null;
                          });
                        } catch (e) {
                          setState(() {
                            _isLoading = false;
                            _statusMessage = 'Error clearing local override: $e';
                          });
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.yellowPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Debug Features Card
            DebugCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Debug Features',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Switch(
                        value: _debugFeaturesEnabled,
                        onChanged: _isLoading ? null : (value) async {
                          setState(() {
                            _isLoading = true;
                            _statusMessage = 'Setting local override...';
                          });
                          
                          try {
                            final result = await ServiceLocator.featureFlagService.setDebugFeaturesOverride(value);
                            
                            setState(() {
                              _isLoading = false;
                              _statusMessage = result
                                  ? 'Local override set successfully!'
                                  : 'Failed to set local override.';
                              _debugFeaturesEnabled = value;
                              _hasDebugFeaturesOverride = true;
                              _debugFeaturesOverrideValue = value;
                            });
                          } catch (e) {
                            setState(() {
                              _isLoading = false;
                              _statusMessage = 'Error setting local override: $e';
                            });
                          }
                        },
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        _debugFeaturesEnabled ? 'Enabled' : 'Disabled',
                        style: TextStyle(
                          fontSize: 14,
                          color: _debugFeaturesEnabled
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                      if (_hasDebugFeaturesOverride) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.yellowPrimary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.yellowPrimary,
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'Local Override',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.yellowPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_hasDebugFeaturesOverride) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Clear Override'),
                      onPressed: _isLoading ? null : () async {
                        setState(() {
                          _isLoading = true;
                          _statusMessage = 'Clearing local override...';
                        });
                        
                        try {
                          final result = await ServiceLocator.featureFlagService.clearDebugFeaturesOverride();
                          
                          // Get the remote config value
                          final remoteConfig = FirebaseRemoteConfig.instance;
                          final remoteValue = remoteConfig.getBool(FeatureFlags.enableDebugFeatures);
                          
                          setState(() {
                            _isLoading = false;
                            _statusMessage = result
                                ? 'Local override cleared successfully!'
                                : 'Failed to clear local override.';
                            _debugFeaturesEnabled = remoteValue;
                            _hasDebugFeaturesOverride = false;
                            _debugFeaturesOverrideValue = null;
                          });
                        } catch (e) {
                          setState(() {
                            _isLoading = false;
                            _statusMessage = 'Error clearing local override: $e';
                          });
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.yellowPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _forceRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Force Refresh Remote Config'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/database-test');
              },
              icon: const Icon(Icons.storage),
              label: const Text('Database Test'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                MarketplaceDebugHelper.showAccountInfo(context);
              },
              icon: const Icon(Icons.account_circle),
              label: const Text('Show Account Information'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            if (_statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 16,
                    color: _statusMessage.contains('successfully')
                        ? AppColors.success
                        : _statusMessage.contains('Failed') || _statusMessage.contains('Error')
                            ? AppColors.error
                            : AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 24),
            DebugSection(
              title: 'Debug Information',
              children: [
                DebugCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Remote Config Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DebugInfoRow(
                        label: 'Marketplace Feature',
                        value: _marketplaceEnabled ? 'Enabled' : 'Disabled',
                      ),
                      DebugInfoRow(
                        label: 'Default Value',
                        value: _marketplaceDefaultValue,
                      ),
                      DebugInfoRow(
                        label: 'Remote Value',
                        value: _marketplaceRemoteValue,
                      ),
                      if (_hasMarketplaceOverride)
                        DebugInfoRow(
                          label: 'Local Override',
                          value: _marketplaceOverrideValue! ? 'Enabled' : 'Disabled',
                          valueStyle: const TextStyle(
                            fontSize: 14,
                            color: AppColors.yellowPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'Debug Features',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DebugInfoRow(
                        label: 'Debug Features',
                        value: _debugFeaturesEnabled ? 'Enabled' : 'Disabled',
                      ),
                      DebugInfoRow(
                        label: 'Default Value',
                        value: _debugFeaturesDefaultValue,
                      ),
                      DebugInfoRow(
                        label: 'Remote Value',
                        value: _debugFeaturesRemoteValue,
                      ),
                      if (_hasDebugFeaturesOverride)
                        DebugInfoRow(
                          label: 'Local Override',
                          value: _debugFeaturesOverrideValue! ? 'Enabled' : 'Disabled',
                          valueStyle: const TextStyle(
                            fontSize: 14,
                            color: AppColors.yellowPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(height: 4),
                      const Text(
                        'Note: If the feature flags are not updating, check the Firebase Console to ensure the parameters are set correctly.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Firebase Services',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            'Firebase Analytics: ',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Initialized',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Firebase Analytics is required for Remote Config A/B testing functionality.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
