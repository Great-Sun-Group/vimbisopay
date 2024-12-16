import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';

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
      color: AppColors.background,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: color),
          const SizedBox(height: 32),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
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
      backgroundColor: AppColors.background,
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
                color: AppColors.primary,
                title: 'Send Money',
                description: 'Transfer money to friends and family with ease',
                icon: Icons.send,
              ),
              _buildPage(
                color: AppColors.secondary,
                title: 'Secure Payments',
                description: 'Your transactions are protected with advanced security',
                icon: Icons.security,
              ),
              _buildPage(
                color: AppColors.accent,
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
                effect: WormEffect(
                  dotHeight: 10,
                  dotWidth: 10,
                  spacing: 16,
                  dotColor: AppColors.surface,
                  activeDotColor: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
