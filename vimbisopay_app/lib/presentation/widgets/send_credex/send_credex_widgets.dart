import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/denomination.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;

/// Widget to display status messages
class StatusMessageWidget extends StatelessWidget {
  final String? message;
  
  const StatusMessageWidget({
    super.key,
    this.message,
  });
  
  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.primary, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget to display error messages
class ErrorMessageWidget extends StatelessWidget {
  final String? message;
  
  const ErrorMessageWidget({
    super.key,
    this.message,
  });
  
  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.error, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
  final bool isVerifying;
  final VoidCallback onVerify;
  final VoidCallback onScanQR;
  final String? Function(String?)? validator;
  
  const RecipientInputSection({
    super.key,
    required this.recipientController,
    required this.isVerifying,
    required this.onVerify,
    required this.onScanQR,
    this.validator,
  });
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: recipientController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: '💳 Handle',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              hintText: 'Recipient account',
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
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: recipientController,
          builder: (context, value, child) {
            return ElevatedButton(
              onPressed: value.text.isEmpty || isVerifying ? null : onVerify,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text('Verify'),
            );
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onScanQR,
          icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
          tooltip: 'Scan QR Code',
        ),
      ],
    );
  }
}

/// Widget to display verified recipient information
class VerifiedRecipientCard extends StatelessWidget {
  final Map<String, dynamic> accountDetails;
  final VoidCallback onChangeRecipient;
  
  const VerifiedRecipientCard({
    super.key,
    required this.accountDetails,
    required this.onChangeRecipient,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'To',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: onChangeRecipient,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '💳 ${accountDetails['accountName']}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '💳 ${accountDetails['accountHandle']}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget to display sender account information
class SenderAccountCard extends StatelessWidget {
  final dashboard.DashboardAccount account;
  final Denomination selectedDenomination;
  final double availableBalance;
  
  const SenderAccountCard({
    super.key,
    required this.account,
    required this.selectedDenomination,
    required this.availableBalance,
  });
  
  @override
  Widget build(BuildContext context) {
    final denom = selectedDenomination.toString().split('.').last;
    
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'From',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '💳 ${account.accountName}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '💳 ${account.accountHandle}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Secured Balances:',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$availableBalance $denom',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget for the submit button
class SubmitButton extends StatelessWidget {
  final bool isLoading;
  final bool isEnabled;
  final VoidCallback onPressed;
  
  const SubmitButton({
    super.key,
    required this.isLoading,
    required this.isEnabled,
    required this.onPressed,
  });
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isEnabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
              ),
            )
          : const Text(
              'Sign Offer',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}

/// Widget to display transaction details in a row
class TransactionDetailRow extends StatelessWidget {
  final String label;
  final String value;
  
  const TransactionDetailRow({
    super.key,
    required this.label,
    required this.value,
  });
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
