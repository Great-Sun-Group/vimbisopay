import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/error_translator.dart';

class ConnectivityService {
  // Singleton instance
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  // Stream controller for broadcasting connectivity status
  final _connectivityStreamController = StreamController<bool>.broadcast();
  
  // Public stream that components can listen to
  Stream<bool> get connectivityStream => _connectivityStreamController.stream;
  
  // Current connectivity status
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  // Initialize the service
  Future<void> initialize() async {
    Logger.data('Initializing ConnectivityService');
    
    try {
      // Check initial connection status
      final connectivityResult = await Connectivity().checkConnectivity();
      _updateConnectionStatus(connectivityResult);
      
      // Listen for connectivity changes
      Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
        Logger.data('Connectivity changed: $result');
        _updateConnectionStatus(result);
      });
      
      Logger.data('ConnectivityService initialized successfully');
    } catch (e, stackTrace) {
      Logger.error('Error initializing ConnectivityService', e, stackTrace);
    }
  }

  // Update and broadcast connection status
  void _updateConnectionStatus(ConnectivityResult result) {
    final isConnected = result != ConnectivityResult.none;
    
    // Only broadcast if status changed
    if (_isConnected != isConnected) {
      _isConnected = isConnected;
      _connectivityStreamController.add(isConnected);
      
      Logger.data('Connection status updated: ${isConnected ? 'ONLINE' : 'OFFLINE'}');
    }
  }

  // Check current connectivity
  Future<bool> checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      Logger.error('Error checking connectivity', e);
      return true; // Assume connected on error to prevent false negatives
    }
  }

  // Clean up resources
  void dispose() {
    _connectivityStreamController.close();
  }
  
  /// Checks if an error is network-related
  bool isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socketexception') || 
           errorString.contains('failed host lookup') ||
           errorString.contains('timeout') ||
           errorString.contains('network') ||
           errorString.contains('connection');
  }
  
  /// Gets a user-friendly message for a specific error
  String getErrorMessage(dynamic error) {
    return ErrorTranslator.getNetworkErrorMessage(error);
  }
  
  /// Translates any error to a user-friendly message
  String translateError(dynamic error) {
    return ErrorTranslator.translateError(error);
  }
}
