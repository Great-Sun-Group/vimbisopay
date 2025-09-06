import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_event.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_state.dart';
import 'package:vimbisopay_app/presentation/widgets/empty_state.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/utils/curved_text_painter.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/utils/date_formatter.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';


/// A compact loading animation widget that uses the Lottie animation
class InlineLoadingAnimation extends StatefulWidget {
  final double size;

  const InlineLoadingAnimation({
    super.key,
    this.size = 40,
  });

  @override
  State<InlineLoadingAnimation> createState() => _InlineLoadingAnimationState();
}

class _InlineLoadingAnimationState extends State<InlineLoadingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller with half the normal duration for 2x speed
    _animationController = AnimationController(
      vsync: this,
      // The animation has 162 frames at 60fps (about 2.7 seconds)
      // For 2x speed, we use half that duration
      duration: const Duration(milliseconds: 1350),
    );

    // Start the animation and make it repeat
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Lottie.asset(
          'assets/animations/loading_anim.json',
          fit: BoxFit.contain,
          controller: _animationController,
        ),
      ),
    );
  }
}

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
    context
        .read<HomeBloc>()
        .add(HomeAcceptCredexBulkStarted(_selectedTransactions.toList()));
    setState(() {
      _selectionMode = false;
      _selectedTransactions.clear();
    });
  }

  void _acceptSingleTransaction(BuildContext context, String credexId) {
    context.read<HomeBloc>().add(HomeAcceptCredexStarted(credexId));
  }

  void _cancelTransaction(BuildContext context, String credexId) {
    context.read<HomeBloc>().add(HomeCancelCredexStarted(credexId));
  }
  
  void _declineTransaction(BuildContext context, String credexId) {
    context.read<HomeBloc>().add(HomeDeclineCredexStarted(credexId));
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
        // No title needed here
        if (_selectionMode && _selectedTransactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              onPressed: state.status == HomeStatus.acceptingCredex
                  ? null
                  : () => _acceptBulkTransactions(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.techAzure,
                minimumSize: const Size.fromHeight(40),
              ),
              child: state.status == HomeStatus.acceptingCredex
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: InlineLoadingAnimation(size: 20),
                    )
                  : Text(
                      'Confirm ${_selectedTransactions.length} Transactions',
                      style: const TextStyle(color: AppColors.white),
                    ),
            ),
          ),
        if (pendingIn.isNotEmpty) ...[
          Container(
            color: const Color(0xFF0A1F15), // Very dull green background (dark blue with green tint)
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pending Incoming',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (pendingIn.isNotEmpty &&
                          state.status != HomeStatus.acceptingCredex) ...[
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
                ...pendingIn
                    .map((offer) => _buildPendingTransactionTile(offer, true, state)),
              ],
            ),
          ),
        ],
        if (pendingOut.isNotEmpty) ...[
          Container(
            color: const Color(0xFF1F0A0A), // Very dull red background (dark blue with red tint)
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Pending Outgoing',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                ...pendingOut.map(
                    (offer) => _buildPendingTransactionTile(offer, false, state)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPendingTransactionTile(
      PendingOffer offer, bool isIncoming, HomeState state) {
    final bool isSelected = _selectedTransactions.contains(offer.credexID);
    final bool isProcessing =
        state.processingCredexIds.contains(offer.credexID);
    final bool isCancelling = state.status == HomeStatus.cancellingCredex;
    
    // Determine colors based on secured status
    final Color accentColor = offer.secured ? AppColors.yellowMain : AppColors.techAzure;
    final String securedText = offer.secured ? 'SECURED' : 'UNSECURED';
    
    final Widget transactionCard = Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? AppColors.primary : accentColor,
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: (state.status == HomeStatus.acceptingCredex ||
                isProcessing)
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
                : () {
                    // Add debug logging
                    Logger.data('Transaction tapped: ${offer.credexID}, secured: ${offer.secured}');
                    
                    // Navigate to Credex detail screen for both secured and unsecured credexes
                    Logger.data('Navigating to credex detail for credex: ${offer.credexID}');
                    Navigator.pushNamed(
                      context,
                      '/credex-detail',
                      arguments: {
                        'credexID': offer.credexID,
                        'accountRepository': AccountRepositoryImpl(),
                      },
                    );
                  },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_selectionMode && isIncoming)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (state.status == HomeStatus.acceptingCredex ||
                            isProcessing)
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
              Column(
                children: [
                  // Styled icon with curved text
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background circle
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      // Curved text
                      CustomPaint(
                        size: const Size(56, 56),
                        painter: CurvedTextPainter(
                          text: securedText,
                          color: accentColor,
                          fontSize: 8,
                        ),
                      ),
                      // Arrow icon
                      Positioned(
                        bottom: 4,
                        child: Icon(
                          isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isIncoming ? AppColors.green : AppColors.error,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                  // Add Decline button for incoming transactions
                  if (isIncoming && !_selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: GestureDetector(
                        onTap: (state.status == HomeStatus.acceptingCredex ||
                                isProcessing)
                            ? null
                            : () => _declineTransaction(context, offer.credexID),
                        child: const Text(
                          'Decline',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.counterpartyAccountName,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (offer.dueDate != null || !offer.secured) 
                      Text(
                        offer.dueDate != null 
                            ? 'Promised by ${DateFormatter.formatShortDate(offer.dueDate!)}'
                            : 'No due date',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    
                    // Display credit rating bar for unsecured transactions
                    if (!offer.secured && offer.counterpartyCreditRating != null) ...[
                      const SizedBox(height: 8),
                      _buildCreditRatingBar(offer.counterpartyCreditRating!),
                    ],
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
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  if (!_selectionMode) ...[
                    const SizedBox(height: 8),
                    if (isIncoming)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isProcessing ? AppColors.green.withOpacity(0.6) : AppColors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: GestureDetector(
                          onTap: (state.status == HomeStatus.acceptingCredex ||
                                  isProcessing)
                              ? null
                              : () => _acceptSingleTransaction(
                                  context, offer.credexID),
                          child: isProcessing
                              ? const SizedBox(
                                  height: 15,
                                  width: 15,
                                  child: InlineLoadingAnimation(size: 15),
                                )
                              : const Text(
                                  'Accept',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isProcessing
                              ? AppColors.error.withOpacity(0.6)
                              : AppColors.error,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: GestureDetector(
                          onTap: (isCancelling || isProcessing)
                              ? null
                              : () => _cancelTransaction(context, offer.credexID),
                          child: isProcessing
                              ? const Text(
                                  'Processing...',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                color: AppColors.white,
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
        // Determine if transaction is incoming or outgoing
        final bool isIncoming = transaction.amount >= 0;
        
        // Determine if transaction is secured or unsecured based on type
        final bool isSecured = transaction.type.toLowerCase() == 'secured';
        final Color accentColor = isSecured ? AppColors.primary : AppColors.techAzure;
        
        // Text color for amount - red for negative numbers
        final Color amountColor = isIncoming ? accentColor : AppColors.error;
        
        return Semantics(
          label: _getTransactionSemanticLabel(transaction),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: accentColor,
                  width: 1.0,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  // Add debug logging for ledger transactions
                  Logger.data('Ledger transaction tapped: ${transaction.credexID}, secured: $isSecured');
                  
                  // Navigate to Credex detail screen for both secured and unsecured ledger transactions
                  if (transaction.credexID != null) {
                    Logger.data('Navigating to credex detail for ledger transaction: ${transaction.credexID}');
                    Navigator.pushNamed(
                      context,
                      '/credex-detail',
                      arguments: {
                        'credexID': transaction.credexID!,
                        'accountRepository': AccountRepositoryImpl(),
                      },
                    );
                  } else {
                    Logger.data('No credexID available - no navigation');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction.counterpartyAccountName,
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM d, yyyy h:mm a').format(transaction.timestamp),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
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
                            transaction.formattedAmount,
                            style: TextStyle(
                              color: amountColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCreditRatingBar(CreditRating rating) {
    // Calculate percentages for the credit rating bar
    final double total = rating.redeemedTotalUSD + 
                 rating.outstandingTotalUSD + 
                 rating.defaultedTotalUSD + 
                 rating.writtenOffTotalUSD;
    
    // Calculate percentages of each component
    int redeemedPercent = total > 0 ? ((rating.redeemedTotalUSD / total) * 100).round() : 0;
    int outstandingPercent = total > 0 ? ((rating.outstandingTotalUSD / total) * 100).round() : 0;
    int defaultedPercent = total > 0 ? ((rating.defaultedTotalUSD / total) * 100).round() : 0;
    int writtenOffPercent = total > 0 ? ((rating.writtenOffTotalUSD / total) * 100).round() : 0;
    
    // Ensure minimum visibility for non-zero values
    if (rating.redeemedTotalUSD > 0 && redeemedPercent == 0) redeemedPercent = 1;
    if (rating.outstandingTotalUSD > 0 && outstandingPercent == 0) outstandingPercent = 1;
    if (rating.defaultedTotalUSD > 0 && defaultedPercent == 0) defaultedPercent = 1;
    if (rating.writtenOffTotalUSD > 0 && writtenOffPercent == 0) writtenOffPercent = 1;
    
    // Adjust percentages to ensure they sum to 100%
    final int sum = redeemedPercent + outstandingPercent + defaultedPercent + writtenOffPercent;
    if (sum != 100 && sum > 0) {
      // Find the largest component to adjust
      int largest = redeemedPercent;
      String largestType = 'redeemed';
      
      if (outstandingPercent > largest) {
        largest = outstandingPercent;
        largestType = 'outstanding';
      }
      if (defaultedPercent > largest) {
        largest = defaultedPercent;
        largestType = 'defaulted';
      }
      if (writtenOffPercent > largest) {
        largest = writtenOffPercent;
        largestType = 'writtenOff';
      }
      
      // Adjust the largest component
      if (largestType == 'redeemed') {
        redeemedPercent += (100 - sum);
      } else if (largestType == 'outstanding') {
        outstandingPercent += (100 - sum);
      } else if (largestType == 'defaulted') {
        defaultedPercent += (100 - sum);
      } else {
        writtenOffPercent += (100 - sum);
      }
    }
    
    // If all values are zero, show "not yet established" message
    if (total == 0) {
      return Container(
        height: 18,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: AppColors.techAzure,
            width: 1.0,
          ),
        ),
        child: const Center(
          child: Text(
            'Counterparty credit rating not yet established',
            style: TextStyle(
              color: AppColors.techAzure,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    // Return credit rating bar with calculated percentages
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        // Bar graph with calculated proportions
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 18,
            width: double.infinity,
            child: Row(
              children: [
                // Redeemed (primary)
                if (redeemedPercent > 0)
                  Expanded(
                    flex: redeemedPercent,
                    child: Container(
                      color: AppColors.primary,
                    ),
                  ),
                // Outstanding (blue)
                if (outstandingPercent > 0)
                  Expanded(
                    flex: outstandingPercent,
                    child: Container(
                      color: AppColors.techAzure,
                    ),
                  ),
                // Defaulted (amber)
                if (defaultedPercent > 0)
                  Expanded(
                    flex: defaultedPercent,
                    child: Container(
                      color: AppColors.yellowPrimary,
                    ),
                  ),
                // Written off (red)
                if (writtenOffPercent > 0)
                  Expanded(
                    flex: writtenOffPercent,
                    child: Container(
                      color: AppColors.darkRed,
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Counterparty credit rating text inside the bar
        const Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Text(
            'Counterparty credit rating',
            style: TextStyle(
              color: Colors.black,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
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
        Logger.data(
            'Has pending transactions: ${state.hasPendingTransactions}');
        Logger.data('Pending in count: ${state.pendingInTransactions.length}');
        Logger.data(
            'Pending out count: ${state.pendingOutTransactions.length}');

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
          // Check if we have any results at all
          final hasFilteredResults = state.filteredLedgerEntries.isNotEmpty ||
              state.filteredPendingInTransactions.isNotEmpty ||
              state.filteredPendingOutTransactions.isNotEmpty;

          Logger.data('Search query: ${state.searchQuery}');
          Logger.data('Has filtered results: $hasFilteredResults');
          Logger.data(
              'Filtered ledger entries: ${state.filteredLedgerEntries.length}');
          Logger.data(
              'Filtered pending in: ${state.filteredPendingInTransactions.length}');
          Logger.data(
              'Filtered pending out: ${state.filteredPendingOutTransactions.length}');

          // Show no results view if we have no matches
          if (!hasFilteredResults) {
            return _buildNoSearchResults();
          }

          // Show filtered results
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'Account Ledger',
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
            ),
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
              if (state.status == HomeStatus.loading ||
                  state.status == HomeStatus.initial) ...[
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: InlineLoadingAnimation(size: 80),
                  ),
                ),
              ] else if (state.combinedLedgerEntries.isNotEmpty) ...[
                const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Account Ledger',
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
                      child: InlineLoadingAnimation(size: 50),
                    ),
                  ),
              ],
            ],
          );
        }

        // Show loading indicator only if we don't have any data yet
        if (state.status == HomeStatus.initial ||
            state.status == HomeStatus.loading) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(
              child: InlineLoadingAnimation(size: 80),
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
                  'Your Account Ledger will appear here once you start sending or receiving payments.',
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
                'Account Ledger',
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
                  child: InlineLoadingAnimation(size: 50),
                ),
              ),
          ],
        );
      },
    );
  }
}
