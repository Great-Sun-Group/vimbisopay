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
                Navigator.of(context)
                    .pop(true); // Return true to indicate action was taken
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
                  _buildCredexBarGraph(state.credexDetail!),
                  const SizedBox(height: 24),
                  _buildMemberCardsSection(context, state.credexDetail!),
                  if (state.credexDetail!.clearedAgainst.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildClearedTransactionsSection(
                        context, state.credexDetail!),
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

  Widget _buildClearedTransactionsSection(
      BuildContext context, CredexDetail credex) {
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

  Widget _buildClearedTransactionTile(
      BuildContext context, ClearedTransaction cleared) {
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
                accountRepository:
                    context.read<CredexDetailBloc>().accountRepository,
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
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCredexBarGraph(CredexDetail credex) {
    return CredexBarGraph(
      credexDetail: credex,
      showLegend: true,
    );
  }

  Widget _buildMemberCardsSection(BuildContext context, CredexDetail credex) {
    // Get current user information - try multiple ways
    User? user;

    try {
      // Try StreamProvider first
      user = context.watch<User?>();
    } catch (e) {
      // If StreamProvider fails, try regular Provider
      try {
        user = context.read<User?>();
      } catch (e2) {
        // If both fail, user is null
        user = null;
      }
    }

    // Check if we have member data
    final hasIssuerData =
        credex.issuerMemberId != null && credex.issuerFirstName != null;
    final hasAcceptorData =
        credex.acceptorMemberId != null && credex.acceptorFirstName != null;

    // If we have member data but no user context, we can still show the cards
    // We'll assume the current user based on the transaction direction
    if (user == null && (hasIssuerData || hasAcceptorData)) {
      return _buildMemberCardsWithoutUserContext(
          context, credex, hasIssuerData, hasAcceptorData);
    }

    // If we don't have sufficient data, return empty
    if (user == null || (!hasIssuerData && !hasAcceptorData)) {
      return const SizedBox.shrink();
    }

    // Account names are now determined in the CredexDetail.fromApiResponse method

    // Determine current user position and arrow direction
    final isCurrentUserIssuer = user!.memberId == credex.issuerMemberId;
    final isCurrentUserAcceptor = user.memberId == credex.acceptorMemberId;

    // Current user is always on the left
    late final MemberCard leftCard;
    late final MemberCard rightCard;

    if (isCurrentUserIssuer) {
      // Current user is issuer (left), counterparty is acceptor (right)
      leftCard = MemberCard(
        memberId: credex.issuerMemberId,
        firstName: credex.issuerFirstName,
        lastName: credex.issuerLastName,
        handle: credex.issuerHandle,
        tier: credex.issuerTier,
        profilePicture: credex.issuerProfilePicture,
        creditRating: _createCreditRatingFromCredex(credex, 'issuer'),
        isCurrentUser: true,
        accountName: credex.currentUserAccountName,
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
        creditRating: _createCreditRatingFromCredex(credex, 'acceptor'),
        isCurrentUser: false,
        accountName: credex.counterpartyAccountName,
        onTap: credex.acceptorMemberId != null
            ? () => _navigateToCreditReport(context, credex.acceptorMemberId!,
                '${credex.acceptorFirstName ?? 'Unknown'} ${credex.acceptorLastName ?? 'Member'}')
            : null,
      );
    } else if (isCurrentUserAcceptor) {
      // Current user is acceptor (left), counterparty is issuer (right)
      leftCard = MemberCard(
        memberId: credex.acceptorMemberId,
        firstName: credex.acceptorFirstName,
        lastName: credex.acceptorLastName,
        handle: credex.acceptorHandle,
        tier: credex.acceptorTier,
        profilePicture: credex.acceptorProfilePicture,
        creditRating: _createCreditRatingFromCredex(credex, 'acceptor'),
        isCurrentUser: true,
        accountName: credex.currentUserAccountName,
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
        creditRating: _createCreditRatingFromCredex(credex, 'issuer'),
        isCurrentUser: false,
        accountName: credex.counterpartyAccountName,
        onTap: credex.issuerMemberId != null
            ? () => _navigateToCreditReport(context, credex.issuerMemberId!,
                '${credex.issuerFirstName ?? 'Unknown'} ${credex.issuerLastName ?? 'Member'}')
            : null,
      );
    } else {
      // Fallback: shouldn't happen, but handle gracefully
      return const SizedBox.shrink();
    }

    // Return just the row with cards, ensuring same height
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left card (current user)
        Expanded(child: leftCard),
        const SizedBox(width: 8), // Small gap between cards
        // Right card (counterparty)
        Expanded(child: rightCard),
      ],
    );
  }

  // Helper method to build member cards when user context is not available
  Widget _buildMemberCardsWithoutUserContext(
    BuildContext context,
    CredexDetail credex,
    bool hasIssuerData,
    bool hasAcceptorData,
  ) {
    // Determine layout based on available data and transaction direction
    final isDebit = credex
        .debit; // true = outgoing (user is issuer), false = incoming (user is acceptor)

    late final MemberCard leftCard;
    late final MemberCard rightCard;
    late final bool arrowPointsRight;

    if (isDebit && hasIssuerData) {
      // Outgoing transaction - current user is issuer (left)
      leftCard = MemberCard(
        memberId: credex.issuerMemberId,
        firstName: credex.issuerFirstName,
        lastName: credex.issuerLastName,
        handle: credex.issuerHandle,
        tier: credex.issuerTier,
        profilePicture: credex.issuerProfilePicture,
        creditRating: _createCreditRatingFromCredex(credex, 'issuer'),
        isCurrentUser: true,
        accountName: credex.currentUserAccountName,
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
        creditRating: _createCreditRatingFromCredex(credex, 'acceptor'),
        isCurrentUser: false,
        accountName: credex.counterpartyAccountName,
        onTap: credex.acceptorMemberId != null
            ? () => _navigateToCreditReport(context, credex.acceptorMemberId!,
                '${credex.acceptorFirstName ?? 'Unknown'} ${credex.acceptorLastName ?? 'Member'}')
            : null,
      );
      arrowPointsRight = true; // Outgoing transaction
    } else if (!isDebit && hasAcceptorData) {
      // Incoming transaction - current user is acceptor (left)
      leftCard = MemberCard(
        memberId: credex.acceptorMemberId,
        firstName: credex.acceptorFirstName,
        lastName: credex.acceptorLastName,
        handle: credex.acceptorHandle,
        tier: credex.acceptorTier,
        profilePicture: credex.acceptorProfilePicture,
        creditRating: _createCreditRatingFromCredex(credex, 'acceptor'),
        isCurrentUser: true,
        accountName: credex.currentUserAccountName,
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
        creditRating: _createCreditRatingFromCredex(credex, 'issuer'),
        isCurrentUser: false,
        accountName: credex.counterpartyAccountName,
        onTap: credex.issuerMemberId != null
            ? () => _navigateToCreditReport(context, credex.issuerMemberId!,
                '${credex.issuerFirstName ?? 'Unknown'} ${credex.issuerLastName ?? 'Member'}')
            : null,
      );
      arrowPointsRight = false; // Incoming transaction
    } else {
      // Fallback - show available data
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
              creditRating: _createCreditRatingFromCredex(credex, 'issuer'),
              isCurrentUser: false,
              onTap: credex.issuerMemberId != null
                  ? () => _navigateToCreditReport(
                      context,
                      credex.issuerMemberId!,
                      '${credex.issuerFirstName ?? 'Unknown'} ${credex.issuerLastName ?? 'Member'}')
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
              creditRating: _createCreditRatingFromCredex(credex, 'acceptor'),
              isCurrentUser: false,
              onTap: credex.acceptorMemberId != null
                  ? () => _navigateToCreditReport(
                      context,
                      credex.acceptorMemberId!,
                      '${credex.acceptorFirstName ?? 'Unknown'} ${credex.acceptorLastName ?? 'Member'}')
                  : null,
            ),
          ],
        ],
      );
    }

    // Return just the row with cards, no container wrapper
    return Row(
      children: [
        // Left card (current user)
        Expanded(child: leftCard),
        const SizedBox(width: 8), // Small gap between cards
        // Right card (counterparty)
        Expanded(child: rightCard),
      ],
    );
  }

  // Helper method to create CreditRating from API response data
  CreditRating? _createCreditRatingFromCredex(
      CredexDetail credex, String memberType) {
    // Return the credit rating for the specific member type
    if (memberType == 'issuer') {
      return credex.issuerCreditRating;
    } else if (memberType == 'acceptor') {
      return credex.acceptorCreditRating;
    }

    return null;
  }

  void _navigateToCreditReport(
      BuildContext context, String memberId, String memberName) {
    // Get the account repository from the current bloc
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
