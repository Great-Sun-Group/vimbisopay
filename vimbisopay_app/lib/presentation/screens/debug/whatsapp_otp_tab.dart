import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/navigation_utils.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tab for testing WhatsApp OTP functionality
class WhatsAppOTPTab extends StatelessWidget {
  const WhatsAppOTPTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'WhatsApp OTP Testing',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Use these tools to test the WhatsApp OTP verification flow.',
            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          
          // Test WhatsApp OTP Dialog
          Card(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Test WhatsApp OTP Dialog',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This will open the WhatsApp OTP verification dialog with test data.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      Logger.interaction('[DEBUG] Opening WhatsApp OTP test screen');
                      NavigationUtils.safeNavigateTo(context, '/test-whatsapp-otp');
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textPrimary,
                    ),
                    child: const Text('Open Test Screen'),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Direct WhatsApp Deep Link Test
          Card(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Direct WhatsApp Deep Link Test',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This will open WhatsApp directly with a test verification message.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      Logger.interaction('[DEBUG] Testing direct WhatsApp deep link');
                      final uri = Uri.parse('https://wa.me/263785304448?text=VERIFY%20123456');
                      try {
                        final canLaunch = await canLaunchUrl(uri);
                        if (canLaunch) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not launch WhatsApp. Make sure it is installed.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        Logger.error('[DEBUG] Error launching WhatsApp', e);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366), // WhatsApp green
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.send),
                    label: const Text('Open WhatsApp'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
