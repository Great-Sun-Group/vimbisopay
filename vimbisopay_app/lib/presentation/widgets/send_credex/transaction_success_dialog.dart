import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lottie/lottie.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_event.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/send_credex_widgets.dart';

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
              const Text(
                'Secured Credex Offered',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TransactionDetailRow(
                      label: 'Amount',
                      value: '${widget.amount} ${widget.denomination}',
                    ),
                    const SizedBox(height: 12),
                    TransactionDetailRow(
                      label: 'To',
                      value: widget.response.data.action.details.receiverAccountName,
                    ),
                    const SizedBox(height: 12),
                    TransactionDetailRow(
                      label: 'New Balance',
                      value: _getNewBalance(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _handleDone(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
