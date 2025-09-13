import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/credex_detail.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/presentation/blocs/credex_detail/credex_detail_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/credex_detail/credex_detail_event.dart';
import 'package:vimbisopay_app/presentation/blocs/credex_detail/credex_detail_state.dart';
import 'package:vimbisopay_app/presentation/widgets/credex_bar_graph.dart';
import 'package:vimbisopay_app/presentation/widgets/member_card.dart';
import 'package:vimbisopay_app/presentation/widgets/transaction_arrow.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart';
import 'package:vimbisopay_app/presentation/widgets/transactions_list.dart';
import 'package:vimbisopay_app/presentation/screens/counterparty_credit_report_screen.dart';
import 'package:vimbisopay_app/core/constants/credex_detail_dimensions.dart';

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
      child: const CredexDetailView(),
    );
  }
}

class CredexDetailView extends StatelessWidget {
  const CredexDetailView({super.key});

  // Helper method to get colors and title based on credex security
  ({Color appBarColor, Color iconColor, String title}) _getHeaderColors(
      bool? isSecured, String? formattedAmount) {
    // Default values if no data yet
    final secured = isSecured ?? false;
    final amount = formattedAmount ?? '0.00';

    // Remove negative sign for display
    final displayAmount = amount.replaceAll('-', '');

    if (secured) {
      // Gold colors for secured
      return (
        appBarColor: AppColors.primary, // Gold
        iconColor: AppColors.primary, // Gold
        title: 'Credex $displayAmount'
      );
    } else {
      // Teal colors for unsecured
      return (
        appBarColor: AppColors.secondary, // Teal
        iconColor: AppColors.secondary, // Teal
        title: 'Credex $displayAmount'
      );
    }
  }

  // Helper method to get amount arrow color based on credex security
  Color _getAmountArrowColor(bool? isSecured) {
    return (isSecured ?? false) ? AppColors.primary : AppColors.secondary;
  }

  @override
  Widget build(BuildContext context) {
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
          state.credexDetail?.formattedInitialAmount,
        );

