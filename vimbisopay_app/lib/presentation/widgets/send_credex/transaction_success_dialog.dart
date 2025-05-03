import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lottie/lottie.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_event.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/common/action_button.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/common/styled_card.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/utils/date_formatter.dart';

class TransactionSuccessDialog extends StatefulWidget {
  final CredexResponse response;
  final String amount;
  final String denomination;
  final HomeBloc homeBloc;
  
  const TransactionSuccessDialog({
    super.key,
    required this.response,
    required this.amount,
    required this.denomination,
    required this.homeBloc,
  });
  
  @override
  State<TransactionSuccessDialog> createState() => _TransactionSuccessDialogState();
}

class _TransactionSuccessDialogState extends State<TransactionSuccessDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _lottieController;
  late final AudioPlayer _audioPlayer;
  
  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _lottieController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Debug print the response details
    print('Response details: ${widget.response.data.action.details.toString()}');
    print('Due date from response: ${widget.response.data.action.details.dueDate}');
    
    // Play success sound and trigger haptic feedback
    Future.microtask(() async {
      HapticFeedback.mediumImpact();
      await _audioPlayer.play(AssetSource('audio/success.mp3'));
      await _audioPlayer.setVolume(0.5);
    });
  }
  
  @override
  void dispose() {
    _lottieController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Lottie.asset(
                  'assets/animations/success.json',
                  controller: _lottieController,
                  onLoaded: (composition) {
                    _lottieController.duration = composition.duration;
                    _lottieController.forward();
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Text(
                  widget.response.data.action.details.securedCredex 
                    ? 'Secured Credex Offered' 
                    : 'Unsecured Credex Offered',
                  style: TextStyle(
                    color: widget.response.data.action.details.securedCredex 
                      ? AppColors.textPrimary 
                      : AppColors.techAzure,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              widget.response.data.action.details.securedCredex
                ? StyledCard.gold(
                    padding: const EdgeInsets.all(16),
                    margin: EdgeInsets.zero,
                    showTitleOverlay: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Amount', '${widget.amount} ${widget.denomination}'),
                        const SizedBox(height: 12),
                        _buildDetailRow('To', widget.response.data.action.details.receiverAccountName),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          'New Balance',
                          _getNewBalance(),
                        ),
                      ],
                    ),
                  )
                : StyledCard.teal(
                    padding: const EdgeInsets.all(16),
                    margin: EdgeInsets.zero,
                    showTitleOverlay: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Amount', '${widget.amount} ${widget.denomination}'),
                        const SizedBox(height: 12),
                        _buildDetailRow('To', widget.response.data.action.details.receiverAccountName),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          'Due Date',
                          _formatDueDate(widget.response.data.action.details.dueDate),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 24),
              widget.response.data.action.details.securedCredex
                ? ActionButton(
                    label: 'Done',
                    onPressed: () => _handleDone(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    borderRadius: BorderRadius.circular(8),
                  )
                : ActionButton.teal(
                    label: 'Done',
                    onPressed: () => _handleDone(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    borderRadius: BorderRadius.circular(8),
                  ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
  
  String _getNewBalance() {
    final denom = widget.denomination;
    return widget.response.data.dashboard.accounts.first.balanceData.securedNetBalancesByDenom.firstWhere(
      (balance) {
        return balance.endsWith(' $denom') && 
               (balance.startsWith('-') || 
                balance.startsWith('+') || 
                RegExp(r'^\d').hasMatch(balance));
      },
      orElse: () => '0.0 $denom',
    );
  }
  
  String _formatDueDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return 'Not specified';
    }
    
    try {
      // Parse the date string (expected format: YYYY-MM-DD)
      final date = DateTime.parse(dateString);
      // Format it using the DateFormatter utility
      return DateFormatter.formatShortDate(date);
    } catch (e) {
      // If parsing fails, return the original string
      return dateString;
    }
  }
  
  void _handleDone(BuildContext context) {
    Navigator.of(context).pop();
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => WillPopScope(
          onWillPop: () async => false,
          child: const AlertDialog(
            backgroundColor: AppColors.surface,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                SizedBox(height: 16),
                Text(
                  'Refreshing...',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
      
      // Trigger refresh to update dashboard and transactions
      widget.homeBloc.add(const HomeFetchPendingTransactions());
    }
  }
}
