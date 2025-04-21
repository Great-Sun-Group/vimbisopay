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
                borderSide: const BorderSide(color: AppColors.textSecondary, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.techAzure, width: 1.5),
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
                borderSide: const BorderSide(color: AppColors.textSecondary, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.techAzure, width: 1.5),
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
  });
  
  @override
  Widget build(BuildContext context) {
    final denom = selectedDenomination.toString().split('.').last;
    
    // If not showing full content, just show an empty card with title
    if (!showFullContent) {
      return StyledCard.gold(
        title: '3. Amount',
        child: Container(
          height: 10,
        ),
      );
    }
    
    // Otherwise show the full card content
    return StyledCard.gold(
      title: '3. Amount',
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
            ),
            
            const SizedBox(height: 12),
            
            // Daily Limit display with gold border
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.yellowMain, // Gold color
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Daily Limit:",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        "10.0 $denom",
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onUpgradePressed,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "Upgrade",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
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
      ),
    );
  }
}
