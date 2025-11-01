import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/credex_detail.dart';

/// Widget for displaying a bar graph of credex amounts (redeemed, outstanding, defaulted, written-off)
class CredexBarGraph extends StatefulWidget {
  final CredexDetail credexDetail;
  final bool showLegend;
  final double height;

  const CredexBarGraph({
    super.key,
    required this.credexDetail,
    this.showLegend = true,
    this.height = 24.0,
  });

  @override
  State<CredexBarGraph> createState() => _CredexBarGraphState();
}

class _CredexBarGraphState extends State<CredexBarGraph> {
  bool _isLegendExpanded = false;

  @override
  Widget build(BuildContext context) {
    final totalAmount = widget.credexDetail.initialAmount;

    if (totalAmount == 0) {
      return Container(
        height: widget.height,
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
            'No credex data available',
            style: TextStyle(
              color: AppColors.techAzure,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [

        // Bar graph container
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.darkBlueDark1,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppColors.techAzure.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: widget.showLegend
                ? () {
                    setState(() {
                      _isLegendExpanded = !_isLegendExpanded;
                    });
                  }
                : null,
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                // Bar graph with calculated proportions
                _buildBarGraph(totalAmount),

                // Dropdown arrow (centered if legend is enabled)
                if (widget.showLegend)
                  Positioned(
                    right: widget.height * 0.25, // Position relative to height
                    top: 0,
                    bottom: 0,
                    child: Icon(
                      _isLegendExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.darkBlueDark1,
                      size: widget.height * 0.8,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Expandable legend details
        if (widget.showLegend && _isLegendExpanded) ...[
          const SizedBox(height: 12),
          _buildLegendDetails(totalAmount),
        ],
      ],
    );
  }

  Widget _buildBarGraph(double totalAmount) {
    final percentages = _calculatePercentages(totalAmount);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: widget.height,
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
    );
  }

  Widget _buildLegendDetails(double totalAmount) {
    return Column(
      children: [
        _buildLegendRow(
          'Redeemed',
          'Successfully completed portions of this credex.',
          widget.credexDetail.redeemedAmount,
          totalAmount,
          AppColors.primary,
        ),
        const SizedBox(height: 8),
        _buildLegendRow(
          'Outstanding',
          'Active portions of this credex still pending.',
          widget.credexDetail.outstandingAmount,
          totalAmount,
          AppColors.techAzure,
        ),
        const SizedBox(height: 8),
        _buildLegendRow(
          'Defaulted',
          'Overdue portions of this credex.',
          widget.credexDetail.defaultedAmount,
          totalAmount,
          AppColors.yellowPrimary,
        ),
        const SizedBox(height: 8),
        _buildLegendRow(
          'Written Off',
          'Uncollectable portions of this credex.',
          widget.credexDetail.writtenOffAmount,
          totalAmount,
          AppColors.darkRed,
        ),
      ],
    );
  }

  Widget _buildLegendRow(String label, String description, double amount,
      double totalAmount, Color color) {
    final percentage = totalAmount > 0
        ? (amount / totalAmount * 100).toStringAsFixed(1)
        : '0.0';

    return Row(
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  Text(
                    '\$${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
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
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Map<String, int> _calculatePercentages(double totalAmount) {
    if (totalAmount == 0) {
      return {
        'redeemed': 0,
        'outstanding': 0,
        'defaulted': 0,
        'writtenOff': 0,
      };
    }

    // Calculate percentages of each component
    int redeemedPercent = (widget.credexDetail.redeemedAmount / totalAmount * 100).round();
    int outstandingPercent = (widget.credexDetail.outstandingAmount / totalAmount * 100).round();
    int defaultedPercent = (widget.credexDetail.defaultedAmount / totalAmount * 100).round();
    int writtenOffPercent = (widget.credexDetail.writtenOffAmount / totalAmount * 100).round();

    // Ensure minimum visibility for non-zero values
    if (widget.credexDetail.redeemedAmount > 0 && redeemedPercent == 0) redeemedPercent = 1;
    if (widget.credexDetail.outstandingAmount > 0 && outstandingPercent == 0) outstandingPercent = 1;
    if (widget.credexDetail.defaultedAmount > 0 && defaultedPercent == 0) defaultedPercent = 1;
    if (widget.credexDetail.writtenOffAmount > 0 && writtenOffPercent == 0) writtenOffPercent = 1;

    // Adjust percentages to ensure they sum to 100%
    final sum = redeemedPercent + outstandingPercent + defaultedPercent + writtenOffPercent;
    if (sum != 100 && sum > 0) {
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
      final adjustment = 100 - sum;
      if (largestType == 'redeemed') {
        redeemedPercent += adjustment;
      } else if (largestType == 'outstanding') {
        outstandingPercent += adjustment;
      } else if (largestType == 'defaulted') {
        defaultedPercent += adjustment;
      } else {
        writtenOffPercent += adjustment;
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
