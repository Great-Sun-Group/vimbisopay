import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/presentation/constants/home_constants.dart';
import 'package:vimbisopay_app/presentation/widgets/account_qr_dialog.dart';
import 'package:vimbisopay_app/presentation/widgets/account_selection_bottom_sheet.dart';
import 'package:vimbisopay_app/presentation/screens/send_credex_screen.dart';

class HomeActionButtons extends StatelessWidget {
  final List<DashboardAccount>? accounts;
  final VoidCallback? onSendTap;
  final AccountRepository accountRepository;

  const HomeActionButtons({
    super.key,
    this.accounts,
    this.onSendTap,
    required this.accountRepository,
  });

  void _handleSendTap(BuildContext context) {
    if (accounts == null || accounts!.isEmpty) return;

    if (accounts!.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SendCredexScreen(
            senderAccount: accounts!.first,
            accountRepository: accountRepository,
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => AccountSelectionBottomSheet(
          accounts: accounts!,
          action: AccountSelectionAction.send,
          accountRepository: accountRepository,
        ),
      );
    }
  }

  void _handleReceiveTap(BuildContext context) {
    if (accounts == null || accounts!.isEmpty) return;

    if (accounts!.length == 1) {
      _showQRDialog(context, accounts!.first);
    } else {
      _showAccountSelection(context);
    }
  }

  void _showQRDialog(BuildContext context, DashboardAccount account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(HomeConstants.cardBorderRadius),
          ),
        ),
        child: AccountQRDialog(account: account),
      ),
    );
  }

  void _showAccountSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AccountSelectionBottomSheet(
        accounts: accounts!,
        action: AccountSelectionAction.receive,
        accountRepository: accountRepository,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: HomeConstants.defaultPadding - 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.payments_outlined,
            label: 'Send',
            onTap: () => _handleSendTap(context),
          ),
          _ActionButton(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Receive',
            onTap: () => _handleReceiveTap(context),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: HomeConstants.actionButtonSize,
            height: HomeConstants.actionButtonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: HomeConstants.actionButtonIconSize,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: HomeConstants.tinyPadding),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: HomeConstants.actionButtonTextSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
