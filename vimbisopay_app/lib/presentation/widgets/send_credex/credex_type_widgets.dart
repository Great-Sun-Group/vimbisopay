import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/presentation/blocs/send_credex/send_credex_state.dart';

/// Widget for Credex type selection
class CredexTypeSelector extends StatelessWidget {
  final CredexType credexType;
  final Function(CredexType) onCredexTypeChanged;
  
  const CredexTypeSelector({
    super.key,
    required this.credexType,
    required this.onCredexTypeChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeButton(
              context,
              title: 'Secured',
              isSelected: credexType == CredexType.SECURED,
              onTap: () => onCredexTypeChanged(CredexType.SECURED),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildTypeButton(
              context,
              title: 'Unsecured',
              isSelected: credexType == CredexType.UNSECURED,
              onTap: () => onCredexTypeChanged(CredexType.UNSECURED),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTypeButton(
    BuildContext context, {
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? AppColors.secondary : AppColors.textSecondary,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// Widget for due date selection
class DueDateSelector extends StatefulWidget {
  final DateTime? selectedDate;
  final Function(DateTime?) onDateChanged;
  
  const DueDateSelector({
    super.key,
    this.selectedDate,
    required this.onDateChanged,
  });

  @override
  State<DueDateSelector> createState() => _DueDateSelectorState();
}

class _DueDateSelectorState extends State<DueDateSelector> {
  DateTime? _effectiveDate;
  
  @override
  void initState() {
    super.initState();
    // Use the provided date or set a default date (4 weeks from now) for display purposes only
    _effectiveDate = widget.selectedDate ?? DateTime.now().add(const Duration(days: 28));
    // Don't notify parent if no date was provided - keep it null
  }
  
  @override
  void didUpdateWidget(DueDateSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update effective date when selectedDate changes
    if (widget.selectedDate != oldWidget.selectedDate) {
      _effectiveDate = widget.selectedDate ?? _effectiveDate;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Due Date (Optional)',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _selectDate(context),
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
                      widget.selectedDate == null 
                          ? "Recommended for business" 
                          : _formatDate(_effectiveDate!),
                      style: TextStyle(
                        color: widget.selectedDate == null
                            ? AppColors.textSecondary.withOpacity(0.5)
                            : AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Show clear button if a date is selected, otherwise show informational message
          widget.selectedDate != null
            ? Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // Actually clear the date (set to null)
                    setState(() {
                      // Keep _effectiveDate for display in the picker, but tell parent it's null
                    });
                    widget.onDateChanged(null);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondary,
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
                ),
              ),
        ],
      ),
    );
  }
  
  // Format date as "Tuesday, March 3, 2034"
  String _formatDate(DateTime date) {
    final List<String> weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    final List<String> months = [
      'January', 'February', 'March', 'April', 'May', 'June', 
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    // Weekday is 1-7 where 1 is Monday and 7 is Sunday
    final String weekday = weekdays[date.weekday - 1];
    final String month = months[date.month - 1];
    final int day = date.day;
    final int year = date.year;
    
    return '$weekday, $month $day, $year';
  }

  Future<void> _selectDate(BuildContext context) async {
    // Get tomorrow's date (to prevent selecting today or past dates)
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    
    // Create a custom date picker that closes immediately when a date is selected
    final DateTime? picked = await _showCustomDatePicker(
      context: context,
      initialDate: _effectiveDate ?? DateTime.now().add(const Duration(days: 28)),
      firstDate: tomorrow,
      lastDate: DateTime(2100),
    );
    
    if (picked != null) {
      setState(() {
        _effectiveDate = picked;
      });
      widget.onDateChanged(picked);
    }
  }
  
  // Custom date picker that closes immediately when a date is selected
  Future<DateTime?> _showCustomDatePicker({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    return showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CalendarDatePicker(
                  initialDate: initialDate,
                  firstDate: firstDate,
                  lastDate: lastDate,
                  onDateChanged: (DateTime date) {
                    // Close the dialog and return the selected date
                    Navigator.of(context).pop(date);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
