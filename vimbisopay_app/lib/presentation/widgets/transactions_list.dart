import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_event.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_state.dart';
import 'package:vimbisopay_app/presentation/widgets/empty_state.dart';

class TransactionsList extends StatefulWidget {
  const TransactionsList({super.key});

  @override
  State<TransactionsList> createState() => _TransactionsListState();
}

class _TransactionsListState extends State<TransactionsList> {
  final Set<String> _selectedTransactions = {};
  bool _selectionMode = false;

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

  Widget _buildPendingTransactionsSection(
    List<PendingOffer> pendingIn,
    List<PendingOffer> pendingOut,
  ) {
    if (pendingIn.isEmpty && pendingOut.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pending Transactions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (pendingIn.isNotEmpty) ...[
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectionMode = !_selectionMode;
                      if (!_selectionMode) {
                        _selectedTransactions.clear();
                      }
                    });
                  },
                  icon: Icon(
                    _selectionMode ? Icons.close : Icons.checklist,
                    size: 20,
                  ),
                  label: Text(_selectionMode ? 'Cancel' : 'Select'),
                ),
              ],
            ],
          ),
        ),
        if (_selectionMode && _selectedTransactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              onPressed: () {
                // TODO: Implement bulk confirmation
                print('Confirming ${_selectedTransactions.length} transactions');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                minimumSize: const Size.fromHeight(40),
              ),
              child: Text(
                'Confirm ${_selectedTransactions.length} Transactions',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        if (pendingIn.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Incoming',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ...pendingIn.map((offer) => _buildPendingTransactionTile(offer, true)),
        ],
        if (pendingOut.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Outgoing',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ...pendingOut.map((offer) => _buildPendingTransactionTile(offer, false)),
        ],
      ],
    );
  }

  Widget _buildPendingTransactionTile(PendingOffer offer, bool isIncoming) {
    final bool isSelected = _selectedTransactions.contains(offer.credexID);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Card(
        elevation: isSelected ? 2 : 0,
        color: isSelected ? AppColors.primary.withOpacity(0.05) : null,
        child: InkWell(
          onTap: _selectionMode
              ? () {
                  setState(() {
                    if (isSelected) {
                      _selectedTransactions.remove(offer.credexID);
                    } else {
                      _selectedTransactions.add(offer.credexID);
                    }
                  });
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                if (_selectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedTransactions.add(offer.credexID);
                          } else {
                            _selectedTransactions.remove(offer.credexID);
                          }
                        });
                      },
                      activeColor: AppColors.primary,
                    ),
                  ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.counterpartyAccountName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        offer.secured ? 'Secured Credex' : 'Unsecured Credex',
                        style: TextStyle(
                          color: offer.secured ? AppColors.success : AppColors.warning,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      offer.formattedInitialAmount,
                      style: TextStyle(
                        color: isIncoming ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (!_selectionMode && isIncoming) ...[
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: Implement individual confirmation
                          print('Confirming transaction ${offer.credexID}');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(60, 30),
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        print('TransactionList state: ${state.status}');
        if (state.status == HomeStatus.initial ||
            ((state.status == HomeStatus.loading || state.status == HomeStatus.success) &&
             state.combinedLedgerEntries.isEmpty &&
             state.accountLedgers.isEmpty &&
             !state.hasPendingTransactions)) {
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

        if (state.combinedLedgerEntries.isEmpty && !state.hasPendingTransactions) {
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

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPendingTransactionsSection(
                state.pendingInTransactions,
                state.pendingOutTransactions,
              ),
              if (state.combinedLedgerEntries.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Transaction History',
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
              ],
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
          ),
        );
      },
    );
  }
}
