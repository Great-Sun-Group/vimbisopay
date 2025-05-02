import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/presentation/blocs/send_credex/send_credex_state.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/common/styled_card.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/utils/curved_text_painter.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/utils/date_formatter.dart';

/// Widget to display a preview of what the counterparty will see for secured credex
class SecuredCounterpartyPreviewCard extends StatelessWidget {
  final String amount;
  final String denomination;
  final String senderAccountName;
  
  const SecuredCounterpartyPreviewCard({
    super.key,
    required this.amount,
    required this.denomination,
    required this.senderAccountName,
  });
  
  @override
  Widget build(BuildContext context) {
    return StyledCard(
      title: 'What your counterparty will see',
      child: Row(
        children: [
          // Incoming icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.techAzure.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.arrow_downward,
              color: AppColors.techAzure,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Transaction details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  senderAccountName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Secured Credex',
                  style: TextStyle(
                    color: AppColors.techAzure,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Amount and confirm button
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$amount $denomination',
                style: const TextStyle(
                  color: AppColors.techAzure,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
                  'Confirm',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget to display a preview of what the counterparty will see for unsecured credex
class UnsecuredCounterpartyPreviewCard extends StatelessWidget {
  final String amount;
  final String denomination;
  final String senderAccountName;
  final DateTime? dueDate;
  
  const UnsecuredCounterpartyPreviewCard({
    super.key,
    required this.amount,
    required this.denomination,
    required this.senderAccountName,
    this.dueDate,
  });
  
  @override
  Widget build(BuildContext context) {
    return StyledCard(
      title: 'What your counterparty will see',
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
                    width: 56, // Bigger
                    height: 56, // Bigger
                    decoration: BoxDecoration(
                      color: AppColors.techAzure.withOpacity(0.1), // Teal background
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  // Curved UNSECURED text
                  CustomPaint(
                    size: const Size(56, 56),
                    painter: CurvedTextPainter(
                      text: 'UNSECURED',
                      color: AppColors.techAzure,
                      fontSize: 8,
                    ),
                  ),
                  // Teal arrow icon - larger and positioned lower
                  const Positioned(
                    bottom: 4, // Position closer to bottom of circle
                    child: Icon(
                      Icons.arrow_downward,
                      color: AppColors.techAzure, // Teal color
                      size: 36, // Bigger icon
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
                      senderAccountName, // From Account name
                      style: const TextStyle(
                        color: AppColors.techAzure, // Teal color
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
                        'Promised by ${DateFormatter.formatShortDate(dueDate!)}',
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
                    '$amount $denomination',
                    style: const TextStyle(
                      color: AppColors.techAzure, // Teal color
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.techAzure, // Teal color
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Accept', // Changed from Confirm to Accept
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
                    child: SizedBox(
                      height: 18, // Taller to fit text
                      width: double.infinity,
                      child: Row(
                        children: [
                          // 70% teal (60% + 10% from orange)
                          Expanded(
                            flex: 70,
                            child: Container(
                              color: AppColors.techAzure, // Teal
                            ),
                          ),
                          // 25% gold
                          Expanded(
                            flex: 25,
                            child: Container(
                              color: AppColors.primary, // gold color
                            ),
                          ),
                          // 5% red
                          Expanded(
                            flex: 5,
                            child: Container(
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Owner credit rating text inside the bar, aligned left with black text
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Text(
                      'Owner credit rating',
                      style: TextStyle(
                        color: Colors.black, // Changed to black
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Credit rating bar for unestablished rating (0/0/0)
              Container(
                height: 18,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.techAzure, // Teal outline
                    width: 1.0,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Owner credit rating not yet established',
                    style: TextStyle(
                      color: AppColors.techAzure, // Teal text
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
    );
  }
}

/// Widget to display the counterparty preview section based on credex type and state
class CounterpartyPreviewSection extends StatelessWidget {
  final CredexType credexType;
  final String amount;
  final String denomination;
  final String senderAccountName;
  final DateTime? dueDate;
  final double availableBalance;
  
  const CounterpartyPreviewSection({
    super.key,
    required this.credexType,
    required this.amount,
    required this.denomination,
    required this.senderAccountName,
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
    
    // Check if the preview should be displayed
    final shouldShowPreview = double.tryParse(amount) != null && 
                             double.parse(amount) > 0 && 
                             (credexType != CredexType.SECURED || double.parse(amount) <= availableBalance);
    
    if (shouldShowPreview && !hasInsufficientBalance) {
      if (credexType == CredexType.SECURED) {
        return SecuredCounterpartyPreviewCard(
          amount: amount,
          denomination: denomination,
          senderAccountName: senderAccountName,
        );
      } else if (credexType == CredexType.UNSECURED) {
        return UnsecuredCounterpartyPreviewCard(
          amount: amount,
          denomination: denomination,
          senderAccountName: senderAccountName,
          dueDate: dueDate,
        );
      }
    }
    
    // Return an empty card with title if no preview should be shown
    return StyledCard(
      title: 'What your counterparty will see',
      child: Container(
        height: 80,
        alignment: Alignment.center,
        child: const Text(
          'Complete previous sections to see how this will appear to your counterparty',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
