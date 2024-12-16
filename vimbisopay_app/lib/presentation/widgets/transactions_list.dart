import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_event.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_state.dart';
import 'package:vimbisopay_app/presentation/widgets/empty_state.dart';

class TransactionsList extends StatelessWidget {
  const TransactionsList({super.key});

  IconData _getTransactionIcon(String type, double amount) {
    switch (type.toLowerCase()) {
      case 'transfer':
        return amount >= 0 ? Icons.arrow_downward : Icons.arrow_upward;
      case 'payment':
        return amount >= 0 ? Icons.payments : Icons.payment;
      case 'deposit':
        return Icons.account_balance_wallet;
      case 'withdrawal':
        return Icons.money_off;
      default:
        return Icons.swap_horiz;
    }
  }

  String _getTransactionSemanticLabel(LedgerEntry transaction) {
    final dateFormat = DateFormat('MMMM d, yyyy h:mm a');
    final formattedDate = dateFormat.format(transaction.timestamp);
    final transactionType = transaction.amount >= 0 ? 'Received' : 'Sent';

    return '$transactionType ${transaction.formattedAmount} on $formattedDate. '
        'Transaction with ${transaction.counterpartyAccountName}. '
        'Description: ${transaction.description}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        print('TransactionList state: ${state.status}');
        if (state.status == HomeStatus.initial ||
            ((state.status == HomeStatus.loading || state.status == HomeStatus.success) &&
             state.combinedLedgerEntries.isEmpty &&
             state.accountLedgers.isEmpty)) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          );
        }

        if (state.error != null) {
          return EmptyState(
            icon: Icons.cloud_off_rounded,
            message: state.error!,
            onRetry: () {
              context.read<HomeBloc>().add(const HomeLedgerLoaded(
                    accountLedgers: {},
                    combinedEntries: [],
                    hasMore: true,
                  ));
            },
          );
        }

        if (state.combinedLedgerEntries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                SizedBox(height: 16),
                Text(
                  'No Transactions Yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your transaction history will appear here once you start sending or receiving payments.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 24),
              ],
            ),
          );
        }

        return Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.combinedLedgerEntries.length,
              itemBuilder: (context, index) {
                final transaction = state.combinedLedgerEntries[index];
                final dateFormat = DateFormat('MMM d, yyyy h:mm a');
                final formattedDate = dateFormat.format(transaction.timestamp);

                return Semantics(
                  label: _getTransactionSemanticLabel(transaction),
                  child: ListTile(
                    leading: Icon(
                      _getTransactionIcon(transaction.type, transaction.amount),
                      color: transaction.amount >= 0
                          ? AppColors.success
                          : AppColors.error,
                      size: 28,
                    ),
                    title: Text(
                      transaction.description,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.counterpartyAccountName,
                          style: TextStyle(
                            color: AppColors.primary.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      transaction.formattedAmount,
                      style: TextStyle(
                        color: transaction.amount >= 0
                            ? AppColors.success
                            : AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    isThreeLine: true,
                    enabled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                );
              },
            ),
            if (state.status == HomeStatus.loadingMore)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
