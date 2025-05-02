import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/utils/date_formatter.dart';

/// Widget for due date selection
class DueDateSelector extends StatelessWidget {
  final DateTime? selectedDate;
  final Function(DateTime?) onDateChanged;
  final String amount;
  final String denomination;
  
  const DueDateSelector({
    super.key,
    this.selectedDate,
    required this.onDateChanged,
    this.amount = "0.00",
    this.denomination = "USD",
  });

  @override
  Widget build(BuildContext context) {
    // Default date is 4 weeks from now
    final defaultDate = DateFormatter.getDefaultDueDate();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'I promise to provide $amount $denomination worth of value by',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _selectDate(context, defaultDate),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.textSecondary,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      selectedDate == null 
                          ? "No due date" 
                          : DateFormatter.formatLongDate(selectedDate!),
                      style: TextStyle(
                        color: selectedDate == null
                            ? AppColors.textSecondary.withOpacity(0.5)
                            : AppColors.techAzure, // Changed to teal
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today,
                    color: AppColors.techAzure,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Show clear button if a date is selected, otherwise show informational message
          selectedDate != null
            ? Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => onDateChanged(null),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.techAzure,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Clear'),
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Unsecured credexes without a due date are primarily intended for use between family and friends.",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, DateTime defaultDate) async {
    // Get tomorrow's date (to prevent selecting today or past dates)
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    
    // Create a custom calendar dialog that submits immediately when a date is tapped
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        // Start with the initial date
        DateTime viewDate = selectedDate ?? defaultDate;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Month and year navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: AppColors.techAzure),
                          onPressed: () {
                            setState(() {
                              viewDate = DateTime(
                                viewDate.year,
                                viewDate.month - 1,
                                1,
                              );
                            });
                          },
                        ),
                        Text(
                          "${_getMonthName(viewDate.month)} ${viewDate.year}",
                          style: TextStyle(
                            color: AppColors.techAzure,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.arrow_forward, color: AppColors.techAzure),
                          onPressed: () {
                            setState(() {
                              viewDate = DateTime(
                                viewDate.year,
                                viewDate.month + 1,
                                1,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Day of week headers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(7, (index) {
                        return SizedBox(
                          width: 30,
                          child: Text(
                            _getDayName(index),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Calendar grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: 42, // 6 weeks
                      itemBuilder: (context, index) {
                        // Calculate the day for this grid position
                        final firstDayOfMonth = DateTime(viewDate.year, viewDate.month, 1);
                        final daysInMonth = DateTime(viewDate.year, viewDate.month + 1, 0).day;
                        
                        // Calculate day offset (0 = Sunday, 6 = Saturday)
                        final firstWeekdayOfMonth = firstDayOfMonth.weekday % 7;
                        final day = index - firstWeekdayOfMonth + 1;
                        
                        // Check if this position is a valid day in the current month
                        if (day < 1 || day > daysInMonth) {
                          return Container(); // Empty cell
                        }
                        
                        // Create the date for this cell
                        final date = DateTime(viewDate.year, viewDate.month, day);
                        
                        // Check if this date is selectable (not in the past)
                        final isSelectable = !date.isBefore(tomorrow);
                        
                        // Check if this is the currently selected date
                        final isSelected = selectedDate != null && 
                                          date.year == selectedDate!.year && 
                                          date.month == selectedDate!.month && 
                                          date.day == selectedDate!.day;
                        
                        return GestureDetector(
                          onTap: isSelectable ? () {
                            // Immediately return the selected date and close the dialog
                            Navigator.of(context).pop(date);
                          } : null,
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.techAzure : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: isSelectable && !isSelected ? Border.all(
                                color: AppColors.techAzure.withOpacity(0.3),
                                width: 1,
                              ) : null,
                            ),
                            child: Center(
                              child: Text(
                                day.toString(),
                                style: TextStyle(
                                  color: !isSelectable 
                                      ? AppColors.textSecondary.withOpacity(0.3)
                                      : isSelected 
                                          ? AppColors.white 
                                          : AppColors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Cancel button
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.techAzure,
                      ),
                      child: Text('Cancel'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    
    if (picked != null) {
      onDateChanged(picked);
    }
  }
  
  // Helper methods for custom calendar
  String _getMonthName(int month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 
                   'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
  }
  
  String _getDayName(int day) {
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return days[day];
  }
}
