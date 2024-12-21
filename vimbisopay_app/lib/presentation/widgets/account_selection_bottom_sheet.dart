import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/presentation/widgets/account_qr_dialog.dart';
import 'package:vimbisopay_app/presentation/models/send_credex_arguments.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';

enum AccountSelectionAction {
  send,
  receive,
}

class AccountSelectionBottomSheet extends StatelessWidget {
  final List<DashboardAccount> accounts;
  final AccountSelectionAction action;
  final AccountRepository accountRepository;
  final HomeBloc homeBloc;
  final DatabaseHelper databaseHelper;

  const AccountSelectionBottomSheet({
    Key? key,
    required this.accounts,
    required this.action,
    required this.accountRepository,
    required this.homeBloc,
    required this.databaseHelper,
  }) : super(key: key);

  void _handleAccountSelection(BuildContext context, DashboardAccount account) {
    Navigator.pop(context); // Close bottom sheet

    if (action == AccountSelectionAction.receive) {
      Logger.interaction('Showing QR for selected account');
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: AccountQRDialog(account: account),
        ),
      );
    } else if (action == AccountSelectionAction.send) {
      Logger.interaction('Navigating to send credex with selected account');
      Navigator.pushNamed(
        context,
        '/send-credex',
        arguments: SendCredexArguments(
          senderAccount: account,
          accountRepository: accountRepository,
          homeBloc: homeBloc,
          databaseHelper: databaseHelper,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                action == AccountSelectionAction.send 
                    ? 'Select Account to Send From'
                    : 'Select Account to Receive To',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return ListTile(
                title: Text(
                  account.accountName,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Row(
                  children: [
                    const Text(
                      '@',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      account.accountHandle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                onTap: () => _handleAccountSelection(context, account),
              );
            },
          ),
        ],
      ),
    );
  }
}
