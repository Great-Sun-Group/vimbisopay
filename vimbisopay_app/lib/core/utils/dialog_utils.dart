import 'package:flutter/material.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/presentation/widgets/setup_password_dialog.dart';

class DialogUtils {
  static void showPasswordSetupIfNeeded(BuildContext context, User user) {
    // Check if this is a phone-only auth that needs password setup
    if (user.version == 'v1' && 
        user.authMethod == 'phone_only' && 
        !user.otpVerified) {
      // Show the password setup dialog
      showDialog(
        context: context,
        barrierDismissible: false, // User must choose an option
        builder: (context) => const SetupPasswordDialog(),
      );
    }
  }
}
