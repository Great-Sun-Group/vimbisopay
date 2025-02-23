import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';

class ChangePinBottomSheet extends StatefulWidget {
  final bool isChangingPin;

  const ChangePinBottomSheet({
    super.key,
    required this.isChangingPin,
  });

  @override
  State<ChangePinBottomSheet> createState() => _ChangePinBottomSheetState();
}

class _ChangePinBottomSheetState extends State<ChangePinBottomSheet> {
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

  Future<void> _handlePinAction() async {
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();
    final currentPin = _currentPinController.text.trim();

    // Validation
    if (widget.isChangingPin && currentPin.isEmpty) {
      setState(() => _error = 'Current PIN is required');
      return;
    }

    if (newPin.isEmpty || confirmPin.isEmpty) {
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

      // If changing PIN, verify current PIN first
      if (widget.isChangingPin) {
        final isValid = await _securityService.verifyPin(currentPin);
        if (!isValid) {
          setState(() {
            _error = 'Current PIN is incorrect';
            _isLoading = false;
          });
          return;
        }
      }

      // Set PIN
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
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          Text(
            widget.isChangingPin ? 'Change PIN' : 'Set PIN',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          if (_isLoading)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.isChangingPin ? 'Changing PIN...' : 'Setting PIN...',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(top: 8, bottom: 16),
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
                if (widget.isChangingPin) ...[
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
                ],
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
                  onSubmitted: (_) => _handlePinAction(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _handlePinAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    widget.isChangingPin ? 'Change PIN' : 'Set PIN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
