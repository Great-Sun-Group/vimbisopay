import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/pin_validator.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/screens/forgot_pin_screen.dart';

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

    try {
      // Validation
      if (widget.isChangingPin && currentPin.isEmpty) {
        setState(() => _error = 'Current PIN is required');
        return;
      }

      if (newPin.isEmpty || confirmPin.isEmpty) {
        setState(() => _error = 'All fields are required');
        return;
      }

      // Validate PIN format and security requirements
      final pinError = PinValidator.validatePin(newPin);
      if (pinError != null) {
        setState(() => _error = pinError);
        return;
      }

      if (newPin != confirmPin) {
        setState(() => _error = 'New PINs do not match');
        return;
      }

      setState(() {
        _isLoading = true;
        _error = null;
      });

      // If changing PIN, verify current PIN first
      if (widget.isChangingPin) {
        try {
          final isValid = await _securityService.verifyPin(currentPin);
          if (!isValid) {
            setState(() {
              _error = 'Current PIN is incorrect';
              _isLoading = false;
            });
            return;
          }
        } catch (e) {
          if (e.toString().contains('Too many failed attempts')) {
            setState(() {
              _error = e.toString();
              _isLoading = false;
            });
            return;
          }
          rethrow;
        }
      }

      // Set PIN
      try {
        await _securityService.setPin(newPin);
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (e.toString().contains('has been used recently')) {
          setState(() {
            _error = e.toString();
            _isLoading = false;
          });
          return;
        }
        rethrow;
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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.isChangingPin ? 'Change PIN' : 'Set PIN',
                    style: const TextStyle(
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
                      Material(
                        elevation: 1,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          margin: const EdgeInsets.only(top: 8, bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.error.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFB71C1C), // Darker red for better contrast
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (widget.isChangingPin) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _currentPinController,
                            decoration: const InputDecoration(
                              labelText: 'Current PIN',
                              hintText: '****',
                              helperText: 'Enter your current PIN',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            obscureText: true,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading 
                                  ? null 
                                  : () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const ForgotPINScreen(),
                                        ),
                                      );
                                    },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              child: const Text(
                                'Forgot PIN?',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ],
                    TextField(
                      controller: _newPinController,
                      decoration: InputDecoration(
                        labelText: 'New PIN',
                        hintText: '****',
                        helperText: PinValidator.getRequirementsText(),
                        helperMaxLines: 4,
                        helperStyle: const TextStyle(fontSize: 12),
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
                        helperText: 'Re-enter your new PIN',
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
        ),
      ),
    );
  }
}
