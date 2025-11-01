import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/services/dashboard_service.dart';
import 'package:vimbisopay_app/domain/entities/credex_detail.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/presentation/blocs/credex_detail/credex_detail_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/credex_detail/credex_detail_event.dart';
import 'package:vimbisopay_app/presentation/blocs/credex_detail/credex_detail_state.dart';
import 'package:vimbisopay_app/presentation/widgets/credex_bar_graph.dart';
import 'package:vimbisopay_app/presentation/widgets/credex_detail_account_card.dart';
import 'package:vimbisopay_app/presentation/widgets/transaction_arrow.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart';
import 'package:vimbisopay_app/presentation/widgets/transactions_list.dart';
import 'package:vimbisopay_app/presentation/screens/counterparty_credit_report_screen.dart';
import 'package:vimbisopay_app/core/constants/credex_detail_dimensions.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';

class CredexDetailScreen extends StatelessWidget {
  final String credexId;
  final AccountRepository accountRepository;
  final User? user;

  const CredexDetailScreen({
    super.key,
    required this.credexId,
    required this.accountRepository,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CredexDetailBloc(
        accountRepository: accountRepository,
      )..add(CredexDetailLoadStarted(credexId)),
      child: CredexDetailView(user: user),
    );
  }
}

class CredexDetailView extends StatelessWidget {
  final User? user;

  const CredexDetailView({
    super.key,
    required this.user,
  });

  // Helper method to get colors based on credex security
  ({Color appBarColor, Color iconColor}) _getHeaderColors(bool? isSecured) {
    // Default values if no data yet
    final secured = isSecured ?? false;

    if (secured) {
      // Gold colors for secured
      return (
        appBarColor: AppColors.primary, // Gold
        iconColor: AppColors.primary, // Gold
      );
    } else {
      // Teal colors for unsecured
      return (
        appBarColor: AppColors.secondary, // Teal
        iconColor: AppColors.secondary, // Teal
      );
    }
  }

  // Helper method to get amount arrow color based on credex security
  Color _getAmountArrowColor(bool? isSecured) {
    return (isSecured ?? false) ? AppColors.primary : AppColors.secondary;
  }

