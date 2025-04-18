import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/presentation/blocs/send_credex/send_credex_state.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/common/styled_card.dart';

/// Widget to display verified recipient information
class VerifiedRecipientCard extends StatelessWidget {
  final Map<String, dynamic> accountDetails;
  final VoidCallback onChangeRecipient;
  final CredexType? credexType;
  final String? profileImageUrl;
  final String? memberName;
  final bool isVerifying;
  
  const VerifiedRecipientCard({
    super.key,
    required this.accountDetails,
    required this.onChangeRecipient,
    this.credexType,
    this.profileImageUrl,
    this.memberName,
    this.isVerifying = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return StyledCard.gold(
      title: '2. To Account',
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Account name and handle
              Text(
                '💳 ${accountDetails['accountName']}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '💳 ${accountDetails['accountHandle']}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              
              // Add some space at the bottom to maintain height
              const SizedBox(height: 12),
            ],
          ),
          
          // Only show Change button if not verifying
          if (!isVerifying)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                onPressed: onChangeRecipient,
                icon: const Icon(
                  Icons.autorenew,
                  color: AppColors.primary,
                ),
                tooltip: 'Change recipient',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 20,
              ),
            ),
        ],
      ),
    );
  }
}

/// Widget for recipient input and verification
class RecipientInputCard extends StatelessWidget {
  final TextEditingController recipientController;
  final FocusNode? focusNode;
  final bool isVerifying;
  final VoidCallback onVerify;
  final VoidCallback onScanQR;
  final String? Function(String?)? validator;
  
  const RecipientInputCard({
    super.key,
    required this.recipientController,
    this.focusNode,
    required this.isVerifying,
    required this.onVerify,
    required this.onScanQR,
    this.validator,
  });
  
  @override
  Widget build(BuildContext context) {
    return StyledCard.gold(
      title: '2. To Account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle input field - full width
          TextFormField(
            controller: recipientController,
            focusNode: focusNode,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: '💳 Handle',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              hintText: 'Send to what account?',
              hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.textSecondary, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.textSecondary, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.techAzure, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              suffixIcon: isVerifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    )
                  : null,
            ),
            validator: validator,
          ),
          
          const SizedBox(height: 12),
          
          // When verifying, don't show any buttons or helper text
          if (isVerifying) ...[
            // Empty space to maintain layout
            const SizedBox(height: 24),
          ] else ...[
            // Helper text - only visible when not verifying
            const Text(
              'Verify account handle or scan QR code',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Action buttons row
            Row(
              children: [
                // Verify button
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: recipientController,
                    builder: (context, value, child) {
                      return ElevatedButton(
                        onPressed: value.text.length >= 6 ? onVerify : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.techAzure,
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text('Verify Handle'),
                      );
                    },
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // QR Scan button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onScanQR,
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('Scan QR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.techAzure,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
