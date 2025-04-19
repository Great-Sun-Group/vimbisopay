import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vimbisopay_app/core/config/api_config.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/widgets/debug/debug_card.dart';
import 'package:vimbisopay_app/presentation/widgets/debug/debug_section.dart';

/// Tab for managing API configuration in the debug screen.
class ApiConfigTab extends StatefulWidget {
  const ApiConfigTab({super.key});

  @override
  State<ApiConfigTab> createState() => _ApiConfigTabState();
}

class _ApiConfigTabState extends State<ApiConfigTab> {
  bool _isLoading = false;
  String _statusMessage = '';
  ApiEnvironment _currentEnvironment = ApiEnvironment.development;
  String _baseUrl = '';
  String _apiKey = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentValues();
  }

  Future<void> _loadCurrentValues() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize API config if not already initialized
      await ApiConfig.initialize();
      
      // Refresh environment to ensure we have the latest setting
      await ApiConfig.refreshEnvironment();
      
      setState(() {
        _currentEnvironment = ApiConfig.environment;
        _baseUrl = ApiConfig.baseUrl;
        _apiKey = ApiConfig.apiKey;
        _isLoading = false;
      });
      
      Logger.data('API environment loaded: ${ApiConfig.environmentName}');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error loading API configuration: $e';
      });
      Logger.error('Error loading API configuration', e);
    }
  }

  Future<void> _setEnvironment(ApiEnvironment environment) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Changing API environment...';
    });

    try {
      await ApiConfig.setEnvironment(environment);
      
      setState(() {
        _currentEnvironment = ApiConfig.environment;
        _baseUrl = ApiConfig.baseUrl;
        _apiKey = ApiConfig.apiKey;
        _isLoading = false;
        _statusMessage = 'API environment changed to ${ApiConfig.environmentName}';
      });
      
      Logger.data('API environment changed to: ${ApiConfig.environmentName}');
      
      // Show dialog to prompt user to restart the app
      if (context.mounted) {
        _showRestartDialog();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error changing API environment: $e';
      });
      Logger.error('Error changing API environment', e);
    }
  }
  
  /// Shows a dialog prompting the user to exit the app after changing the API environment.
  void _showRestartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('API Environment Changed'),
          content: Text(
            'The API environment has been changed to ${ApiConfig.environmentName}. '
            'The app will now close. Please restart it manually to use the new environment.'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                _logoutAndExit();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
              ),
              child: const Text('Logout & Exit'),
            ),
          ],
        );
      },
    );
  }
  
  /// Logs out the user and exits the app.
  Future<void> _logoutAndExit() async {
    try {
      // Clear all user data including security settings and database
      final securityService = ServiceLocator.securityService;
      await securityService.clearAllData();
      
      // Show a snackbar to inform the user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully. Closing app...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Give time for the snackbar to be visible
      await Future.delayed(const Duration(seconds: 2));
      
      // Exit the app
      SystemNavigator.pop();
    } catch (e) {
      Logger.error('Error logging out user', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
                  const Text(
                    'API Environment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildEnvironmentButton(
                          environment: ApiEnvironment.development,
                          label: 'Development',
                          icon: Icons.code,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildEnvironmentButton(
                          environment: ApiEnvironment.production,
                          label: 'Production',
                          icon: Icons.public,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Current Environment: ${ApiConfig.environmentName}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _currentEnvironment == ApiEnvironment.production
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
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
                    color: _statusMessage.contains('changed to')
                        ? AppColors.success
                        : _statusMessage.contains('Error')
                            ? AppColors.error
                            : AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 24),
            DebugSection(
              title: 'API Configuration',
              children: [
                DebugCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DebugInfoRow(
                        label: 'Base URL',
                        value: _baseUrl,
                      ),
                      DebugInfoRow(
                        label: 'API Key',
                        value: _maskApiKey(_apiKey),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Note: API configuration is stored in SharedPreferences and will persist across app restarts.',
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

  Widget _buildEnvironmentButton({
    required ApiEnvironment environment,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _currentEnvironment == environment;
    
    return FilledButton.icon(
      onPressed: _isLoading || isSelected ? null : () => _setEnvironment(environment),
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: isSelected ? AppColors.primary : AppColors.surface,
        foregroundColor: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
        disabledBackgroundColor: isSelected ? AppColors.primary.withOpacity(0.7) : null,
        disabledForegroundColor: isSelected ? AppColors.textPrimary.withOpacity(0.7) : null,
        padding: const EdgeInsets.symmetric(
          vertical: 16,
        ),
      ),
    );
  }

  String _maskApiKey(String apiKey) {
    if (apiKey.length <= 8) {
      return '********';
    }
    
    // Show first 4 and last 4 characters, mask the rest
    final firstFour = apiKey.substring(0, 4);
    final lastFour = apiKey.substring(apiKey.length - 4);
    final maskedLength = apiKey.length - 8;
    final masked = '*' * maskedLength;
    
    return '$firstFour$masked$lastFour';
  }
}
