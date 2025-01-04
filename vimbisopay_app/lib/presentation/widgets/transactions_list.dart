import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
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
  final bool _wasCancelling = false;
  String? _cancellingId;

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

  void _acceptBulkTransactions(BuildContext context) {
    context.read<HomeBloc>().add(HomeAcceptCredexBulkStarted(_selectedTransactions.toList()));
    setState(() {
      _selectionMode = false;
      _selectedTransactions.clear();
    });
  }

  void _acceptSingleTransaction(BuildContext context, String credexId) {
    context.read<HomeBloc>().add(HomeAcceptCredexBulkStarted([credexId]));
  }

  void _cancelTransaction(BuildContext context, String credexId) {
    context.read<HomeBloc>().add(HomeCancelCredexStarted(credexId));
  }

  Widget _buildPendingTransactionsSection(
    List<PendingOffer> pendingIn,
    List<PendingOffer> pendingOut,
    HomeState state,
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
              if (pendingIn.isNotEmpty && state.status != HomeStatus.acceptingCredex) ...[
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
              onPressed: state.status == HomeStatus.acceptingCredex
                  ? null
                  : () => _acceptBulkTransactions(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                minimumSize: const Size.fromHeight(40),
              ),
              child: state.status == HomeStatus.acceptingCredex
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
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
          ...pendingIn.map((offer) => _buildPendingTransactionTile(offer, true, state)),
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
          ...pendingOut.map((offer) => _buildPendingTransactionTile(offer, false, state)),
        ],
      ],
    );
  }

  Widget _buildPendingTransactionTile(PendingOffer offer, bool isIncoming, HomeState state) {
    final bool isSelected = _selectedTransactions.contains(offer.credexID);
    final bool isProcessing = state.processingCredexIds.contains(offer.credexID);
    final bool isCancelling = state.status == HomeStatus.cancellingCredex;

    final Widget transactionCard = Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected ? AppColors.primary.withOpacity(0.05) : null,
      child: InkWell(
        onTap: (state.status == HomeStatus.acceptingCredex || isProcessing || !isIncoming)
            ? null
            : _selectionMode
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
              if (_selectionMode && isIncoming)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (state.status == HomeStatus.acceptingCredex || isProcessing)
                        ? null
                        : (bool? value) {
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
                      color: isIncoming ? AppColors.success : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (!_selectionMode) ...[
                    const SizedBox(height: 8),
                    if (isIncoming)
                      ElevatedButton(
                        onPressed: (state.status == HomeStatus.acceptingCredex || isProcessing)
                            ? null
                            : () => _acceptSingleTransaction(context, offer.credexID),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(60, 30),
                        ),
                        child: isProcessing
                            ? const SizedBox(
                                height: 15,
                                width: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Confirm',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                      )
                    else
                      ElevatedButton(
                        onPressed: (isCancelling || isProcessing)
                            ? null
                            : () => _cancelTransaction(context, offer.credexID),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(60, 30),
                        ),
                        child: isProcessing
                            ? const SizedBox(
                                height: 15,
                                width: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Cancel',
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
    );

    // Wrap outgoing transactions with Dismissible for swipe-to-cancel
    if (!isIncoming && !_selectionMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: SizedBox(
          width: double.infinity,
          child: Dismissible(
            key: Key('dismiss_${offer.credexID}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              if (!isCancelling && !isProcessing) {
                _cancelTransaction(context, offer.credexID);
              }
              return false;
            },
            background: Container(
              color: AppColors.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20.0),
              child: const Icon(
                Icons.cancel,
                color: Colors.white,
                size: 28,
              ),
            ),
            child: transactionCard,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: transactionCard,
    );
  }

  Widget _buildLedgerTransactions(List<LedgerEntry> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: transactions.map((transaction) {
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
                    : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            isThreeLine: true,
            enabled: false,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNoSearchResults() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 16),
          Text(
            'No Results Found',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try adjusting your search terms or clear the search to see all transactions.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeBloc, HomeState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.pendingInTransactions != current.pendingInTransactions ||
          previous.pendingOutTransactions != current.pendingOutTransactions ||
          previous.processingCredexIds != current.processingCredexIds,
      listener: (context, state) {
        Logger.data('TransactionsList state update - Status: ${state.status}');
        Logger.data('Has pending transactions: ${state.hasPendingTransactions}');
        Logger.data('Pending in count: ${state.pendingInTransactions.length}');
        Logger.data('Pending out count: ${state.pendingOutTransactions.length}');
        
        // Clear selection for any transactions that are being processed
        if (state.processingCredexIds.isNotEmpty) {
          setState(() {
            _selectedTransactions.removeWhere((uniqueId) {
              try {
                final offer = state.pendingInTransactions
                    .firstWhere((o) => o.uniqueIdentifier == uniqueId);
                return state.isProcessingTransaction(offer.credexID);
              } catch (e) {
                // If transaction not found, it was probably removed
                return true;
              }
            });
          });
        }

        // Clear selection mode when no pending transactions
        if (!state.hasPendingTransactions && _selectionMode) {
          setState(() {
            _selectionMode = false;
            _selectedTransactions.clear();
          });
        }
      },
      builder: (context, state) {
        Logger.data('Building TransactionsList with:');
        Logger.data('- Status: ${state.status}');
        Logger.data('- Has pending: ${state.hasPendingTransactions}');
        Logger.data('- Pending in: ${state.pendingInTransactions.length}');
        Logger.data('- Pending out: ${state.pendingOutTransactions.length}');
        // Handle search state
        if (state.searchQuery.isNotEmpty) {
          final hasFilteredResults = state.filteredLedgerEntries.isNotEmpty ||
                                   state.filteredPendingInTransactions.isNotEmpty ||
                                   state.filteredPendingOutTransactions.isNotEmpty;
          
          if (!hasFilteredResults) {
            return _buildNoSearchResults();
          }

          return Column(
            children: [
              if (state.filteredPendingInTransactions.isNotEmpty || 
                  state.filteredPendingOutTransactions.isNotEmpty)
                _buildPendingTransactionsSection(
                  state.filteredPendingInTransactions,
                  state.filteredPendingOutTransactions,
                  state,
                ),
              if (state.filteredLedgerEntries.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Transaction History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _buildLedgerTransactions(state.filteredLedgerEntries),
              ],
            ],
          );
        }

        // Show normal view when not searching
        if (state.hasPendingTransactions) {
          return Column(
            children: [
              _buildPendingTransactionsSection(
                state.pendingInTransactions,
                state.pendingOutTransactions,
                state,
              ),
              if (state.status == HomeStatus.loading || state.status == HomeStatus.initial) ...[
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ),
              ] else if (state.combinedLedgerEntries.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Transaction History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _buildLedgerTransactions(state.combinedLedgerEntries),
                if (!state.hasMoreEntries)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'No more ledger entries',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else if (state.status == HomeStatus.loadingMore)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  ),
              ],
            ],
          );
        }

        // Show loading indicator only if we don't have any data yet
        if (state.status == HomeStatus.initial || state.status == HomeStatus.loading) {
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
              context.read<HomeBloc>().add(const HomeRefreshStarted());
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Transaction History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            _buildLedgerTransactions(state.combinedLedgerEntries),
            if (!state.hasMoreEntries)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'No more ledger entries',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else if (state.status == HomeStatus.loadingMore)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
