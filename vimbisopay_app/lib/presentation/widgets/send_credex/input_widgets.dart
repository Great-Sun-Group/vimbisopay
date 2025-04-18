import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/denomination.dart';

/// Widget for amount input and denomination selection
class AmountInputSection extends StatelessWidget {
  final TextEditingController amountController;
  final FocusNode amountFocusNode;
  final Denomination selectedDenomination;
  final List<Denomination> availableDenominations;
  final Function(Denomination?) onDenominationChanged;
  final int decimalPlaces;
  final Function(String) onAmountChanged;
  final String? Function(String?)? validator;
  
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
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
            onChanged: onDenominationChanged,
          ),
        ),
      ],
    );
  }
}

/// Widget for recipient input and verification
class RecipientInputSection extends StatelessWidget {
  final TextEditingController recipientController;
  final FocusNode? focusNode;
  final bool isVerifying;
  final VoidCallback onVerify;
  final VoidCallback onScanQR;
  final String? Function(String?)? validator;
  
  const RecipientInputSection({
    super.key,
    required this.recipientController,
    this.focusNode,
    required this.isVerifying,
    required this.onVerify,
    required this.onScanQR,
    this.validator,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Handle input field - full width
        TextFormField(
          controller: recipientController,
          focusNode: focusNode,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: '💳 Handle',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            hintText: 'Send to what account?',
            hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
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
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            suffixIcon: isVerifying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  )
                : null,
          ),
          validator: validator,
        ),
        
        const SizedBox(height: 12),
        
        // When verifying, don't show any buttons or helper text
        if (isVerifying) ...[
          // Empty space to maintain layout
          const SizedBox(height: 24),
        ] else ...[
          // Helper text - only visible when not verifying
          const Text(
            'Enter handle or scan QR code',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Action buttons row
          Row(
            children: [
              // Verify button
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: recipientController,
                  builder: (context, value, child) {
                    return ElevatedButton(
                      onPressed: value.text.isEmpty ? null : onVerify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text('Verify Handle'),
                    );
                  },
                ),
              ),
              
              const SizedBox(width: 12),
              
              // QR Scan button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onScanQR,
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Scan QR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Widget to wrap RecipientInputSection in a card with border
class RecipientInputCard extends StatelessWidget {
  final TextEditingController recipientController;
  final FocusNode? focusNode;
  final bool isVerifying;
  final VoidCallback onVerify;
  final VoidCallback onScanQR;
  final String? Function(String?)? validator;
  
  const RecipientInputCard({
    super.key,
    required this.recipientController,
    this.focusNode,
    required this.isVerifying,
    required this.onVerify,
    required this.onScanQR,
    this.validator,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'To Account:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            RecipientInputSection(
              recipientController: recipientController,
              focusNode: focusNode,
              isVerifying: isVerifying,
              onVerify: onVerify,
              onScanQR: onScanQR,
              validator: validator,
            ),
          ],
        ),
      ),
    );
  }
}
