import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';

class LoadingDialog extends StatefulWidget {
  final AnimationController spinController;
  final String message;
  final Stream<String>? messageStream;

  const LoadingDialog({
    super.key,
    required this.spinController,
    required this.message,
    this.messageStream,
  });

  @override
  State<LoadingDialog> createState() => _LoadingDialogState();
}

class _LoadingDialogState extends State<LoadingDialog> {
  late String _currentMessage;
  StreamSubscription<String>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _currentMessage = widget.message;
    if (widget.messageStream != null) {
      _messageSubscription = widget.messageStream!.listen((message) {
        if (mounted) {
          setState(() {
            _currentMessage = message;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: widget.spinController,
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
                _currentMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
