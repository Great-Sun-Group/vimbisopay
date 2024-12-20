import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';

class SwipeableTransactionCard extends StatefulWidget {
  final PendingOffer offer;
  final bool isProcessing;
  final bool isCancelling;
  final VoidCallback onCancel;
  final Widget child;

  const SwipeableTransactionCard({
    super.key,
    required this.offer,
    required this.isProcessing,
    required this.isCancelling,
    required this.onCancel,
    required this.child,
  });

  @override
  State<SwipeableTransactionCard> createState() => _SwipeableTransactionCardState();
}

class _SwipeableTransactionCardState extends State<SwipeableTransactionCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.3, 0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (details.primaryDelta! > 0) { // Only allow right swipe
      final percent = details.primaryDelta! / context.size!.width;
      _controller.value = (_controller.value + percent).clamp(0.0, 0.3);
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_controller.value >= 0.15) {
      _controller.animateTo(0.3);
      setState(() => _isOpen = true);
    } else {
      _controller.animateTo(0.0);
      setState(() => _isOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            // Background with cancel button
            Positioned.fill(
              child: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20.0),
                color: AppColors.error,
                child: ElevatedButton.icon(
                  onPressed: (widget.isCancelling || widget.isProcessing)
                      ? null
                      : widget.onCancel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  icon: const Icon(
                    Icons.cancel,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            // Animated card
            GestureDetector(
              onHorizontalDragUpdate: _handleDragUpdate,
              onHorizontalDragEnd: _handleDragEnd,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) => SlideTransition(
                  position: _animation,
                  child: child,
                ),
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
