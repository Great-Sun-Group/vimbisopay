import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/presentation/widgets/empty_state.dart';

class TransactionsList extends StatelessWidget {
  final List<LedgerEntry> transactions;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final String? error;
  final VoidCallback onRetry;

  const TransactionsList({
    super.key,
    required this.transactions,
    required this.isLoading,
    required this.isRefreshing,
    required this.isLoadingMore,
    required this.error,
    required this.onRetry,
  });

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
    Widget content;

    if (isLoading && !isRefreshing && transactions.isEmpty) {
      content = const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            semanticsLabel: 'Loading transactions',
          ),
        ),
      );
    } else if (!isLoading && !isRefreshing && transactions.isEmpty) {
      content = EmptyState(
        icon: error != null ? Icons.cloud_off_rounded : Icons.receipt_long,
        message: error ?? 'No transactions found',
        onRetry: error != null ? onRetry : null,
      );
    } else {
      content = ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          final dateFormat = DateFormat('MMM d, yyyy h:mm a');
          final formattedDate = dateFormat.format(transaction.timestamp);
          
          return Semantics(
            label: _getTransactionSemanticLabel(transaction),
            child: ListTile(
              leading: Icon(
                _getTransactionIcon(transaction.type, transaction.amount),
                color: transaction.amount >= 0 ? AppColors.success : AppColors.error,
                semanticLabel: transaction.type,
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
      );
    }

    return Column(
      children: [
        content,
        if (isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                semanticsLabel: 'Loading more transactions',
              ),
            ),
          ),
      ],
    );
  }
}
