import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/denomination.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;
import 'package:vimbisopay_app/presentation/blocs/send_credex/send_credex_state.dart';

/// Widget to display verified recipient information
class VerifiedRecipientCard extends StatelessWidget {
  final Map<String, dynamic> accountDetails;
  final VoidCallback onChangeRecipient;
  final CredexType? credexType;
  final String? profileImageUrl;
  final String? memberName;
  final bool isVerifying;
  final bool fullWidth;
  
  const VerifiedRecipientCard({
    super.key,
    required this.accountDetails,
    required this.onChangeRecipient,
    this.credexType,
    this.profileImageUrl,
    this.memberName,
    this.isVerifying = false,
    this.fullWidth = true,
  });
  
  // Helper property for backward compatibility
  bool get isSecuredCredex => credexType == CredexType.SECURED;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(
          color: AppColors.primary,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'To Account:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                // Only show Change icon if not verifying
                if (!isVerifying)
                  GestureDetector(
                    onTap: onChangeRecipient,
                    child: const Icon(
                      Icons.autorenew,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Full width account info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget to display sender account information
class SenderAccountCard extends StatelessWidget {
  final dashboard.DashboardAccount account;
  final Denomination selectedDenomination;
  final double availableBalance;
  final CredexType? credexType;
  final String? profileImageUrl;
  final String? memberName;
  final bool fullWidth;
  
  const SenderAccountCard({
    super.key,
    required this.account,
    required this.selectedDenomination,
    required this.availableBalance,
    this.credexType,
    this.profileImageUrl,
    this.memberName,
    this.fullWidth = false,
  });
  
  // Helper property for backward compatibility
  bool get isSecuredCredex => credexType == CredexType.SECURED;
  
  @override
  Widget build(BuildContext context) {
    final denom = selectedDenomination.toString().split('.').last;
    
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(
          color: AppColors.primary,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'From Account:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            // Full width account info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💳 ${account.accountName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '💳 ${account.accountHandle}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
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
