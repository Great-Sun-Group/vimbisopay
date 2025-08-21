import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';

/// A reusable widget for displaying credit rating information
/// Can be used in both compact (bar) and detailed (breakdown) modes
class CreditRatingDisplay extends StatelessWidget {
  final CreditRating? creditRating;
  final bool showDetailed;
  final bool showLegend;
  final String? memberName;
  final VoidCallback? onTap;
  final bool isClickable;
  final double height;
  final EdgeInsets padding;

  const CreditRatingDisplay({
    super.key,
    required this.creditRating,
    this.showDetailed = false,
    this.showLegend = false,
    this.memberName,
    this.onTap,
    this.isClickable = false,
    this.height = 18.0,
    this.padding = const EdgeInsets.all(0),
  });

  /// Factory constructor for compact bar display (used in cards)
  const CreditRatingDisplay.compact({
    super.key,
    required this.creditRating,
    this.memberName,
    this.onTap,
    this.isClickable = false,
  }) : showDetailed = false,
       showLegend = false,
       height = 18.0,
       padding = const EdgeInsets.all(0);

  /// Factory constructor for detailed display (used in credit report screen)
  const CreditRatingDisplay.detailed({
    super.key,
    required this.creditRating,
    this.memberName,
    this.onTap,
    this.isClickable = false,
  }) : showDetailed = true,
       showLegend = true,
       height = 24.0,
       padding = const EdgeInsets.all(16.0);

