import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/otp_utils.dart';
import 'package:vimbisopay_app/core/utils/error_translator.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart';

/// A widget that handles WhatsApp OTP verification flow
///
/// This widget generates an OTP, stores it in Credex Core, and provides
/// a button to open WhatsApp with a pre-populated verification message.
class WhatsAppOTPVerification extends StatefulWidget {
  final String token;
  final String phone;
  final String memberId;
  final User? user; // Optional user object for v2 flow
  final String? password; // Optional password for v1->v2 migration
  final bool isAccountCreation; // Flag to indicate if this is for account creation
  final Function(User) onVerificationComplete;

  const WhatsAppOTPVerification({
    super.key,
    required this.token,
    required this.phone,
    required this.memberId,
    required this.onVerificationComplete,
    this.user,
    this.password,
    this.isAccountCreation = false,
  });

  @override
  State<WhatsAppOTPVerification> createState() => _WhatsAppOTPVerificationState();
}

class _WhatsAppOTPVerificationState extends State<WhatsAppOTPVerification> {
  final _repository = ServiceLocator.accountRepository;
  bool _isLoading = true;
  bool _isGeneratingOTP = false;
  bool _otpSent = false;
  String? _otp;
  String? _error;
  bool _verificationComplete = false;
  
  @override
  void initState() {
    super.initState();
    _generateAndStoreOTP();
  }
  
  /// Generates an OTP and stores it in Credex Core
  Future<void> _generateAndStoreOTP() async {
    if (_isGeneratingOTP) return;
    
    setState(() {
      _isGeneratingOTP = true;
      _error = null;
    });
    
    try {
      // Generate a random 6-digit OTP
      final otp = OTPUtils.generateOTP();
      
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => LoadingDialog(
            message: 'Preparing verification...',
          ),
        );
      }
      
      // Store OTP in Credex Core
      final result = await _repository.storeOtp(
        memberId: widget.memberId,
        phone: widget.phone,
        otp: otp,
        purpose: 'PASSWORD_RESET',
      );
      
      // Dismiss loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      result.fold(
        (failure) {
          setState(() {
            _error = failure.message ?? ErrorTranslator.translateError(failure);
            _isGeneratingOTP = false;
            _isLoading = false;
          });
        },
        (_) {
          setState(() {
            _otp = otp;
            _isGeneratingOTP = false;
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      // Dismiss loading dialog if it's showing
      if (mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      }
      
      setState(() {
        _error = ErrorTranslator.translateError(e);
        _isGeneratingOTP = false;
        _isLoading = false;
      });
    }
  }
  
  /// Opens WhatsApp with the OTP
  Future<void> _openWhatsApp() async {
    if (_otp == null) return;
    
    try {
      final success = await OTPUtils.openWhatsAppWithOTP(_otp!);
      
      if (success) {
        setState(() {
          _otpSent = true;
        });
      } else {
        setState(() {
          _error = 'Could not open WhatsApp. Please make sure WhatsApp is installed.';
        });
      }
    } catch (e) {
      setState(() {
        _error = ErrorTranslator.translateError(e);
      });
    }
  }
  
  /// Starts the verification polling process
  Future<void> _startVerificationPolling() async {
    // TODO: Implement polling for verification status
    // This would periodically check if the OTP has been verified
    // For now, we'll just rely on the user returning to the app after verification
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      title: const Text(
        'WhatsApp Verification',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Preparing verification...',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
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
                          overflow: TextOverflow.visible,
                          softWrap: true,
                        ),
                      ),
                    if (_error != null) const SizedBox(height: 16),
                    
                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.info.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Verification Steps:',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildInstructionStep(
                            1,
                            'Tap the "Open WhatsApp" button below',
                            _otpSent,
                          ),
                          _buildInstructionStep(
                            2,
                            'Send the pre-filled message to the Vimbiso chatbot',
                            _otpSent,
                          ),
                          _buildInstructionStep(
                            3,
                            'Wait for confirmation in WhatsApp',
                            _verificationComplete,
                          ),
                          _buildInstructionStep(
                            4,
                            'Return to this app to complete the process',
                            _verificationComplete,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // WhatsApp button
                    FilledButton.icon(
                      onPressed: _otp == null || _isGeneratingOTP ? null : _openWhatsApp,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366), // WhatsApp green
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.send),
                      label: Text(
                        _otpSent ? 'Open WhatsApp Again' : 'Open WhatsApp',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // OTP display
                    if (_otp != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Your verification code:',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _otp!,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'This code will be automatically included in your WhatsApp message.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    
                    if (_otpSent) const SizedBox(height: 16),
                    
                    // Regenerate OTP button
                    if (_otpSent && !_verificationComplete)
                      TextButton.icon(
                        onPressed: _isGeneratingOTP ? null : _generateAndStoreOTP,
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          _isGeneratingOTP ? 'Generating...' : 'Generate New Code',
                        ),
                      ),
                  ],
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildInstructionStep(int number, String text, bool completed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: completed ? AppColors.success : AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: completed
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : Text(
                      number.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: completed ? AppColors.textSecondary : AppColors.textPrimary,
                fontSize: 14,
                height: 1.4,
                decoration: completed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
