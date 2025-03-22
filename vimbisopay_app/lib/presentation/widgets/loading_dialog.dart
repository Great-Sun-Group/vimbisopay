import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:lottie/lottie.dart';

class LoadingDialog extends StatefulWidget {
  final String message;
  final Stream<String>? messageStream;

  const LoadingDialog({
    super.key,
    required this.message,
    this.messageStream,
  });

  @override
  State<LoadingDialog> createState() => _LoadingDialogState();
}

class _LoadingDialogState extends State<LoadingDialog> with SingleTickerProviderStateMixin {
  late String _currentMessage;
  StreamSubscription<String>? _messageSubscription;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _currentMessage = widget.message;
    
    // Initialize animation controller with half the normal duration for 2x speed
    _animationController = AnimationController(
      vsync: this,
      // The animation has 162 frames at 60fps (about 2.7 seconds)
      // For 2x speed, we use half that duration
      duration: const Duration(milliseconds: 1350),
    );
    
    // Start the animation and make it repeat
    _animationController.repeat();
    
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
    _animationController.dispose();
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
            Lottie.asset(
              'assets/animations/loading_anim.json',
              width: 90,
              height: 90,
              fit: BoxFit.contain,
              controller: _animationController,
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
