import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class IntroScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const IntroScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildPage({
    required Color color,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      color: color,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: Colors.white),
          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // PageView
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              // When user reaches the last page, show a button to complete
              if (index == 2) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  widget.onComplete();
                });
              }
            },
            children: [
              _buildPage(
                color: Colors.blue,
                title: 'Send Money',
                description: 'Transfer money to friends and family with ease',
                icon: Icons.send,
              ),
              _buildPage(
                color: Colors.green,
                title: 'Secure Payments',
                description: 'Your transactions are protected with advanced security',
                icon: Icons.security,
              ),
              _buildPage(
                color: Colors.purple,
                title: 'Track Expenses',
                description: 'Keep track of your spending with detailed analytics',
                icon: Icons.analytics,
              ),
            ],
          ),
          // Page Indicator
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _pageController,
                count: 3,
                effect: const WormEffect(
                  dotHeight: 10,
                  dotWidth: 10,
                  spacing: 16,
                  dotColor: Colors.grey,
                  activeDotColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