  @override
  Widget build(BuildContext context) {
    Widget content;
    
    if (creditRating == null || !_hasCreditHistory) {
      content = Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: AppColors.techAzure,
            width: 1.0,
          ),
        ),
        child: const Center(
          child: Text(
            'Credit rating not yet established',
            style: TextStyle(
              color: AppColors.techAzure,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      content = Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDetailed) ...[
              _buildDetailedHeader(),
              const SizedBox(height: 12),
            ],
            _buildCreditRatingBar(),
            if (showDetailed) ...[
              const SizedBox(height: 12),
              _buildBreakdownDetails(),
            ],
            if (showLegend) ...[
              const SizedBox(height: 12),
              _buildLegend(),
            ],
          ],
        ),
      );
    }

    if (isClickable && onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        splashColor: AppColors.techAzure.withOpacity(0.2),
        highlightColor: AppColors.techAzure.withOpacity(0.1),
        child: content,
      );
    }

    return content;
  }

  bool get _hasCreditHistory {
    if (creditRating == null) return false;
    return creditRating!.redeemedTotalUSD > 0 ||
           creditRating!.outstandingTotalUSD > 0 ||
           creditRating!.defaultedTotalUSD > 0 ||
           creditRating!.writtenOffTotalUSD > 0;
  }

  double get _totalCreditActivity {
    if (creditRating == null) return 0.0;
    return creditRating!.redeemedTotalUSD +
           creditRating!.outstandingTotalUSD +
           creditRating!.defaultedTotalUSD +
           creditRating!.writtenOffTotalUSD;
  }


  Widget _buildDetailedHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          memberName != null ? '$memberName\'s Credit Rating' : 'Credit Rating',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Total Credit Activity: \$${_totalCreditActivity.toStringAsFixed(2)} USD',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCreditRatingBar() {
    final percentages = _calculatePercentages();
    
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        // Bar graph with calculated proportions
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Row(
              children: [
                // Redeemed (gold)
                if (percentages['redeemed']! > 0)
                  Expanded(
                    flex: percentages['redeemed']!,
                    child: Container(
                      color: AppColors.primary,
                    ),
                  ),
                // Outstanding (teal)
                if (percentages['outstanding']! > 0)
                  Expanded(
                    flex: percentages['outstanding']!,
                    child: Container(
                      color: AppColors.techAzure,
                    ),
                  ),
                // Defaulted (yellow)
                if (percentages['defaulted']! > 0)
                  Expanded(
                    flex: percentages['defaulted']!,
                    child: Container(
                      color: AppColors.yellowPrimary,
                    ),
                  ),
                // Written off (red)
                if (percentages['writtenOff']! > 0)
                  Expanded(
                    flex: percentages['writtenOff']!,
                    child: Container(
                      color: AppColors.darkRed,
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Credit rating text inside the bar
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            'Credit rating',
            style: TextStyle(
              color: Colors.black,
              fontSize: showDetailed ? 12 : 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownDetails() {
    return Column(
      children: [
        _buildBreakdownRow(
          'Redeemed',
          creditRating!.redeemedTotalUSD,
          AppColors.primary,
        ),
        const SizedBox(height: 4),
        _buildBreakdownRow(
          'Outstanding',
          creditRating!.outstandingTotalUSD,
          AppColors.techAzure,
        ),
        const SizedBox(height: 4),
        _buildBreakdownRow(
          'Defaulted',
          creditRating!.defaultedTotalUSD,
          AppColors.yellowPrimary,
        ),
        const SizedBox(height: 4),
        _buildBreakdownRow(
          'Written Off',
          creditRating!.writtenOffTotalUSD,
          AppColors.darkRed,
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, double amount, Color color) {
    final percentage = _totalCreditActivity > 0 
        ? (amount / _totalCreditActivity * 100).toStringAsFixed(1)
        : '0.0';
    
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '($percentage%)',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Credit Rating Legend',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _buildLegendItem(
            AppColors.primary,
            'Redeemed',
            'Successfully completed credex transactions',
          ),
          _buildLegendItem(
            AppColors.techAzure,
            'Outstanding',
            'Active credex transactions pending completion',
          ),
          _buildLegendItem(
            AppColors.yellowPrimary,
            'Defaulted',
            'Overdue credex transactions',
          ),
          _buildLegendItem(
            AppColors.darkRed,
            'Written Off',
            'Uncollectable credex transactions',
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _calculatePercentages() {
    final total = _totalCreditActivity;
    
    // Calculate percentages of each component
    int redeemedPercent = total > 0 ? ((creditRating!.redeemedTotalUSD / total) * 100).round() : 0;
    int outstandingPercent = total > 0 ? ((creditRating!.outstandingTotalUSD / total) * 100).round() : 0;
    int defaultedPercent = total > 0 ? ((creditRating!.defaultedTotalUSD / total) * 100).round() : 0;
    int writtenOffPercent = total > 0 ? ((creditRating!.writtenOffTotalUSD / total) * 100).round() : 0;
    
    // Ensure minimum visibility for non-zero values
    if (creditRating!.redeemedTotalUSD > 0 && redeemedPercent == 0) redeemedPercent = 1;
    if (creditRating!.outstandingTotalUSD > 0 && outstandingPercent == 0) outstandingPercent = 1;
    if (creditRating!.defaultedTotalUSD > 0 && defaultedPercent == 0) defaultedPercent = 1;
    if (creditRating!.writtenOffTotalUSD > 0 && writtenOffPercent == 0) writtenOffPercent = 1;
    
    // Adjust percentages to ensure they sum to 100%
    final sum = redeemedPercent + outstandingPercent + defaultedPercent + writtenOffPercent;
    if (sum != 100) {
      // Find the largest component to adjust
      int largest = redeemedPercent;
      String largestType = 'redeemed';
      
      if (outstandingPercent > largest) {
        largest = outstandingPercent;
        largestType = 'outstanding';
      }
      if (defaultedPercent > largest) {
        largest = defaultedPercent;
        largestType = 'defaulted';
      }
      if (writtenOffPercent > largest) {
        largest = writtenOffPercent;
        largestType = 'writtenOff';
      }
      
      // Adjust the largest component
      if (largestType == 'redeemed') {
        redeemedPercent += (100 - sum);
      } else if (largestType == 'outstanding') {
        outstandingPercent += (100 - sum);
      } else if (largestType == 'defaulted') {
        defaultedPercent += (100 - sum);
      } else {
        writtenOffPercent += (100 - sum);
      }
    }
    
    return {
      'redeemed': redeemedPercent,
      'outstanding': outstandingPercent,
      'defaulted': defaultedPercent,
      'writtenOff': writtenOffPercent,
    };
  }
}
