import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/presentation/blocs/send_credex/send_credex_state.dart';
import 'package:vimbisopay_app/presentation/widgets/common/credit_rating_display.dart';

/// Widget to display verified recipient information
class VerifiedRecipientCard extends StatelessWidget {
  final Map<String, dynamic> accountDetails;
  final VoidCallback onChangeRecipient;
  final CredexType? credexType;
  final String? profileImageUrl;
  final String? memberName;
  final bool isVerifying;
  final dashboard.CreditRating? creditRating;
  final String? memberId;
  final AccountRepository? accountRepository;
  
  const VerifiedRecipientCard({
    super.key,
    required this.accountDetails,
    required this.onChangeRecipient,
    this.credexType,
    this.profileImageUrl,
    this.memberName,
    this.isVerifying = false,
    this.creditRating,
    this.memberId,
    this.accountRepository,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main card container
          Container(
            margin: const EdgeInsets.only(top: 10), // Add margin to make space for the title
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppColors.darkBluePrimary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: credexType == CredexType.SECURED 
                    ? AppColors.primary // Gold for Secured
                    : AppColors.techAzure, // Teal for Unsecured
                width: 1
              ),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Add some top padding to account for the title overlap
                    const SizedBox(height: 4),
                    
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
                    
                    // Show credit rating bar for Unsecured credex
                    if (credexType == CredexType.UNSECURED) ...[
                      const SizedBox(height: 12),
                      
                      // Use the reusable credit rating display widget
                      CreditRatingDisplay.compact(
                        creditRating: creditRating,
                        memberName: memberName,
                        isClickable: memberId != null && accountRepository != null && memberName != null,
                        onTap: (memberId != null && accountRepository != null && memberName != null) 
                            ? () => _navigateToCreditReport(context)
                            : null,
                      ),
                    ],
                  ],
                ),
                
                // Only show Change button if not verifying
                if (!isVerifying)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      onPressed: onChangeRecipient,
                      icon: Icon(
                        Icons.autorenew,
                        color: credexType == CredexType.SECURED 
                            ? AppColors.primary // Gold for Secured
                            : AppColors.techAzure, // Teal for Unsecured
                      ),
                      tooltip: 'Change recipient',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 20,
                    ),
                  ),
              ],
            ),
          ),
          
          // Title positioned at the top border
          Positioned(
            top: 0,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: AppColors.darkBlueDark1, // Match the background color
              child: Text(
                'To Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: credexType == CredexType.SECURED 
                      ? AppColors.primary // Gold for Secured
                      : AppColors.techAzure, // Teal for Unsecured
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToCreditReport(BuildContext context) {
    if (memberId != null && accountRepository != null && memberName != null) {
      Navigator.of(context).pushNamed(
        '/counterparty-credit-report',
        arguments: {
          'memberId': memberId!,
          'memberName': memberName!,
          'accountRepository': accountRepository!,
        },
      );
    }
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
  final CredexType? credexType;
  
  const RecipientInputCard({
    super.key,
    required this.recipientController,
    this.focusNode,
    required this.isVerifying,
    required this.onVerify,
    required this.onScanQR,
    this.validator,
    this.credexType,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main card container
          Container(
            margin: const EdgeInsets.only(top: 10), // Add margin to make space for the title
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppColors.darkBluePrimary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: credexType == CredexType.SECURED 
                    ? AppColors.primary // Gold for Secured
                    : AppColors.techAzure, // Teal for Unsecured
                width: 1
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Add some top padding to account for the title overlap
                const SizedBox(height: 4),
                
                // Handle input field - full width
                TextFormField(
                  controller: recipientController,
                  focusNode: focusNode,
                  style: const TextStyle(color: AppColors.textPrimary),
                  cursorColor: credexType == CredexType.SECURED 
                      ? AppColors.primary // Gold for Secured
                      : AppColors.techAzure, // Teal for Unsecured
                  cursorWidth: 2.0, // Make cursor wider and more visible
                  cursorRadius: const Radius.circular(1.0),
                  showCursor: true, // Explicitly show cursor
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
                      borderSide: const BorderSide(
                        color: AppColors.textSecondary, 
                        width: 1
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: credexType == CredexType.SECURED 
                            ? AppColors.primary // Gold for Secured
                            : AppColors.techAzure, // Teal for Unsecured
                        width: 1.5
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    suffixIcon: isVerifying
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  credexType == CredexType.SECURED 
                                      ? AppColors.primary // Gold for Secured
                                      : AppColors.techAzure, // Teal for Unsecured
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                  validator: validator,
                  // Ensure text field is enabled and can receive input
                  enabled: !isVerifying,
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
                                backgroundColor: credexType == CredexType.SECURED 
                                    ? AppColors.primary // Gold for Secured
                                    : AppColors.techAzure, // Teal for Unsecured
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
                            backgroundColor: credexType == CredexType.SECURED 
                                ? AppColors.primary // Gold for Secured
                                : AppColors.techAzure, // Teal for Unsecured
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
          ),
          
          // Title positioned at the top border
          Positioned(
            top: 0,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: AppColors.darkBlueDark1, // Match the background color
              child: Text(
                'To Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: credexType == CredexType.SECURED 
                      ? AppColors.primary // Gold for Secured
                      : AppColors.techAzure, // Teal for Unsecured
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
