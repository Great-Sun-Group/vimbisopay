import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;
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
  final dashboard.CreditRating? creditRating;
  
  const VerifiedRecipientCard({
    super.key,
    required this.accountDetails,
    required this.onChangeRecipient,
    this.credexType,
    this.profileImageUrl,
    this.memberName,
    this.isVerifying = false,
    this.creditRating,
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
                      
                      // Credit rating bar based on creditRating data
                      if (creditRating == null || 
                          (creditRating!.redeemedTotalUSD == 0 && 
                           creditRating!.outstandingTotalUSD == 0 && 
                           creditRating!.defaultedTotalUSD == 0 && 
                           creditRating!.writtenOffTotalUSD == 0)) 
                        // Show "not yet established" for no credit history
                        Container(
                          height: 18,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.techAzure,
                              width: 1.0,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              "Owner credit rating not yet established",
                              style: TextStyle(
                                color: AppColors.techAzure,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        _buildCreditRatingBar(creditRating!),
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
  
  Widget _buildCreditRatingBar(dashboard.CreditRating rating) {
    // Calculate percentages for the credit rating bar
    double total = rating.redeemedTotalUSD + 
                 rating.outstandingTotalUSD + 
                 rating.defaultedTotalUSD + 
                 rating.writtenOffTotalUSD;
    
    // Calculate percentages of each component
    int redeemedPercent = total > 0 ? ((rating.redeemedTotalUSD / total) * 100).round() : 0;
    int outstandingPercent = total > 0 ? ((rating.outstandingTotalUSD / total) * 100).round() : 0;
    int defaultedPercent = total > 0 ? ((rating.defaultedTotalUSD / total) * 100).round() : 0;
    int writtenOffPercent = total > 0 ? ((rating.writtenOffTotalUSD / total) * 100).round() : 0;
    
    // Ensure minimum visibility for non-zero values
    if (rating.redeemedTotalUSD > 0 && redeemedPercent == 0) redeemedPercent = 1;
    if (rating.outstandingTotalUSD > 0 && outstandingPercent == 0) outstandingPercent = 1;
    if (rating.defaultedTotalUSD > 0 && defaultedPercent == 0) defaultedPercent = 1;
    if (rating.writtenOffTotalUSD > 0 && writtenOffPercent == 0) writtenOffPercent = 1;
    
    // Adjust percentages to ensure they sum to 100%
    int sum = redeemedPercent + outstandingPercent + defaultedPercent + writtenOffPercent;
    if (sum != 100) {
      // Find the largest component to adjust
      int largest = redeemedPercent;
      String largestType = "redeemed";
      
      if (outstandingPercent > largest) {
        largest = outstandingPercent;
        largestType = "outstanding";
      }
      if (defaultedPercent > largest) {
        largest = defaultedPercent;
        largestType = "defaulted";
      }
      if (writtenOffPercent > largest) {
        largest = writtenOffPercent;
        largestType = "writtenOff";
      }
      
      // Adjust the largest component
      if (largestType == "redeemed") {
        redeemedPercent += (100 - sum);
      } else if (largestType == "outstanding") {
        outstandingPercent += (100 - sum);
      } else if (largestType == "defaulted") {
        defaultedPercent += (100 - sum);
      } else {
        writtenOffPercent += (100 - sum);
      }
    }
    
    // Return credit rating bar with calculated percentages
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        // Bar graph with calculated proportions
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 18,
            width: double.infinity,
            child: Row(
              children: [
                // Redeemed (green)
                if (redeemedPercent > 0)
                  Expanded(
                    flex: redeemedPercent,
                    child: Container(
                      color: AppColors.green,
                    ),
                  ),
                // Outstanding (blue)
                if (outstandingPercent > 0)
                  Expanded(
                    flex: outstandingPercent,
                    child: Container(
                      color: AppColors.techAzure,
                    ),
                  ),
                // Defaulted (amber)
                if (defaultedPercent > 0)
                  Expanded(
                    flex: defaultedPercent,
                    child: Container(
                      color: AppColors.yellowPrimary,
                    ),
                  ),
                // Written off (red)
                if (writtenOffPercent > 0)
                  Expanded(
                    flex: writtenOffPercent,
                    child: Container(
                      color: AppColors.darkRed,
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Owner credit rating text inside the bar
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            "Owner credit rating",
            style: const TextStyle(
              color: Colors.black,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
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
                      borderSide: BorderSide(
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
