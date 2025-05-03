import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
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

  // Check actual internet connectivity by pinging a reliable server
  Future<bool> checkInternetConnectivity() async {
    try {
      // Try to reach a reliable endpoint
      final response = await http.get(
        Uri.parse('https://www.google.com'),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      Logger.error('Error checking internet connectivity', e);
      return false;
    }
  }

  // Update and broadcast connection status
  void _updateConnectionStatus(ConnectivityResult result) async {
    // First check if connected to a network
    final hasNetwork = result != ConnectivityResult.none;
    
    // If not connected to any network, definitely offline
    if (!hasNetwork) {
      if (_isConnected) {
        _isConnected = false;
        _connectivityStreamController.add(false);
        Logger.data('Connection status updated: OFFLINE (no network)');
      }
      return;
    }
    
    // If connected to a network, verify internet connectivity
    final hasInternet = await checkInternetConnectivity();
    
    // Only update if status changed
    if (_isConnected != hasInternet) {
      _isConnected = hasInternet;
      _connectivityStreamController.add(hasInternet);
      Logger.data('Connection status updated: ${hasInternet ? 'ONLINE' : 'OFFLINE (no internet)'}');
    }
  }

  // Check current connectivity
  Future<bool> checkConnectivity() async {
    try {
      // First check if connected to a network
      final result = await Connectivity().checkConnectivity();
      final hasNetwork = result != ConnectivityResult.none;
      
      // If not connected to any network, definitely offline
      if (!hasNetwork) {
        return false;
      }
      
      // If connected to a network, verify internet connectivity
      return await checkInternetConnectivity();
    } catch (e) {
      Logger.error('Error checking connectivity', e);
      return false; // Changed to assume disconnected on error to prevent false positives
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
