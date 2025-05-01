import 'package:equatable/equatable.dart';

/// Base class for all analytics events.
///
/// This class defines the common structure for all analytics events
/// in the application. All specific event types should extend this class.
abstract class AnalyticsEvent extends Equatable {
  /// The name of the event.
  final String name;

  /// The timestamp when the event occurred.
  final DateTime timestamp;

  /// Additional parameters associated with the event.
  final Map<String, dynamic> parameters;

  /// Creates a new analytics event.
  ///
  /// [name] is the name of the event.
  /// [parameters] is a map of additional parameters associated with the event.
  AnalyticsEvent({
    required this.name,
    required this.parameters,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  List<Object?> get props => [name, timestamp, parameters];

  /// Converts the event to a map that can be sent to analytics providers.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'timestamp': timestamp.toIso8601String(),
      ...parameters,
    };
  }
}
