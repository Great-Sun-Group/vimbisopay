import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/presentation/blocs/send_credex/send_credex_state.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/common/styled_card.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/utils/date_formatter.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/utils/curved_text_painter.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/cards/counterparty_preview_card.dart';

/// Widget to display contract terms for secured credex
class SecuredContractCard extends StatelessWidget {
  final String amount;
  final String denomination;
  final String senderAccountName;
  final String recipientAccountName;
  final String memberName;
  
  const SecuredContractCard({
    super.key,
    required this.amount,
    required this.denomination,
    required this.senderAccountName,
    required this.recipientAccountName,
    required this.memberName,
  });
  
  @override
  Widget build(BuildContext context) {
    return StyledCard.gold(
      title: 'Approve the Contract',
      child: Text(
        "$memberName transfers title of $amount $denomination from the $senderAccountName account to the $recipientAccountName account, effective on acceptance of this offer.",
        style: const TextStyle(
          color: AppColors.techAzure, // All teal text color
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Widget to display contract terms for unsecured credex
class UnsecuredContractCard extends StatelessWidget {
  final String amount;
  final String denomination;
  final String senderAccountName;
  final String recipientAccountName;
  final String memberName;
  final DateTime? dueDate;
  
  const UnsecuredContractCard({
    super.key,
    required this.amount,
    required this.denomination,
    required this.senderAccountName,
    required this.recipientAccountName,
    required this.memberName,
    this.dueDate,
  });
  
  @override
  Widget build(BuildContext context) {
    return StyledCard.gold(
      title: 'Approve the Contract',
      child: Text(
        "$memberName promises to provide $amount $denomination worth of value from the $senderAccountName account to the $recipientAccountName account${dueDate != null ? ' by ${DateFormatter.formatLongDate(dueDate!)}' : ''}.",
        style: const TextStyle(
          color: AppColors.yellowMain, // All gold text color
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Widget to display a warning message for insufficient balance
class InsufficientBalanceCard extends StatelessWidget {
  final String denomination;
  
  const InsufficientBalanceCard({
    super.key,
    required this.denomination,
  });
  
  @override
  Widget build(BuildContext context) {
    return StyledCard.warning(
      child: Text(
        "Insufficient secured $denomination balance",
        style: const TextStyle(
          color: AppColors.darkRed,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Widget to display the contract section based on credex type and state
class ContractSection extends StatelessWidget {
  final CredexType credexType;
  final String amount;
  final String denomination;
  final String senderAccountName;
  final String recipientAccountName;
  final String memberName;
  final DateTime? dueDate;
  final double availableBalance;
  
  const ContractSection({
    super.key,
    required this.credexType,
    required this.amount,
    required this.denomination,
    required this.senderAccountName,
    required this.recipientAccountName,
    required this.memberName,
    this.dueDate,
    required this.availableBalance,
  });
  
  @override
  Widget build(BuildContext context) {
    // Check if there's insufficient balance for secured Credex
    final hasInsufficientBalance = credexType == CredexType.SECURED && 
                                  double.tryParse(amount) != null && 
                                  double.parse(amount) > 0 && 
                                  double.parse(amount) > availableBalance;
    
    // Check if the contract should be displayed
    final shouldShowContract = double.tryParse(amount) != null && 
                              double.parse(amount) > 0 && 
                              (credexType != CredexType.SECURED || double.parse(amount) <= availableBalance);
    
    if (hasInsufficientBalance) {
      return InsufficientBalanceCard(denomination: denomination);
    } else if (shouldShowContract) {
      if (credexType == CredexType.SECURED) {
        return StyledCard.gold(
          title: 'Approve the Contract',
          child: Column(
            children: [
              // Contract text - all teal for secured
              Text(
                "$memberName transfers title of $amount $denomination from the $senderAccountName account to the $recipientAccountName account, effective on acceptance of this offer.",
                style: const TextStyle(
                  color: AppColors.techAzure, // Teal text color
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Nested StyledCard for counterparty preview
              StyledCard(
                title: 'What your counterparty will see',
                borderColor: AppColors.yellowMain,
                borderWidth: 1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top section with icon, account name, amount and accept button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Incoming icon with SECURED text curved around
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Background circle with SECURED text
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.yellowMain.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            // Curved SECURED text
                            CustomPaint(
                              size: const Size(56, 56),
                              painter: CurvedTextPainter(
                                text: "SECURED",
                                color: AppColors.yellowMain,
                                fontSize: 8,
                              ),
                            ),
                            // Gold arrow icon
                            Positioned(
                              bottom: 4,
                              child: Icon(
                                Icons.arrow_downward,
                                color: AppColors.yellowMain,
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        
                        // Middle column - account name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                senderAccountName,
                                style: const TextStyle(
                                  color: AppColors.yellowMain,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        
                        // Right column - amount and accept button
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "$amount $denomination",
                              style: const TextStyle(
                                color: AppColors.yellowMain,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.yellowMain,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Accept',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      } else if (credexType == CredexType.UNSECURED) {
        return StyledCard.gold(
          title: 'Approve the Contract',
          child: Column(
            children: [
              // Contract text
              Text(
                "$memberName promises to provide $amount $denomination worth of value from the $senderAccountName account to the $recipientAccountName account${dueDate != null ? ' by ${DateFormatter.formatLongDate(dueDate!)}' : ''}.",
                style: const TextStyle(
                  color: AppColors.yellowMain, // Gold text color
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Nested StyledCard for counterparty preview
              StyledCard(
                title: 'What your counterparty will see',
                borderColor: AppColors.techAzure,
                borderWidth: 1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top section with icon, account name, amount and accept button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Incoming icon with UNSECURED text curved around
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Background circle with UNSECURED text
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.techAzure.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            // Curved UNSECURED text
                            CustomPaint(
                              size: const Size(56, 56),
                              painter: CurvedTextPainter(
                                text: "UNSECURED",
                                color: AppColors.techAzure,
                                fontSize: 8,
                              ),
                            ),
                            // Teal arrow icon
                            Positioned(
                              bottom: 4,
                              child: Icon(
                                Icons.arrow_downward,
                                color: AppColors.techAzure,
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        
                        // Middle column - account name and due date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                senderAccountName,
                                style: const TextStyle(
                                  color: AppColors.techAzure,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              
                              // Due date text if available
                              if (dueDate != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  "Promised by ${DateFormatter.formatShortDate(dueDate!)}",
                                  style: const TextStyle(
                                    color: AppColors.techAzure,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        // Right column - amount and accept button
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "$amount $denomination",
                              style: const TextStyle(
                                color: AppColors.techAzure,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.techAzure,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Accept',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Credit rating bars
                    Column(
                      children: [
                        // Credit rating bar with text inside (established rating)
                        Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            // Bar graph with fixed proportions
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                height: 18,
                                width: double.infinity,
                                child: Row(
                                  children: [
                                    // 70% teal
                                    Expanded(
                                      flex: 70,
                                      child: Container(
                                        color: AppColors.techAzure,
                                      ),
                                    ),
                                    // 25% gold
                                    Expanded(
                                      flex: 25,
                                      child: Container(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    // 5% red
                                    Expanded(
                                      flex: 5,
                                      child: Container(
                                        color: AppColors.darkRed,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            // Owner credit rating text inside the bar
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Text(
                                "Owner credit rating",
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Credit rating bar for unestablished rating
                        Container(
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
                              "Owner credit rating not yet established",
                              style: TextStyle(
                                color: AppColors.techAzure,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    }
    
    // Return a completely empty card with just the title - always use gold border
    return StyledCard.gold(
      title: '5. Approve the Contract',
      child: Container(
        height: 10,
      ),
    );
  }
}
