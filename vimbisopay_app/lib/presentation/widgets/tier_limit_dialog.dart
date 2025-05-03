import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_event.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_state.dart';

class TierLimitDialog extends StatefulWidget {
  final String message; // Kept for backward compatibility
  final String accountId;
  final HomeBloc homeBloc;
  final double? remainingDailyLimit; // Added parameter for remaining daily limit
  final String? denomination; // Added parameter for denomination

  const TierLimitDialog({
    super.key,
    required this.message,
    required this.accountId,
    required this.homeBloc,
    this.remainingDailyLimit, // Optional parameter
    this.denomination, // Optional parameter
  });

  @override
  State<TierLimitDialog> createState() => _TierLimitDialogState();
}

class _TierLimitDialogState extends State<TierLimitDialog> {
  bool _isUpgrading = false;
  bool _isCompleted = false;
  String? _errorMessage;
  
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
            // Display Free Tier and remaining daily limit if provided
            if (widget.remainingDailyLimit != null && widget.denomination != null) ...[
              const Text(
                "Free Tier",
                style: TextStyle(
                  color: AppColors.darkRed,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Remaining Daily Limit:",
                style: TextStyle(
                  color: AppColors.darkRed,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${widget.remainingDailyLimit!.toStringAsFixed(2)} ${widget.denomination}",
                style: const TextStyle(
                  color: AppColors.darkRed,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            const Icon(
              Icons.star,
              color: AppColors.primary,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Hustler Tier',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            const Text(
              'Upgrade to the Hustler tier for \$1/month and get unlimited transactions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The first 10,000 Hustlers get a full year for \$1.00 USD',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            BlocListener<HomeBloc, HomeState>(
              bloc: widget.homeBloc,
              listener: (context, state) {
                if (state.isUpgradingTier) {
                  setState(() {
                    _isUpgrading = true;
                    _errorMessage = null;
                  });
                } else if (state.hasError && _isUpgrading) {
                  setState(() {
                    _isUpgrading = false;
                    _isCompleted = true;
                    _errorMessage = state.error;
                  });
                } else if (state.message != null && 
                           state.message!.contains('Tier upgrade successful') && 
                           _isUpgrading) {
                  setState(() {
                    _isUpgrading = false;
                    _isCompleted = true;
                    _errorMessage = null;
                  });
                }
              },
              child: _isCompleted
                  ? _buildCompletionView()
                  : _buildActionButtons(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isUpgrading) {
      return const Column(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          SizedBox(height: 16),
          Text(
            'Processing your upgrade...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text('Maybe Later'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  // Don't pop the dialog immediately
                  setState(() {
                    _isUpgrading = true;
                  });
                  widget.homeBloc.add(HomeUpgradeTierStarted(widget.accountId));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Upgrade Now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          '\$1 USD payment will be made automatically from your secured balance',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.green,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionView() {
    final bool isSuccess = _errorMessage == null;
    
    return Column(
      children: [
        Icon(
          isSuccess ? Icons.check_circle : Icons.error,
          color: isSuccess ? Colors.green : Colors.red,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          isSuccess ? 'Upgrade Successful!' : 'Upgrade Failed',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isSuccess 
              ? 'Your account has been upgraded to Hustler tier.'
              : _errorMessage ?? 'An error occurred during the upgrade process.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            // Close the dialog and navigate back to account dashboard
            Navigator.of(context).pop();
            
            // If we're in the send_credex screen, pop back to the dashboard
            if (ModalRoute.of(context)?.settings.name == '/send-credex') {
              Navigator.of(context).pop();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textPrimary,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text(
            'Back to Dashboard',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
