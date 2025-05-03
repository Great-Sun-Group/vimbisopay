import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/denomination.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/common/styled_card.dart';

/// Widget for amount input and denomination selection
class AmountInputSection extends StatelessWidget {
  final TextEditingController amountController;
  final FocusNode? amountFocusNode;
  final Denomination selectedDenomination;
  final List<Denomination> availableDenominations;
  final Function(Denomination?) onDenominationChanged;
  final int decimalPlaces;
  final Function(String) onAmountChanged;
  final String? Function(String?)? validator;
  final bool isEnabled;
  final bool isSecured; // Add isSecured parameter to determine border color
  
  const AmountInputSection({
    super.key,
    required this.amountController,
    required this.amountFocusNode,
    required this.selectedDenomination,
    required this.availableDenominations,
    required this.onDenominationChanged,
    required this.decimalPlaces,
    required this.onAmountChanged,
    this.validator,
    this.isEnabled = true,
    this.isSecured = true, // Default to secured
  });
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: amountController,
            focusNode: amountFocusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Amount',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.textSecondary, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: isSecured ? AppColors.primary : AppColors.techAzure, 
                  width: 1
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: isSecured ? AppColors.primary : AppColors.techAzure, 
                  width: 1.5
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d*\.?\d{0,' + decimalPlaces.toString() + '}'),
              ),
            ],
            onChanged: onAmountChanged,
            validator: validator,
            enabled: isEnabled,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButtonFormField<Denomination>(
            value: selectedDenomination,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Denom',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.textSecondary, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: isSecured ? AppColors.primary : AppColors.techAzure, 
                  width: 1
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: isSecured ? AppColors.primary : AppColors.techAzure, 
                  width: 1.5
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            items: availableDenominations.map((denomination) {
              return DropdownMenuItem(
                value: denomination,
                child: Text(
                  denomination.toString().split('.').last,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              );
            }).toList(),
            onChanged: isEnabled ? onDenominationChanged : null,
          ),
        ),
      ],
    );
  }
}

/// Widget for amount input section with daily limit display
class AmountInputCard extends StatelessWidget {
  final TextEditingController amountController;
  final FocusNode amountFocusNode;
  final Denomination selectedDenomination;
  final List<Denomination> availableDenominations;
  final Function(Denomination?) onDenominationChanged;
  final int decimalPlaces;
  final Function(String) onAmountChanged;
  final String? Function(String?)? validator;
  final VoidCallback onUpgradePressed;
  final bool isEnabled;
  final bool showFullContent;
  final bool isSecured; // Add isSecured parameter to determine border color
  final int? memberTier; // Add memberTier parameter to determine whether to show daily limit
  final double? dailyLimit; // Add dailyLimit parameter to show the actual daily limit
  
  const AmountInputCard({
    super.key,
    required this.amountController,
    required this.amountFocusNode,
    required this.selectedDenomination,
    required this.availableDenominations,
    required this.onDenominationChanged,
    required this.decimalPlaces,
    required this.onAmountChanged,
    required this.onUpgradePressed,
    this.validator,
    this.isEnabled = true,
    this.showFullContent = false,
    this.isSecured = true, // Default to secured
    this.memberTier,
    this.dailyLimit,
  });
  
  @override
  Widget build(BuildContext context) {
    // If not showing full content, just show an empty container
    if (!showFullContent) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
      );
    }
    
    // Otherwise show the full content without background, similar to CredexTypeSection
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount and denomination input
              AmountInputSection(
                amountController: amountController,
                amountFocusNode: amountFocusNode,
                selectedDenomination: selectedDenomination,
                availableDenominations: availableDenominations,
                onDenominationChanged: onDenominationChanged,
                decimalPlaces: decimalPlaces,
                onAmountChanged: onAmountChanged,
                validator: validator,
                isEnabled: isEnabled,
                isSecured: isSecured,
              ),
              
              const SizedBox(height: 12),
              
              // Daily limit box has been moved to under the Sign Offer button in send_credex_screen.dart
            ],
        ),
      ),
    );
  }
}
