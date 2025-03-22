import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';

class ChangePinDialog extends StatefulWidget {
  const ChangePinDialog({super.key});

  @override
  State<ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<ChangePinDialog> {
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _securityService = ServiceLocator.securityService;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _changePin() async {
    final currentPin = _currentPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    // Validation
    if (currentPin.isEmpty || newPin.isEmpty || confirmPin.isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }

    if (newPin.length != 4) {
      setState(() => _error = 'PIN must be 4 digits');
      return;
    }

    if (newPin != confirmPin) {
      setState(() => _error = 'New PINs do not match');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Verify current PIN
      final isValid = await _securityService.verifyPin(currentPin);
      if (!isValid) {
        setState(() {
          _error = 'Current PIN is incorrect';
          _isLoading = false;
        });
        return;
      }

      // Set new PIN
      await _securityService.setPin(newPin);
      
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      Logger.error('Error changing PIN', e);
      if (mounted) {
        setState(() {
          _error = 'Failed to change PIN. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Change PIN',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: _isLoading
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                SizedBox(height: 16),
                Text(
                  'Changing PIN...',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _currentPinController,
                  decoration: const InputDecoration(
                    labelText: 'Current PIN',
                    hintText: '****',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newPinController,
                  decoration: const InputDecoration(
                    labelText: 'New PIN',
                    hintText: '****',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPinController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New PIN',
                    hintText: '****',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _changePin(),
                ),
              ],
            ),
      actions: _isLoading
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: _changePin,
                child: const Text(
                  'Change PIN',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
    );
  }
}
