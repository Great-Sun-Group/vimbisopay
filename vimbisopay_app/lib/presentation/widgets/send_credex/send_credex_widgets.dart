import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/denomination.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;
import 'package:vimbisopay_app/presentation/blocs/send_credex/send_credex_state.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/profile_bar_graph_widget.dart';

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
  final FocusNode? focusNode; // Add focus node parameter
  final bool isVerifying;
  final VoidCallback onVerify;
  final VoidCallback onScanQR;
  final String? Function(String?)? validator;
  
  const RecipientInputSection({
    super.key,
    required this.recipientController,
    this.focusNode, // Make it optional
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
          focusNode: focusNode, // Use the focus node
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

/// Widget to display verified recipient information
class VerifiedRecipientCard extends StatelessWidget {
  final Map<String, dynamic> accountDetails;
  final VoidCallback onChangeRecipient;
  final CredexType? credexType;
  final String? profileImageUrl;
  final String? memberName; // Added for member name
  final bool isVerifying; // Add isVerifying parameter
  
  const VerifiedRecipientCard({
    super.key,
    required this.accountDetails,
    required this.onChangeRecipient,
    this.credexType,
    this.profileImageUrl,
    this.memberName,
    this.isVerifying = false, // Default to false
  });
  
  // Helper property for backward compatibility
  bool get isSecuredCredex => credexType == CredexType.SECURED;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(
          color: AppColors.primary,
          width: 1,
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Account name and handle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                
                // Right side - Empty for Secured/Neutral, Profile Pic for Unsecured
                Expanded(
                  child: credexType == null || credexType == CredexType.NEUTRAL || credexType == CredexType.SECURED
                    ? const SizedBox() // Empty for neutral or secured state
                    : Container(
                        alignment: Alignment.centerRight,
                        child: ProfileWithBarGraph.davidzo(
                          profileImageUrl: profileImageUrl,
                        ),
                      ),
                ),
              ],
            ),
            // Only show Change button if not verifying
            if (!isVerifying) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
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
              ),
            ],
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
  final CredexType? credexType;
  final String? profileImageUrl;
  final String? memberName;
  
  const SenderAccountCard({
    super.key,
    required this.account,
    required this.selectedDenomination,
    required this.availableBalance,
    this.credexType,
    this.profileImageUrl,
    this.memberName,
  });
  
  // Helper property for backward compatibility
  bool get isSecuredCredex => credexType == CredexType.SECURED;
  
  @override
  Widget build(BuildContext context) {
    final denom = selectedDenomination.toString().split('.').last;
    
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(
          color: AppColors.primary,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'From Account:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Account name and handle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                    ],
                  ),
                ),
                
                // Right side - Secured Balances, Profile Pic, or Empty (neutral)
                Expanded(
                  child: credexType == null || credexType == CredexType.NEUTRAL
                    ? const SizedBox() // Empty for neutral state
                    : credexType == CredexType.SECURED
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
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
                        )
                      : Container(
                          alignment: Alignment.centerRight,
                          child: memberName != null
                              ? ProfileWithBarGraph.currentUser(
                                  profileImageUrl: profileImageUrl,
                                  firstName: memberName?.split(' ').first ?? '',
                                  lastName: (memberName?.split(' ').length ?? 0) > 1 
                                      ? memberName?.split(' ').last ?? '' 
                                      : '',
                                )
                              : Text(
                                  account.accountName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
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

/// Widget to display member profile information
class ProfileInfoWidget extends StatelessWidget {
  final String? profileImageUrl;
  final String firstName;
  final String lastName;
  
  const ProfileInfoWidget({
    super.key,
    this.profileImageUrl,
    required this.firstName,
    required this.lastName,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Profile image
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(
              color: AppColors.secondary,
              width: 2,
            ),
            image: null,
          ),
          child: const Icon(
            Icons.person,
            size: 40,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 8),
        // First name
        Text(
          firstName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        // Last name
        Text(
          lastName,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

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
          color: isSelected ? AppColors.secondary : AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? AppColors.secondary : AppColors.textSecondary,
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

/// Widget for due date selection
class DueDateSelector extends StatelessWidget {
  final DateTime? selectedDate;
  final Function(DateTime?) onDateChanged;
  
  const DueDateSelector({
    super.key,
    this.selectedDate,
    required this.onDateChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Due Date (Optional)',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _selectDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.textSecondary,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selectedDate != null
                        ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                        : 'Select a due date',
                    style: TextStyle(
                      color: selectedDate != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary.withOpacity(0.5),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (selectedDate != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => onDateChanged(null),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear'),
              ),
            ),
        ],
      ),
    );
  }
  
  Future<void> _selectDate(BuildContext context) async {
    // Get tomorrow's date (to prevent selecting today or past dates)
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    // Get 4 weeks from today as the default initial date
    final DateTime fourWeeksFromNow = DateTime.now().add(const Duration(days: 28));
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? fourWeeksFromNow,
      firstDate: tomorrow,
      lastDate: DateTime(2100),
    );
    
    if (picked != null && picked != selectedDate) {
      onDateChanged(picked);
    }
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
