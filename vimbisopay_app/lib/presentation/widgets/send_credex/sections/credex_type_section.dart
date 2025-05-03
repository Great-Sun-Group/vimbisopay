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
          color: isSelected 
              ? (title == 'Secured' ? AppColors.yellowMain : AppColors.techAzure) 
              : AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected 
                ? (title == 'Secured' ? AppColors.yellowMain : AppColors.techAzure) 
                : AppColors.textSecondary,
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
  final String amount;
  
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
    this.amount = "0.00",
  });
  
  @override
  Widget build(BuildContext context) {
    // If not showing full content, just show an empty container
    if (!showFullContent) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
      );
    }
    
    // Otherwise show the full content without a card or title
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Credex Type Selector
          CredexTypeSelector(
            credexType: credexType,
            onCredexTypeChanged: onCredexTypeChanged,
          ),
          
          // Show appropriate content based on credex type
          if (credexType == CredexType.SECURED) ...[
            // Show amount and denomination with "transferred immediately" text for Secured
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                "$amount $selectedDenomination will be transferred immediately from your Secured Balance",
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ] else if (credexType == CredexType.UNSECURED) ...[
            // Due Date Selector for Unsecured
            DueDateSelector(
              selectedDate: dueDate,
              onDateChanged: onDueDateChanged,
              amount: amount,
              denomination: selectedDenomination,
            ),
          ],
        ],
      ),
    );
  }
}
