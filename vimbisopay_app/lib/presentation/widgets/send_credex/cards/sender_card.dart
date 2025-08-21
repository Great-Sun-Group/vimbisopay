import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;
import 'package:vimbisopay_app/domain/entities/denomination.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/presentation/blocs/send_credex/send_credex_state.dart';
import 'package:vimbisopay_app/presentation/widgets/common/credit_rating_display.dart';

/// Widget to display sender account information
class SenderAccountCard extends StatelessWidget {
  final dashboard.DashboardAccount account;
  final Denomination selectedDenomination;
  final double availableBalance;
  final CredexType? credexType;
  final String? profileImageUrl;
  final String? memberName;
  final bool showSecuredBalance;
  final dashboard.CreditRating? creditRating;
  final String? memberId;
  final AccountRepository? accountRepository;
  
  const SenderAccountCard({
    super.key,
    required this.account,
    required this.selectedDenomination,
    required this.availableBalance,
    this.credexType,
    this.profileImageUrl,
    this.memberName,
    this.showSecuredBalance = false,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Add some top padding to account for the title overlap
                const SizedBox(height: 4),
                // Account name and handle
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
                
                // Show secured balance if requested
                if (showSecuredBalance && credexType == CredexType.SECURED) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Secured Balance: ${availableBalance.toStringAsFixed(2)} ${selectedDenomination.toString().split('.').last}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
                
                // Show credit rating bar for Unsecured credex
                if (credexType == CredexType.UNSECURED) ...[
                  const SizedBox(height: 12),
                  
                  // Use the reusable credit rating display widget
                  Builder(
                    builder: (context) {
                      final isClickable = memberId != null && accountRepository != null && memberName != null;
                      return CreditRatingDisplay.compact(
                        creditRating: creditRating,
                        memberName: memberName,
                        isClickable: isClickable,
                        onTap: isClickable 
                            ? () => _navigateToCreditReport(context)
                            : null,
                      );
                    },
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
                'From Account',
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