  @override
  Widget build(BuildContext context) {
    // Capture user reference for use in nested functions
    final currentUser = user;

    return BlocConsumer<CredexDetailBloc, CredexDetailState>(
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

        // Navigate back after successful action
        if (state.message != null &&
            (state.message!.contains('accepted') ||
                state.message!.contains('declined') ||
                state.message!.contains('cancelled'))) {
          Future.delayed(const Duration(seconds: 2), () {
            if (context.mounted) {
              Navigator.of(context).pop(true);
            }
          });
        }
      },
      builder: (context, state) {
        // Get header colors based on credex security
        final headerStyle = _getHeaderColors(
          state.credexDetail?.securedCredex,
        );

        if (state.isLoading && !state.hasData) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: headerStyle.appBarColor,
              foregroundColor: AppColors.white,
              title: const Text(
                'Credex',
                textAlign: TextAlign.center,
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: headerStyle.iconColor,
                  ),
                  onPressed: null,
                ),
              ],
            ),
            body: Center(
              child: InlineLoadingAnimation(
                  size: CredexDetailDimensions.largeLoadingAnimationSize),
            ),
          );
        }

        if (state.hasError && !state.hasData) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: headerStyle.appBarColor,
              foregroundColor: AppColors.white,
              title: const Text(
                'Credex',
                textAlign: TextAlign.center,
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: headerStyle.iconColor,
                  ),
                  onPressed: () {
                    context.read<CredexDetailBloc>().add(
                          CredexDetailLoadStarted(state.credexId!),
                        );
                  },
                ),
              ],
            ),
            body: Center(
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
                              CredexDetailLoadStarted(state.credexId!),
                            );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: headerStyle.appBarColor,
                        foregroundColor: AppColors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (!state.hasData) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: headerStyle.appBarColor,
              foregroundColor: AppColors.white,
              title: const Text(
                'Credex',
                textAlign: TextAlign.center,
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: headerStyle.iconColor,
                  ),
                  onPressed: () {
                    context.read<CredexDetailBloc>().add(
                          CredexDetailLoadStarted(state.credexId!),
                        );
                  },
                ),
              ],
            ),
            body: const Center(
              child: Text(
                'No data available',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }

        // Main content with data
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(CredexDetailDimensions
                .headerTotalHeight), // Exact fit: automatically calculated from base dimensions
            child: AppBar(
              backgroundColor: headerStyle.appBarColor, // Main teal/gold color
              foregroundColor: AppColors.white,
              elevation: 0,
              flexibleSpace: SafeArea(
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        headerStyle.appBarColor, // Use the same teal/gold color
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title row with refresh button - Teal section
                      Container(
                        height: CredexDetailDimensions
                            .titleHeight, // Standard AppBar height
                        width: double.infinity,
                        color: headerStyle.appBarColor,
                        child: Row(
                          children: [
                            const SizedBox(
                                width:
                                    CredexDetailDimensions.standardSidePadding),
                            Expanded(
                              child: const Text(
                                'Credex',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            BlocBuilder<CredexDetailBloc, CredexDetailState>(
                              builder: (context, state) {
                                return IconButton(
                                  icon: Icon(
                                    Icons.refresh,
                                    color: headerStyle.iconColor,
                                  ),
                                  onPressed: state.isProcessing
                                      ? null
                                      : () {
                                          context.read<CredexDetailBloc>().add(
                                                CredexDetailRefreshStarted(state
                                                    .credexDetail!.credexID),
                                              );
                                        },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              context.read<CredexDetailBloc>().add(
                    CredexDetailRefreshStarted(state.credexDetail!.credexID),
                  );
            },
            color: headerStyle.iconColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCredexTransactionContainer(
                      context, state.credexDetail!, state, currentUser),
                  if (state.credexDetail!.clearedAgainst.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildClearedTransactionsSection(
                        context, state.credexDetail!, currentUser),
                  ],
                  const SizedBox(height: 24),
                  _buildActionButtons(context, state),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCredexBarGraph(CredexDetail credex) {
    return CredexBarGraph(
      credexDetail: credex,
      showLegend: true,
    );
  }

  Widget _buildCredexTransactionContainer(BuildContext context,
      CredexDetail credex, CredexDetailState state, User? currentUser) {
    final borderColor =
        credex.securedCredex ? AppColors.primary : AppColors.secondary;

    final arrowColor = _getAmountArrowColor(credex.securedCredex);

    // Use amount as-is from API
    final displayAmount = credex.formattedInitialAmount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: borderColor, width: 2.0), // Thin gold/teal border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PENDING status for pending credex (above arrow)
          if (credex.isPending) ...[
            Center(
              child: Text(
                'PENDING',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: credex.securedCredex
                      ? AppColors.primary
                      : AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ] else ...[
            const SizedBox(height: 12),
          ],
          // Arrow below PENDING (if present)
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.75,
              child: AmountWithArrow(
                amount: displayAmount,
                denomination: credex.denomination,
                pointsRight: false, // Arrow points right towards acceptor
                amountColor: AppColors.success, // Always positive/green
                arrowColor: arrowColor,
                amountFontSize: 20.0,
                containerSize:
                    CredexDetailDimensions.transactionArrowContainerSize,
                layoutHeight: 48.0,
                canvasWidth:
                    CredexDetailDimensions.transactionArrowContainerSize * 0.9,
                canvasHeight:
                    CredexDetailDimensions.transactionArrowContainerSize * 0.6,
              ),
            ),
          ),
          // SECURED/UNSECURED status below arrow
          Center(
            child: Text(
              credex.securedCredex ? 'SECURED' : 'UNSECURED',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: credex.securedCredex
                    ? AppColors.primary
                    : AppColors.secondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildInnerMemberCardsSection(context, credex, state, currentUser),
        ],
      ),
    );
  }

  Widget _buildInnerMemberCardsSection(BuildContext context,
      CredexDetail credex, CredexDetailState state, User? currentUser) {
    // Simplified: acceptor on left, issuer on right
    final leftCard = CredexDetailAccountCard(
      memberId: credex.acceptorMemberId,
      firstName: credex.acceptorFirstName,
      lastName: credex.acceptorLastName,
      tier: credex.acceptorTier,
      creditRating: credex.acceptorCreditRating,
      accountName: credex.acceptorAccountName,
      accountHandle: credex.acceptorAccountHandle,
      useExpandedSpacing: false,
      isSecured: credex.securedCredex,
      onTap: credex.acceptorMemberId != null
          ? () => _navigateToCreditReport(
              context,
              credex.acceptorMemberId!,
              '${credex.acceptorFirstName ?? ''} ${credex.acceptorLastName ?? ''}'
                  .trim())
          : null,
    );

    final rightCard = CredexDetailAccountCard(
      memberId: credex.issuerMemberId,
      firstName: credex.issuerFirstName,
      lastName: credex.issuerLastName,
      tier: credex.issuerTier,
      creditRating: credex.issuerCreditRating,
      accountName: credex.issuerAccountName,
      accountHandle: credex.issuerAccountHandle,
      useExpandedSpacing: false,
      isSecured: credex.securedCredex,
      onTap: credex.issuerMemberId != null
          ? () => _navigateToCreditReport(
              context,
              credex.issuerMemberId!,
              '${credex.issuerFirstName ?? ''} ${credex.issuerLastName ?? ''}'
                  .trim())
          : null,
    );

    return Column(
      children: [
        // Row with two equal-width member cards
        Row(
          children: [
            Expanded(
              flex: 1,
              child: SizedBox(
                height: credex.securedCredex ? 170 : 200, // Reduced height for secured credex
                child: leftCard,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: SizedBox(
                height: credex.securedCredex ? 170 : 200, // Reduced height for secured credex
                child: rightCard,
              ),
            ),
          ],
        ),
        // Only show bar graph for non-pending and non-secured credex
        if (!credex.isPending && !credex.securedCredex) ...[
          const SizedBox(height: 16),
          // Bar graph below the cards
          _buildCredexBarGraph(credex),
        ],
      ],
    );
  }

  Widget _buildClearedTransactionsSection(
      BuildContext context, CredexDetail credex, User? user) {
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
          ...credex.clearedAgainst.map((cleared) =>
              _buildClearedTransactionTile(context, cleared, user)),
        ],
      ),
    );
  }

  Widget _buildClearedTransactionTile(
      BuildContext context, ClearedTransaction cleared, User? user) {
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
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CredexDetailScreen(
                credexId: cleared.credexID,
                accountRepository:
                    context.read<CredexDetailBloc>().accountRepository,
                user: user,
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
    final currentUser = user;
    if (credex.isFinalized) {
      return const SizedBox.shrink();
    }

    // Determine user role for offers
    final isCurrentUserIssuer = currentUser != null &&
        currentUser.memberId == credex.issuerMemberId;
    final isCurrentUserAcceptor = currentUser != null &&
        currentUser.memberId == credex.acceptorMemberId;

    // For offers: issuer can cancel, acceptor can accept/decline
    // For requests: issuer can cancel (simplified logic)
    final canShowAccept = credex.canAccept &&
        credex.transactionType == 'OFFERS' &&
        isCurrentUserAcceptor;
    final canShowDecline = credex.canDecline &&
        credex.transactionType == 'OFFERS' &&
        isCurrentUserAcceptor;
    final canShowCancel = credex.canCancel &&
        (credex.transactionType == 'OFFERS' || credex.transactionType == 'REQUESTS');

    return Column(
      children: [
        if (canShowAccept) ...[
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
                  ? SizedBox(
                      height: CredexDetailDimensions.smallLoadingAnimationSize,
                      width: CredexDetailDimensions.smallLoadingAnimationSize,
                      child: InlineLoadingAnimation(
                          size:
                              CredexDetailDimensions.smallLoadingAnimationSize),
                    )
                  : const Text(
                      'Accept Credex',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (canShowDecline) ...[
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
                  ? SizedBox(
                      height: CredexDetailDimensions.smallLoadingAnimationSize,
                      width: CredexDetailDimensions.smallLoadingAnimationSize,
                      child: InlineLoadingAnimation(
                          size:
                              CredexDetailDimensions.smallLoadingAnimationSize),
                    )
                  : const Text(
                      'Decline Credex',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (canShowCancel) ...[
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
                  ? SizedBox(
                      height: CredexDetailDimensions.smallLoadingAnimationSize,
                      width: CredexDetailDimensions.smallLoadingAnimationSize,
                      child: InlineLoadingAnimation(
                          size:
                              CredexDetailDimensions.smallLoadingAnimationSize),
                    )
                  : const Text(
                      'Cancel Credex',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }

  // Helper method to navigate to credit report
  void _navigateToCreditReport(
      BuildContext context, String memberId, String memberName) {
    final accountRepository =
        context.read<CredexDetailBloc>().accountRepository;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CounterpartyCreditReportScreen(
          memberId: memberId,
          memberName: memberName,
          accountRepository: accountRepository,
        ),
      ),
    );
  }
}
