import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/presentation/blocs/send_credex/send_credex_state.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/common/styled_card.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/inputs/due_date_input.dart';

/// Widget for Credex type selection
class CredexTypeSelector extends StatelessWidget {
  final CredexType credexType;
  final Function(CredexType) onCredexTypeChanged;
  
  const CredexTypeSelector({
    super.key,
    required this.credexType,
    required this.onCredexTypeChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeButton(
              context,
              title: 'Secured',
              isSelected: credexType == CredexType.SECURED,
              onTap: () => onCredexTypeChanged(CredexType.SECURED),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildTypeButton(
              context,
              title: 'Unsecured',
              isSelected: credexType == CredexType.UNSECURED,
              onTap: () => onCredexTypeChanged(CredexType.UNSECURED),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTypeButton(
    BuildContext context, {
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.techAzure : AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? AppColors.techAzure : AppColors.textSecondary,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// Widget for the credex type section including the selector and additional info
class CredexTypeSection extends StatelessWidget {
  final CredexType credexType;
  final Function(CredexType) onCredexTypeChanged;
  final DateTime? dueDate;
  final Function(DateTime?) onDueDateChanged;
  final double availableBalance;
  final String selectedDenomination;
  final String accountName;
  final bool isEnabled;
  final bool showFullContent;
  
  const CredexTypeSection({
    super.key,
    required this.credexType,
    required this.onCredexTypeChanged,
    required this.dueDate,
    required this.onDueDateChanged,
    required this.availableBalance,
    required this.selectedDenomination,
    required this.accountName,
    this.isEnabled = true,
    this.showFullContent = false,
  });
  
  @override
  Widget build(BuildContext context) {
    // If not showing full content, just show an empty card with title
    if (!showFullContent) {
      return StyledCard.gold(
        title: '4. Type',
        child: Container(
          height: 10,
        ),
      );
    }
    
    // Otherwise show the full card content
    return StyledCard.gold(
      title: '4. Type',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, // Changed to stretch to center the text
        children: [
          // Credex Type Selector
          Opacity(
            opacity: isEnabled ? 1.0 : 0.6,
            child: CredexTypeSelector(
              credexType: credexType,
              onCredexTypeChanged: isEnabled ? onCredexTypeChanged : (_) {},
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Informational text based on selected credex type
          if (credexType == CredexType.SECURED) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Text(
                'Issuing secured credex gradually improves your credit score.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // Secured balance display with improved formatting
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.techAzure.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    accountName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Secured Balance:',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '$availableBalance $selectedDenomination',
                        style: const TextStyle(
                          color: AppColors.techAzure,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else if (credexType == CredexType.UNSECURED) ...[
            // COMING SOON text with prominent styling - centered
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'COMING SOON',
                  style: TextStyle(
                    color: AppColors.darkRed,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Text(
                'Issuing unsecured credex and providing the promised value by the agreed date immediately boosts your credit score.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // Due Date Selector
            Opacity(
              opacity: isEnabled ? 1.0 : 0.6,
              child: DueDateSelector(
                selectedDate: dueDate,
                onDateChanged: isEnabled ? onDueDateChanged : (_) {},
              ),
            ),
          ],
        ],
      ),
    );
  }
}
