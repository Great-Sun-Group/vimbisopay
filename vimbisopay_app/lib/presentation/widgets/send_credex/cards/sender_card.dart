import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;
import 'package:vimbisopay_app/domain/entities/denomination.dart';
import 'package:vimbisopay_app/presentation/blocs/send_credex/send_credex_state.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/common/section_header.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/common/styled_card.dart';

/// Widget to display sender account information
class SenderAccountCard extends StatelessWidget {
  final dashboard.DashboardAccount account;
  final Denomination selectedDenomination;
  final double availableBalance;
  final CredexType? credexType;
  final String? profileImageUrl;
  final String? memberName;
  
  const SenderAccountCard({
    super.key,
    required this.account,
    required this.selectedDenomination,
    required this.availableBalance,
    this.credexType,
    this.profileImageUrl,
    this.memberName,
  });
  
  @override
  Widget build(BuildContext context) {
    return StyledCard.gold(
      title: '1. From Account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
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
        ],
      ),
    );
  }
}
