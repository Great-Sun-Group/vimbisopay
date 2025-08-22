import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/credex_detail.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/presentation/blocs/credex_detail/credex_detail_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/credex_detail/credex_detail_event.dart';
import 'package:vimbisopay_app/presentation/blocs/credex_detail/credex_detail_state.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart';
import 'package:vimbisopay_app/presentation/widgets/transactions_list.dart';

class CredexDetailScreen extends StatelessWidget {
  final String credexId;
  final AccountRepository accountRepository;

  const CredexDetailScreen({
    super.key,
    required this.credexId,
    required this.accountRepository,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CredexDetailBloc(
        accountRepository: accountRepository,
      )..add(CredexDetailLoadStarted(credexId)),
      child: CredexDetailView(credexId: credexId),
    );
  }
}

class CredexDetailView extends StatelessWidget {
  final String credexId;

  const CredexDetailView({
    super.key,
    required this.credexId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Credex Details'),
        actions: [
          BlocBuilder<CredexDetailBloc, CredexDetailState>(
            builder: (context, state) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: state.isLoading || state.isProcessing
                    ? null
                    : () {
                        context.read<CredexDetailBloc>().add(
                              CredexDetailRefreshStarted(credexId),
                            );
                      },
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<CredexDetailBloc, CredexDetailState>(
        listenWhen: (previous, current) =>
            previous.status != current.status ||
            previous.message != current.message ||
            previous.error != current.error,
        listener: (context, state) {
          // Clear any existing snackbars
          ScaffoldMessenger.of(context).clearSnackBars();

          // Show success message
          if (state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message!),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          }

          // Show error message
          if (state.hasError && state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'DISMISS',
                  textColor: AppColors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ),
            );
          }

          // Navigate back after successful action that changes status
          if (state.message != null && 
              (state.message!.contains('accepted') || 
               state.message!.contains('declined') || 
               state.message!.contains('cancelled'))) {
            // Delay navigation to allow user to see the success message
            Future.delayed(const Duration(seconds: 2), () {
              if (context.mounted) {
                Navigator.of(context).pop(true); // Return true to indicate action was taken
              }
            });
          }
        },
        builder: (context, state) {
          if (state.isLoading && !state.hasData) {
            return const Center(
              child: InlineLoadingAnimation(size: 80),
            );
          }

          if (state.hasError && !state.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error Loading Credex',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.error ?? 'An unknown error occurred',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        context.read<CredexDetailBloc>().add(
                              CredexDetailLoadStarted(credexId),
                            );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!state.hasData) {
            return const Center(
              child: Text(
                'No data available',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<CredexDetailBloc>().add(
                    CredexDetailRefreshStarted(credexId),
                  );
            },
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusHeader(context, state.credexDetail!),
                  const SizedBox(height: 24),
                  _buildAmountSection(state.credexDetail!),
                  const SizedBox(height: 24),
                  _buildCounterpartySection(state.credexDetail!),
                  const SizedBox(height: 24),
                  _buildDetailsSection(state.credexDetail!),
                  if (state.credexDetail!.clearedAgainst.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildClearedTransactionsSection(context, state.credexDetail!),
                  ],
                  const SizedBox(height: 24),
                  _buildActionButtons(context, state),
                  const SizedBox(height: 100), // Extra space at bottom
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context, CredexDetail credex) {
    Color statusColor;
    IconData statusIcon;
    
    switch (credex.status) {
      case CredexStatus.pending:
        statusColor = AppColors.yellowPrimary;
        statusIcon = Icons.schedule;
        break;
      case CredexStatus.accepted:
        statusColor = AppColors.techAzure;
        statusIcon = Icons.check_circle;
        break;
      case CredexStatus.redeemed:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_outline;
        break;
      case CredexStatus.cancelled:
        statusColor = AppColors.error;
        statusIcon = Icons.cancel;
        break;
      case CredexStatus.declined:
        statusColor = AppColors.error;
        statusIcon = Icons.block;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 2),
      ),
      child: Column(
        children: [
          Icon(
            statusIcon,
            size: 48,
            color: statusColor,
          ),
          const SizedBox(height: 12),
          Text(
            credex.statusDisplayName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            credex.securedCredex ? 'SECURED CREDEX' : 'UNSECURED CREDEX',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: credex.securedCredex ? AppColors.yellowMain : AppColors.techAzure,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSection(CredexDetail credex) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Amount Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildAmountRow('Initial Amount', credex.formattedInitialAmount, AppColors.textPrimary),
          if (credex.outstandingAmount != credex.initialAmount)
            _buildAmountRow('Outstanding', credex.formattedOutstandingAmount, AppColors.yellowPrimary),
          if (credex.redeemedAmount > 0)
            _buildAmountRow('Redeemed', credex.formattedRedeemedAmount, AppColors.success),
          if (credex.defaultedAmount > 0)
            _buildAmountRow('Defaulted', credex.formattedDefaultedAmount, AppColors.error),
          if (credex.writtenOffAmount > 0)
            _buildAmountRow('Written Off', credex.formattedWrittenOffAmount, AppColors.error),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, String amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterpartySection(CredexDetail credex) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Counterparty',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.person,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  credex.counterpartyAccountName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (credex.securerName != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.security,
                  color: AppColors.yellowMain,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Secured by',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        credex.securerName!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsSection(CredexDetail credex) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transaction Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Credex ID', credex.credexID),
          _buildDetailRow('Transaction Type', credex.transactionType),
          _buildDetailRow('Direction', credex.debit ? 'Outgoing' : 'Incoming'),
          if (credex.dueDate != null)
            _buildDetailRow('Due Date', DateFormat('MMM d, yyyy').format(credex.dueDate!)),
          if (credex.acceptedAt != null)
            _buildDetailRow('Accepted', DateFormat('MMM d, yyyy').format(credex.acceptedAt!)),
          if (credex.declinedAt != null)
            _buildDetailRow('Declined', DateFormat('MMM d, yyyy').format(credex.declinedAt!)),
          if (credex.cancelledAt != null)
            _buildDetailRow('Cancelled', DateFormat('MMM d, yyyy').format(credex.cancelledAt!)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClearedTransactionsSection(BuildContext context, CredexDetail credex) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cleared Against',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This Credex was cleared against the following transactions:',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...credex.clearedAgainst.map((cleared) => _buildClearedTransactionTile(context, cleared)),
        ],
      ),
    );
  }

  Widget _buildClearedTransactionTile(BuildContext context, ClearedTransaction cleared) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to the cleared transaction's detail screen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CredexDetailScreen(
                credexId: cleared.credexID,
                accountRepository: context.read<CredexDetailBloc>().accountRepository,
              ),
            ),
          );
        },
        child: Row(
          children: [
            const Icon(
              Icons.link,
              color: AppColors.success,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cleared.counterpartyAccountName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cleared: ${cleared.formattedClearedAmount}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Original: ${cleared.formattedInitialAmount}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, CredexDetailState state) {
    final credex = state.credexDetail!;
    
    if (credex.isFinalized) {
      return const SizedBox.shrink(); // No actions for finalized credexes
    }

    return Column(
      children: [
        if (credex.canAccept) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.isProcessing
                  ? null
                  : () {
                      context.read<CredexDetailBloc>().add(
                            CredexDetailAcceptStarted(credex.credexID),
                          );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: state.isAccepting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: InlineLoadingAnimation(size: 20),
                    )
                  : const Text(
                      'Accept Credex',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (credex.canDecline) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: state.isProcessing
                  ? null
                  : () {
                      context.read<CredexDetailBloc>().add(
                            CredexDetailDeclineStarted(credex.credexID),
                          );
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: state.isDeclining
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: InlineLoadingAnimation(size: 20),
                    )
                  : const Text(
                      'Decline Credex',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (credex.canCancel) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: state.isProcessing
                  ? null
                  : () {
                      context.read<CredexDetailBloc>().add(
                            CredexDetailCancelStarted(credex.credexID),
                          );
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: state.isCancelling
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: InlineLoadingAnimation(size: 20),
                    )
                  : const Text(
                      'Cancel Credex',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}
