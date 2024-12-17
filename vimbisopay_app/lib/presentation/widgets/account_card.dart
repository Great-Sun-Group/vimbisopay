import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/presentation/constants/home_constants.dart';

class AccountCard extends StatelessWidget {
  final DashboardAccount account;

  const AccountCard({
    super.key,
    required this.account,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * HomeConstants.accountCardHeight,
      ),
      color: AppColors.surface,
      padding: const EdgeInsets.all(HomeConstants.defaultPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
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
                  const SizedBox(width: HomeConstants.tinyPadding),
                  _buildTierLimitBadge(),
                ],
              ),
              const SizedBox(height: HomeConstants.tinyPadding),
              _buildAccountHandle(),
            ],
          ),
          const SizedBox(height: HomeConstants.defaultPadding),
          _buildBalanceSection(),
          const SizedBox(height: HomeConstants.defaultPadding),
          _buildPayablesSection(),
        ],
      ),
    );
  }

  Widget _buildTierLimitBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HomeConstants.defaultPadding - 4,
        vertical: HomeConstants.smallPadding - 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(HomeConstants.buttonBorderRadius),
      ),
      child: const Column(
        children: [
          Text(
            'Tier Limit',
            style: TextStyle(
              fontSize: HomeConstants.captionTextSize,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: HomeConstants.tinyPadding - 2),
          Text(
            '\$10 USD/day',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountHandle() {
    return Row(
      children: [
        const Text(
          '@',
          style: TextStyle(
            fontSize: HomeConstants.subheadingTextSize,
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: HomeConstants.tinyPadding - 2),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Net Balance',
          style: TextStyle(
            fontSize: HomeConstants.subheadingTextSize,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: HomeConstants.smallPadding),
        Text(
          account.balanceData.netCredexAssetsInDefaultDenom,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildPayablesSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Receivables',
              style: TextStyle(
                fontSize: HomeConstants.bodyTextSize,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: HomeConstants.tinyPadding),
            Text(
              account.balanceData.unsecuredBalances.totalReceivables,
              style: const TextStyle(
                fontSize: HomeConstants.subheadingTextSize,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Payables',
              style: TextStyle(
                fontSize: HomeConstants.bodyTextSize,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: HomeConstants.tinyPadding),
            Text(
              account.balanceData.unsecuredBalances.totalPayables,
              style: const TextStyle(
                fontSize: HomeConstants.subheadingTextSize,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
