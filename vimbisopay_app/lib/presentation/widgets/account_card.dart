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
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                  _buildAccountHandle(),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: _buildBalanceSection(),
            ),
            _buildPayablesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTierLimitBadge() {
    // Don't show tier limit for special tier
    if (memberTier.type == MemberTierType.special) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HomeConstants.defaultPadding - 4,
            vertical: HomeConstants.smallPadding - 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(HomeConstants.buttonBorderRadius),
          ),
          child: Column(
            children: [
              const Text(
                'Daily Limit',
                style: TextStyle(
                  fontSize: HomeConstants.captionTextSize,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: HomeConstants.tinyPadding - 2),
              Text(
                '\$${memberTier.dailySecuredCredexLimit.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (memberTier.type == MemberTierType.open && onUpgrade != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onUpgrade,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(HomeConstants.cardBorderRadius),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.upgrade,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Upgrade',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Net Balance',
            style: TextStyle(
              fontSize: HomeConstants.subheadingTextSize,
              color: AppColors.textSecondary,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              account.balanceData.netCredexAssetsInDefaultDenom,
              style: const TextStyle(
                fontSize: 26,
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
    return SizedBox(
      height: 50,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Receivables',
                      style: TextStyle(
                        fontSize: HomeConstants.bodyTextSize,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      account.balanceData.unsecuredBalances.totalReceivables,
                      style: const TextStyle(
                        fontSize: HomeConstants.subheadingTextSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.techAzure,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Payables',
                      style: TextStyle(
                        fontSize: HomeConstants.bodyTextSize,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      account.balanceData.unsecuredBalances.totalPayables,
                      style: const TextStyle(
                        fontSize: HomeConstants.subheadingTextSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.errorRed,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
