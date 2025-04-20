# Analytics Tracking System

This document describes the analytics tracking system implemented in the VimbisoPay app. The system is designed to be provider-agnostic, allowing for easy swapping or addition of analytics providers without changing the app code.

## Architecture

The analytics tracking system consists of the following components:

1. **Analytics Events**: Base classes and specific event types for tracking different kinds of events
2. **Analytics Provider Interface**: A common interface that all analytics providers must implement
3. **Provider Implementations**: Concrete implementations of the analytics provider interface
4. **Analytics Service**: The main service that the app code interacts with

### Component Diagram

```
App Code → AnalyticsService → AnalyticsProvider Interface → Provider Implementations
                                                              (Firebase, etc.)
```

## Analytics Events

All analytics events extend the base `AnalyticsEvent` class, which provides common functionality for all events. The following event types are available:

- **ScreenViewEvent**: For tracking screen views
- **ButtonTapEvent**: For tracking button taps
- **ApiErrorEvent**: For tracking API errors
- **CrashEvent**: For tracking app crashes
- **CustomEvent**: For tracking custom events

## Analytics Provider Interface

The `AnalyticsProvider` interface defines the contract that all analytics providers must implement. It includes methods for:

- Initializing the provider
- Tracking events
- Setting user properties
- Setting the current screen
- Logging errors
- Resetting analytics data

## Provider Implementations

Currently, the system includes the following provider implementations:

- **FirebaseAnalyticsProvider**: Uses Firebase Analytics to track events

Additional providers can be added by implementing the `AnalyticsProvider` interface.

## Analytics Service

The `AnalyticsService` is the main entry point for the app code to track events. It provides methods for:

- Tracking screen views
- Tracking button taps
- Tracking API errors
- Tracking app crashes
- Tracking custom events
- Setting user properties
- Resetting analytics data

The service delegates the actual tracking to one or more analytics providers.

## Usage

### Initialization

The analytics service is initialized in the `main.dart` file:

```dart
// Initialize Analytics Service
print('Initializing Analytics Service...');
await ServiceLocator.initializeAnalyticsService();
print('Analytics Service initialized successfully');

// Set up global error handler for tracking crashes
print('Setting up global error handler...');
CrashTracker.setupGlobalErrorHandler();
print('Global error handler set up successfully');
```

### Tracking Screen Views

```dart
// In a screen's initState method
try {
  _analyticsService = ServiceLocator.analyticsService;
  // Track screen view
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _analyticsService.trackScreenView('ScreenName');
  });
} catch (e) {
  Logger.error('Failed to initialize analytics service', e);
}
```

### Tracking Button Taps

```dart
// When a button is tapped
try {
  _analyticsService.trackButtonTap(
    'button_id',
    screenName: 'ScreenName',
    parameters: {'param_key': 'param_value'},
  );
} catch (e) {
  Logger.error('Failed to track button tap', e);
}
```

### Tracking API Errors

```dart
// When an API error occurs
try {
  _analyticsService.trackApiError(
    endpoint: '/api/endpoint',
    statusCode: 404,
    errorMessage: 'Resource not found',
    parameters: {'request_id': 'abc123'},
  );
} catch (e) {
  Logger.error('Failed to track API error', e);
}
```

### Tracking App Crashes

```dart
// When an app crash occurs
try {
  _analyticsService.trackCrash(
    exception: exception,
    stackTrace: stackTrace,
    parameters: {'app_version': '1.0.0'},
  );
} catch (e) {
  Logger.error('Failed to track crash', e);
}
```

### Tracking Custom Events

```dart
// For tracking custom events
try {
  _analyticsService.trackCustomEvent(
    'custom_event_name',
    parameters: {'param_key': 'param_value'},
  );
} catch (e) {
  Logger.error('Failed to track custom event', e);
}
```

## Utility Classes

The analytics system includes several utility classes to make it easier to track events throughout the app:

### ScreenTracker

The `ScreenTracker` class provides methods for tracking screen views:

```dart
// Track a screen view
ScreenTracker.trackScreenView('HomeScreen');

// Using the mixin in a StatefulWidget
class _MyScreenState extends State<MyScreen> with ScreenViewTrackerMixin {
  @override
  String get screenName => 'MyScreen';
  
  @override
  Map<String, dynamic> get screenParameters => {
    'param_key': 'param_value',
  };
  
  // The mixin automatically tracks the screen view in initState
}
```

### ButtonTracker

The `ButtonTracker` class provides methods for tracking button taps:

```dart
// Track a button tap
ButtonTracker.trackButtonTap(
  'login_button',
  screenName: 'LoginScreen',
);

// Create a callback that tracks a button tap
onPressed: ButtonTracker.trackButtonTapWithCallback(
  'login_button',
  screenName: 'LoginScreen',
  callback: () {
    // Original callback code
  },
);

// Create a callback that tracks a button tap with a value
onChanged: ButtonTracker.trackButtonTapWithValueCallback<bool>(
  'toggle_button',
  screenName: 'SettingsScreen',
  callback: (value) {
    // Original callback code
  },
);
```

### ApiErrorTracker

The `ApiErrorTracker` class provides methods for tracking API errors:

```dart
// Track an API error
ApiErrorTracker.trackError(
  endpoint: '/api/endpoint',
  statusCode: 404,
  errorMessage: 'Resource not found',
);

// Track an API exception
try {
  // API call
} catch (e, stackTrace) {
  ApiErrorTracker.trackException(
    endpoint: '/api/endpoint',
    exception: e,
    stackTrace: stackTrace,
  );
}
```

### CrashTracker

The `CrashTracker` class provides methods for tracking app crashes:

```dart
// Track a crash
CrashTracker.trackCrash(
  exception: exception,
  stackTrace: stackTrace,
);

// Run a function and track any exceptions
CrashTracker.runAndTrackExceptions(() {
  // Code that might throw an exception
});

// Run an async function and track any exceptions
await CrashTracker.runAndTrackAsyncExceptions(() async {
  // Async code that might throw an exception
});
```

## Adding a New Analytics Provider

To add a new analytics provider:

1. Create a new class that implements the `AnalyticsProvider` interface
2. Add the new provider to the list of providers in the `ServiceLocator.initializeAnalyticsService()` method

Example:

```dart
// Create a new provider class
class NewAnalyticsProvider implements AnalyticsProvider {
  // Implement all required methods
}

// Add the provider to the list in ServiceLocator
static Future<AnalyticsService> initializeAnalyticsService() async {
  if (_analyticsService != null) {
    return _analyticsService!;
  }
  
  // Create a list of analytics providers
  final providers = <AnalyticsProvider>[
    _firebaseAnalyticsProvider,
    NewAnalyticsProvider(), // Add the new provider here
  ];
  
  // Create and initialize the analytics service
  _analyticsService = AnalyticsService(providers);
  await _analyticsService!.initialize();
  
  return _analyticsService!;
}
```

## Best Practices

1. **Error Handling**: Always wrap analytics tracking calls in try-catch blocks to prevent crashes if the analytics service fails
2. **Meaningful Event Names**: Use clear, descriptive names for events and parameters
3. **Consistent Naming**: Follow a consistent naming convention for events and parameters
4. **Minimal Data**: Only track the data you need to avoid privacy concerns
5. **User Consent**: Ensure you have user consent before tracking analytics data
6. **Testing**: Test analytics tracking in development to ensure it works as expected
