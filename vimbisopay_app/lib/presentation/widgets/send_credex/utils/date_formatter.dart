/// Utility class for formatting dates consistently across the app
class DateFormatter {
  /// Format date as "Tuesday, March 3, 2034"
  static String formatLongDate(DateTime date) {
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
  
  /// Format date as "Mar 3, 2034" for compact display
  static String formatShortDate(DateTime date) {
    final List<String> shortMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final String month = shortMonths[date.month - 1];
    final int day = date.day;
    final int year = date.year;
    
    return '$month $day, $year';
  }
  
  /// Format date as "MM/DD/YYYY"
  static String formatNumericDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
  
  /// Get a default due date (28 days from now)
  static DateTime getDefaultDueDate() {
    return DateTime.now().add(const Duration(days: 28));
  }
}
