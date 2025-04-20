import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/presentation/constants/home_constants.dart';

class AccountCard extends StatelessWidget {
  final DashboardAccount account;
  final MemberTier memberTier;
  final VoidCallback? onUpgrade;

  const AccountCard({
    super.key,
    required this.account,
    required this.memberTier,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.all(HomeConstants.defaultPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Changed to min to reduce space
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Account name and net balance row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Account name
              Expanded(
                flex: 3,
                child: Text(
                  account.accountName,
                  style: const TextStyle(
                    fontSize: HomeConstants.headingTextSize,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              // Net Balance
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Net Balance',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          account.balanceData.netCredexAssetsInDefaultDenom.split(' ')[0],
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          account.balanceData.netCredexAssetsInDefaultDenom.split(' ').length > 1 
                              ? account.balanceData.netCredexAssetsInDefaultDenom.split(' ')[1] 
                              : 'USD',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Account handle
          _buildAccountHandle(),
          
          // More space between handle and payables
          const SizedBox(height: 20),
          
          // Balances section
          _buildPayablesSection(),
        ],
      ),
    );
  }

  Widget _buildTierLimitBadge() {
    // Return empty widget to remove daily limit and upgrade buttons
    return const SizedBox.shrink();
  }

  Widget _buildAccountHandle() {
    return Row(
      children: [
        const Text(
          '💳 ',
          style: TextStyle(
            fontSize: HomeConstants.subheadingTextSize,
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Flexible(
          child: Text(
            account.accountHandle,
            style: const TextStyle(
              fontSize: HomeConstants.subheadingTextSize,
              color: AppColors.textSecondary,
            ),
            softWrap: true,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 4), // Removed bottom padding
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start, // Changed from spaceBetween to start
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Net Balance',
            style: TextStyle(
              fontSize: HomeConstants.subheadingTextSize,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2), // Controlled spacing
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              account.balanceData.netCredexAssetsInDefaultDenom,
              style: const TextStyle(
                fontSize: 20, // Further reduced from 22px to fix overflow
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayablesSection() {
    // Gold border color
    final borderColor = AppColors.yellowMain;
    final borderWidth = 1.5;
    
    // IMPORTANT: Removed ALL top padding here
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Secured section with gold border and title overlay
        Expanded(
          flex: 1, // Maintain 1:2 ratio
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Main card
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: borderColor,
                      width: borderWidth,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center, // Changed to center
                    children: [
                      const SizedBox(height: 2),
                      // Secured value
                      const Center( // Added Center widget
                        child: Text(
                          'Available',
                          style: TextStyle(
                            fontSize: HomeConstants.bodyTextSize,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Center( // Added Center widget
                        child: Text(
                          account.balanceData.netCredexAssetsInDefaultDenom,
                          style: const TextStyle(
                            fontSize: HomeConstants.subheadingTextSize,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Title overlay
                Positioned(
                  top: -10,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    color: AppColors.surface,
                    child: Text(
                      'Secured',
                      style: TextStyle(
                        color: borderColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Unsecured section containing both Receivable and Payable
        Expanded(
          flex: 2, // Maintain 1:2 ratio
          child: Container(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Main card
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: borderColor,
                      width: borderWidth,
                    ),
                  ),
                  // IMPORTANT: Kept Table but added vertical divider and reduced cell padding
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1),
                      1: FlexColumnWidth(1),
                    },
                    // Add a border that only shows vertically between columns
                    border: TableBorder(
                      verticalInside: BorderSide(
                        width: 1,
                        color: Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    children: [
                      TableRow(
                        children: [
                          // Receivable label - center aligned
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Center(
                              child: Text(
                                'Receivable',
                                style: TextStyle(
                                  fontSize: HomeConstants.bodyTextSize,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          // Payable label - center aligned
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Center(
                              child: Text(
                                'Payable',
                                style: TextStyle(
                                  fontSize: HomeConstants.bodyTextSize,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          // Receivable value - center aligned
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Center(
                              child: Text(
                                '0.00 USD', // Placeholder value
                                style: const TextStyle(
                                  fontSize: HomeConstants.subheadingTextSize,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.techAzure,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          // Payable value - center aligned
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Center(
                              child: Text(
                                '0.00 USD', // Placeholder value
                                style: const TextStyle(
                                  fontSize: HomeConstants.subheadingTextSize,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.techAzure,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Title overlay
                Positioned(
                  top: -10,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    color: AppColors.surface,
                    child: Text(
                      'Unsecured',
                      style: TextStyle(
                        color: borderColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
