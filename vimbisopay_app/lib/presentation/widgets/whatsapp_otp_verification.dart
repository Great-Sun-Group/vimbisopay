import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/otp_utils.dart';
import 'package:vimbisopay_app/core/utils/error_translator.dart';
import 'package:vimbisopay_app/core/utils/deep_link_handler.dart';
import 'package:vimbisopay_app/core/config/api_config.dart';
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
  final bool isAccountCreation; // Flag to indicate if this is for account creation
  final Function(User) onVerificationComplete;

  const WhatsAppOTPVerification({
    super.key,
    required this.token,
    required this.phone,
    required this.memberId,
    required this.onVerificationComplete,
    this.user,
    this.isAccountCreation = false,
  });

  @override
  State<WhatsAppOTPVerification> createState() => _WhatsAppOTPVerificationState();
}

class _WhatsAppOTPVerificationState extends State<WhatsAppOTPVerification> {
  final _repository = ServiceLocator.accountRepository;
  bool _isLoading = true;
  bool _isGeneratingOTP = false;
  bool _isCheckingStatus = false;
  bool _otpSent = false;
  String? _otp;
  String? _error;
  bool _verificationComplete = false;
  String? _verificationToken;
  int? _tokenExpiresIn;
  
  @override
  void initState() {
    super.initState();
    
    // Register verification callback with DeepLinkHandler
    DeepLinkHandler.registerVerificationCallback(_handleDeepLinkVerification);
    
    // Schedule OTP generation after the widget is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _generateAndStoreOTP();
      }
    });
  }
  
  @override
  void dispose() {
    // Unregister verification callback when widget is disposed
    DeepLinkHandler.unregisterVerificationCallback();
    super.dispose();
  }
  
  /// Handle verification deep link
  void _handleDeepLinkVerification(String phone) {
    Logger.data('[WhatsAppOTPVerification] Received verification deep link for phone: $phone');
    
    // Check if the phone number matches
    if (phone == widget.phone) {
      // Check verification status
      _checkVerificationStatus();
    } else {
      Logger.data('[WhatsAppOTPVerification] Phone number mismatch: $phone != ${widget.phone}');
    }
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
          builder: (context) => const LoadingDialog(
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
        (data) {
          setState(() {
            _otp = otp;
            _verificationToken = data['verificationToken'] as String?;
            _tokenExpiresIn = data['expiresIn'] as int?;
            _isGeneratingOTP = false;
            _isLoading = false;
          });
          
          Logger.data('[WhatsAppOTPVerification] OTP stored with token: ${_verificationToken != null ? '[REDACTED]' : 'null'}, expires in: $_tokenExpiresIn seconds');
        },
      );
    } catch (e) {
      // Log the error
      Logger.error('[WhatsAppOTPVerification] Error generating OTP', e);
      
      // Safely handle dialog dismissal using a post-frame callback
      if (mounted) {
        // First update the state
        setState(() {
          _error = ErrorTranslator.translateError(e);
          _isGeneratingOTP = false;
          _isLoading = false;
        });
        
        // Then schedule dialog dismissal after the current frame is complete
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Check if there's a dialog to dismiss
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
      }
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
  
  /// Checks if the OTP has been verified
  Future<void> _checkVerificationStatus() async {
    if (_isCheckingStatus) return;
    
    setState(() {
      _isCheckingStatus = true;
      _error = null;
    });
    
    try {
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const LoadingDialog(
            message: 'Checking verification status...',
          ),
        );
      }
      
      // Check OTP verification status
      final result = await _repository.checkOtpVerificationStatus(
        phone: widget.phone,
      );
      
      // Dismiss loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      result.fold(
        (failure) {
          setState(() {
            _error = failure.message ?? ErrorTranslator.translateError(failure);
            _isCheckingStatus = false;
          });
        },
        (status) {
          // Explicitly cast status to VerificationStatus
          final verificationStatus = status;
          setState(() {
            _verificationComplete = verificationStatus.verified;
            _isCheckingStatus = false;
          });
          
          if (verificationStatus.verified) {
            // Call the completion callback with either the provided user or a placeholder
            // This ensures the flow continues even in password reset where user might be null
            if (widget.user != null) {
              widget.onVerificationComplete(widget.user!);
            } else {
              // For password reset flow, create a minimal User with just the memberId
              // and the verification token that we received during OTP storage
              final tempUser = User(
                memberId: widget.memberId,
                phone: widget.phone,
                token: _verificationToken ?? widget.token, // Use the stored token from initial OTP storage
              );
              
              Logger.data('[WhatsAppOTPVerification] Verification complete with stored token: ${_verificationToken != null ? '[REDACTED]' : 'null'}');
              widget.onVerificationComplete(tempUser);
            }
            
            // Close the dialog after a short delay to show the success state
            if (mounted) {
              Future.delayed(const Duration(milliseconds: 1500), () {
                if (mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              });
            }
          }
        },
      );
    } catch (e) {
      // Log the error
      Logger.error('[WhatsAppOTPVerification] Error checking verification status', e);
      
      // Safely handle dialog dismissal using a post-frame callback
      if (mounted) {
        // First update the state
        setState(() {
          _error = ErrorTranslator.translateError(e);
          _isCheckingStatus = false;
        });
        
        // Then schedule dialog dismissal after the current frame is complete
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Check if there's a dialog to dismiss
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
      }
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
                    
                    // Development mode indicator
                    if (ApiConfig.isDevelopment)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.developer_mode,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Development Mode: Use OTP 123456',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
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
                          Text(
                            ApiConfig.isDevelopment ? 'Development Verification:' : 'Verification Steps:',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (ApiConfig.isDevelopment) ...[
                            _buildInstructionStep(
                              1,
                              'Use the fixed development OTP: 123456',
                              false,
                            ),
                            _buildInstructionStep(
                              2,
                              'No WhatsApp verification needed in dev mode',
                              false,
                            ),
                          ] else ...[
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
                            Text(
                              ApiConfig.isDevelopment 
                                ? 'Development verification code:'
                                : 'Your verification code:',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ApiConfig.isDevelopment ? '123456' : _otp!,
                              style: TextStyle(
                                color: ApiConfig.isDevelopment ? Colors.orange : AppColors.primary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ApiConfig.isDevelopment
                                ? 'Use this fixed code for development verification.'
                                : 'This code will be automatically included in your WhatsApp message.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    
                    if (_otpSent) const SizedBox(height: 16),
                    
                    // Check verification status button
                    if (_otpSent && !_verificationComplete)
                      FilledButton.icon(
                        onPressed: _isCheckingStatus ? null : _checkVerificationStatus,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          _isCheckingStatus ? 'Checking...' : 'Check Verification Status',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    
                    if (_otpSent && !_verificationComplete) const SizedBox(height: 16),
                    
                    // Regenerate OTP button
                    if (_otpSent && !_verificationComplete)
                      TextButton.icon(
                        onPressed: _isGeneratingOTP ? null : _generateAndStoreOTP,
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          _isGeneratingOTP ? 'Generating...' : 'Generate New Code',
                        ),
                      ),
                      
                    // Success message
                    if (_verificationComplete)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.success.withOpacity(0.3),
                          ),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                              size: 48,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Verification Successful!',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Your phone number has been verified. You can now continue with the process.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
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
