import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LoadingAnimation extends StatelessWidget {
  final double size;
  
  const LoadingAnimation({
    super.key,
    this.size = 600,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Lottie.asset(
          'assets/animations/loading.json',
          repeat: true,
          animate: true,
        ),
      ),
    );
  }
}

// Example usage:
// LoadingAnimation(size: 100) // For a smaller animation
// LoadingAnimation() // For default size