        if (state.isLoading && !state.hasData) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: headerStyle.appBarColor,
              foregroundColor: AppColors.white,
              title: Text(
                headerStyle.title,
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
              child: InlineLoadingAnimation(size: CredexDetailDimensions.largeLoadingAnimationSize),
            ),
          );
        }

        if (state.hasError && !state.hasData) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: headerStyle.appBarColor,
              foregroundColor: AppColors.white,
              title: Text(
                headerStyle.title,
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
                          CredexDetailLoadStarted(''),
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
                              CredexDetailLoadStarted(''),
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
              title: Text(
                headerStyle.title,
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
                          CredexDetailLoadStarted(''),
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
            preferredSize: Size.fromHeight(CredexDetailDimensions.headerTotalHeight), // Exact fit: automatically calculated from base dimensions
            child: AppBar(
              backgroundColor: headerStyle.appBarColor, // Main teal/gold color
              foregroundColor: AppColors.white,
              elevation: 0,
              flexibleSpace: SafeArea(
                child: Container(
                  decoration: BoxDecoration(
                    color: headerStyle.appBarColor, // Use the same teal/gold color
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title row with refresh button - Teal section
                      Container(
                        height: CredexDetailDimensions.titleHeight, // Standard AppBar height
                        width: double.infinity,
                        color: headerStyle.appBarColor,
                        child: Row(
                          children: [
                            const SizedBox(width: CredexDetailDimensions.standardSidePadding),
                            Expanded(
                              child: Text(
                                headerStyle.title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.white,
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
                                                CredexDetailRefreshStarted(
                                                    state.credexDetail!.credexID),
                                              );
                                        },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      // Dark section with bar graph and precise bottom border
                      Container(
                        width: double.infinity,
                        height: CredexDetailDimensions.barGraphContentHeight, // Bar graph space only
                        padding: CredexDetailDimensions.headerContentPadding,
                        decoration: BoxDecoration(
                          color: AppColors.darkBluePrimary, // Background color inside decoration
                          border: Border(
                            bottom: BorderSide(
                              color: headerStyle.appBarColor, // Teal/gold color matching header
                              width: CredexDetailDimensions.borderWidth, // Precise border thickness
                            ),
                          ),
                        ),
                        child: _buildCredexBarGraph(state.credexDetail!),
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
                  _buildMemberCardsSection(context, state.credexDetail!),
                  if (state.credexDetail!.clearedAgainst.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildClearedTransactionsSection(context, state.credexDetail!),
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

  Widget _buildMemberCardsSection(BuildContext context, CredexDetail credex) {
    // Get current user information
    User? user;
    try {
      user = context.watch<User?>();
    } catch (e) {
      try {
        user = context.read<User?>();
      } catch (e) {
        user = null;
      }
    }

    // Check if we have member data
    final hasIssuerData = credex.issuerMemberId != null && credex.issuerFirstName != null;
    final hasAcceptorData = credex.acceptorMemberId != null && credex.acceptorFirstName != null;

    // Build member cards without user context if needed
    if (user == null && (hasIssuerData || hasAcceptorData)) {
      return _buildMemberCardsWithoutUserContext(context, credex, hasIssuerData, hasAcceptorData);
    }

    // Return empty if insufficient data
    if (user == null || (!hasIssuerData && !hasAcceptorData)) {
      return const SizedBox.shrink();
    }

    // Determine user position
    final isCurrentUserIssuer = user!.memberId == credex.issuerMemberId;
    final isCurrentUserAcceptor = user.memberId == credex.acceptorMemberId;

    // Current user is always on the left
    late final MemberCard leftCard;
    late final MemberCard rightCard;

    if (isCurrentUserIssuer) {
      leftCard = MemberCard(
        memberId: credex.issuerMemberId,
        firstName: credex.issuerFirstName,
        lastName: credex.issuerLastName,
        handle: credex.issuerHandle,
        tier: credex.issuerTier,
        profilePicture: credex.issuerProfilePicture,
        creditRating: _getCreditRating(credex, 'issuer'),
        isCurrentUser: true,
        accountName: credex.currentUserAccountName,
        useExpandedSpacing: true,
        onTap: credex.issuerMemberId != null
            ? () => _navigateToCreditReport(context, credex.issuerMemberId!,
                '${credex.issuerFirstName ?? 'Unknown'} ${credex.issuerLastName ?? 'Member'}')
            : null,
      );
      rightCard = MemberCard(
        memberId: credex.acceptorMemberId,
        firstName: credex.acceptorFirstName,
        lastName: credex.acceptorLastName,
        handle: credex.acceptorHandle,
        tier: credex.acceptorTier,
        profilePicture: credex.acceptorProfilePicture,
        creditRating: _getCreditRating(credex, 'acceptor'),
        isCurrentUser: false,
        accountName: credex.counterpartyAccountName,
        useExpandedSpacing: false,
        onTap: credex.acceptorMemberId != null
            ? () => _navigateToCreditReport(context, credex.acceptorMemberId!,
                '${credex.acceptorFirstName ?? 'Unknown'} ${credex.acceptorLastName ?? 'Member'}')
            : null,
      );
    } else if (isCurrentUserAcceptor) {
      leftCard = MemberCard(
        memberId: credex.acceptorMemberId,
        firstName: credex.acceptorFirstName,
        lastName: credex.acceptorLastName,
        handle: credex.acceptorHandle,
        tier: credex.acceptorTier,
        profilePicture: credex.acceptorProfilePicture,
        creditRating: _getCreditRating(credex, 'acceptor'),
        isCurrentUser: true,
        accountName: credex.currentUserAccountName,
        useExpandedSpacing: true,
        onTap: credex.acceptorMemberId != null
            ? () => _navigateToCreditReport(context, credex.acceptorMemberId!,
                '${credex.acceptorFirstName ?? 'Unknown'} ${credex.acceptorLastName ?? 'Member'}')
            : null,
      );
      rightCard = MemberCard(
        memberId: credex.issuerMemberId,
        firstName: credex.issuerFirstName,
        lastName: credex.issuerLastName,
        handle: credex.issuerHandle,
        tier: credex.issuerTier,
        profilePicture: credex.issuerProfilePicture,
        creditRating: _getCreditRating(credex, 'issuer'),
        isCurrentUser: false,
        accountName: credex.counterpartyAccountName,
        useExpandedSpacing: false,
        onTap: credex.issuerMemberId != null
            ? () => _navigateToCreditReport(context, credex.issuerMemberId!,
                '${credex.issuerFirstName ?? 'Unknown'} ${credex.issuerLastName ?? 'Member'}')
            : null,
      );
    } else {
      return const SizedBox.shrink();
    }

    // Create amount widget with conditional colors
    final isNegative = credex.initialAmount < 0;
    final arrowColor = _getAmountArrowColor(credex.securedCredex);
    final displayAmount = credex.formattedInitialAmount.replaceAll('-', '');

    final amountWithArrow = AmountWithArrow(
      amount: displayAmount,
      isNegative: isNegative,
      amountColor: isNegative ? AppColors.errorRed : AppColors.success,
      arrowColor: arrowColor,
      amountFontSize: 20.0,
      containerSize: CredexDetailDimensions.transactionArrowContainerSize,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: leftCard),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: isNegative
                ? [
                    amountWithArrow,
                    const SizedBox(height: 8),
                    rightCard,
                  ]
                : [
                    rightCard,
                    const SizedBox(height: 8),
                    amountWithArrow,
                  ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberCardsWithoutUserContext(
      BuildContext context, CredexDetail credex, bool hasIssuerData, bool hasAcceptorData) {
    // Determine layout based on transaction direction
    final isDebit = credex.debit;

    late final MemberCard leftCard;
    late final MemberCard rightCard;

    if (isDebit && hasIssuerData) {
      leftCard = MemberCard(
        memberId: credex.issuerMemberId,
        firstName: credex.issuerFirstName,
        lastName: credex.issuerLastName,
        handle: credex.issuerHandle,
        tier: credex.issuerTier,
        profilePicture: credex.issuerProfilePicture,
        creditRating: _getCreditRating(credex, 'issuer'),
        isCurrentUser: true,
        accountName: credex.currentUserAccountName,
        useExpandedSpacing: true,
        onTap: credex.issuerMemberId != null
            ? () => _navigateToCreditReport(context, credex.issuerMemberId!,
                '${credex.issuerFirstName ?? 'Unknown'} ${credex.issuerLastName ?? 'Member'}')
            : null,
      );
      rightCard = MemberCard(
        memberId: credex.acceptorMemberId,
        firstName: credex.acceptorFirstName,
        lastName: credex.acceptorLastName,
        handle: credex.acceptorHandle,
        tier: credex.acceptorTier,
        profilePicture: credex.acceptorProfilePicture,
        creditRating: _getCreditRating(credex, 'acceptor'),
        isCurrentUser: false,
        accountName: credex.counterpartyAccountName,
        useExpandedSpacing: false,
        onTap: credex.acceptorMemberId != null
            ? () => _navigateToCreditReport(context, credex.acceptorMemberId!,
                '${credex.acceptorFirstName ?? 'Unknown'} ${credex.acceptorLastName ?? 'Member'}')
            : null,
      );
    } else if (!isDebit && hasAcceptorData) {
      leftCard = MemberCard(
        memberId: credex.acceptorMemberId,
        firstName: credex.acceptorFirstName,
        lastName: credex.acceptorLastName,
        handle: credex.acceptorHandle,
        tier: credex.acceptorTier,
        profilePicture: credex.acceptorProfilePicture,
        creditRating: _getCreditRating(credex, 'acceptor'),
        isCurrentUser: true,
        accountName: credex.currentUserAccountName,
        useExpandedSpacing: true,
        onTap: credex.acceptorMemberId != null
            ? () => _navigateToCreditReport(context, credex.acceptorMemberId!,
                '${credex.acceptorFirstName ?? 'Unknown'} ${credex.acceptorLastName ?? 'Member'}')
            : null,
      );
      rightCard = MemberCard(
        memberId: credex.issuerMemberId,
        firstName: credex.issuerFirstName,
        lastName: credex.issuerLastName,
        handle: credex.issuerHandle,
        tier: credex.issuerTier,
        profilePicture: credex.issuerProfilePicture,
        creditRating: _getCreditRating(credex, 'issuer'),
        isCurrentUser: false,
        accountName: credex.counterpartyAccountName,
        useExpandedSpacing: false,
        onTap: credex.issuerMemberId != null
            ? () => _navigateToCreditReport(context, credex.issuerMemberId!,
                '${credex.issuerFirstName ?? 'Unknown'} ${credex.issuerLastName ?? 'Member'}')
            : null,
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasIssuerData) ...[
            MemberCard(
              memberId: credex.issuerMemberId,
              firstName: credex.issuerFirstName,
              lastName: credex.issuerLastName,
              handle: credex.issuerHandle,
              tier: credex.issuerTier,
              profilePicture: credex.issuerProfilePicture,
              creditRating: _getCreditRating(credex, 'issuer'),
              isCurrentUser: false,
              useExpandedSpacing: true,
              onTap: credex.issuerMemberId != null
                  ? () => _navigateToCreditReport(context, credex.issuerMemberId!,
                      '${credex.issuerFirstName ?? ''} ${credex.issuerLastName ?? ''}'.trim())
                  : null,
            ),
            const SizedBox(height: 16),
          ],
          if (hasAcceptorData) ...[
            MemberCard(
              memberId: credex.acceptorMemberId,
              firstName: credex.acceptorFirstName,
              lastName: credex.acceptorLastName,
              handle: credex.acceptorHandle,
              tier: credex.acceptorTier,
              profilePicture: credex.acceptorProfilePicture,
              creditRating: _getCreditRating(credex, 'acceptor'),
              isCurrentUser: false,
              useExpandedSpacing: false,
              onTap: credex.acceptorMemberId != null
                  ? () => _navigateToCreditReport(context, credex.acceptorMemberId!,
                      '${credex.acceptorFirstName ?? ''} ${credex.acceptorLastName ?? ''}'.trim())
                  : null,
            ),
          ],
        ],
      );
    }

    // Create amount widget with conditional colors
    final isNegative = credex.initialAmount < 0;
    final arrowColor = _getAmountArrowColor(credex.securedCredex);
    final displayAmount = credex.formattedInitialAmount.replaceAll('-', '');

    final amountWithArrow = AmountWithArrow(
      amount: displayAmount,
      isNegative: isNegative,
      amountColor: isNegative ? AppColors.errorRed : AppColors.success,
      arrowColor: arrowColor,
      amountFontSize: 20.0,
      containerSize: CredexDetailDimensions.transactionArrowContainerSize,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: leftCard),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: isNegative
                ? [
                    amountWithArrow,
                    const SizedBox(height: 8),
                    rightCard,
                  ]
                : [
                    rightCard,
                    const SizedBox(height: 8),
                    amountWithArrow,
                  ],
          ),
        ),
      ],
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
          ...credex.clearedAgainst
              .map((cleared) => _buildClearedTransactionTile(context, cleared)),
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
      return const SizedBox.shrink();
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
                  ? SizedBox(
                      height: CredexDetailDimensions.smallLoadingAnimationSize,
                      width: CredexDetailDimensions.smallLoadingAnimationSize,
                      child: InlineLoadingAnimation(size: CredexDetailDimensions.smallLoadingAnimationSize),
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
                  ? SizedBox(
                      height: CredexDetailDimensions.smallLoadingAnimationSize,
                      width: CredexDetailDimensions.smallLoadingAnimationSize,
                      child: InlineLoadingAnimation(size: CredexDetailDimensions.smallLoadingAnimationSize),
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
                  ? SizedBox(
                      height: CredexDetailDimensions.smallLoadingAnimationSize,
                      width: CredexDetailDimensions.smallLoadingAnimationSize,
                      child: InlineLoadingAnimation(size: CredexDetailDimensions.smallLoadingAnimationSize),
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

  // Helper method to get credit rating
  CreditRating? _getCreditRating(CredexDetail credex, String memberType) {
    if (memberType == 'issuer') {
      return credex.issuerCreditRating;
    } else if (memberType == 'acceptor') {
      return credex.acceptorCreditRating;
    }
    return null;
  }

  // Helper method to navigate to credit report
  void _navigateToCreditReport(BuildContext context, String memberId, String memberName) {
    final accountRepository = context.read<CredexDetailBloc>().accountRepository;
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
