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
    return BottomNavigationBar(
      backgroundColor: AppColors.surface,
      elevation: 8,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.primary,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
            ),
            child: const Icon(Icons.payments_outlined),
          ),
          label: 'Send',
        ),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined),
          ),
          label: 'Receive',
        ),
      ],
      onTap: (index) {
        if (index == 0) {
          _handleSendTap(context);
        } else {
          _handleReceiveTap(context);
        }
      },
    );
  }
}
