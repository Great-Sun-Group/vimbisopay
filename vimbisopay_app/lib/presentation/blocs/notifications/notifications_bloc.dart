import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/notification_preferences.dart';

// Events
abstract class NotificationsEvent {}

class NotificationsInitialize extends NotificationsEvent {}

class UpdateNotificationPreference extends NotificationsEvent {
  final NotificationPreferences preferences;

  UpdateNotificationPreference(this.preferences);
}

// States
abstract class NotificationsState {}

class NotificationsInitial extends NotificationsState {}

class NotificationsLoading extends NotificationsState {}

class NotificationsLoaded extends NotificationsState {
  final NotificationPreferences preferences;

  NotificationsLoaded(this.preferences);
}

class NotificationsError extends NotificationsState {
  final String message;

  NotificationsError(this.message);
}

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  static const String _prefsKey = 'notification_preferences';
  final SharedPreferences _prefs;

  NotificationsBloc(this._prefs) : super(NotificationsInitial()) {
    on<NotificationsInitialize>(_onInitialize);
    on<UpdateNotificationPreference>(_onUpdatePreference);
  }

  Future<void> _onInitialize(
    NotificationsInitialize event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      emit(NotificationsLoading());
      
      final prefsJson = _prefs.getString(_prefsKey);
      Logger.data('''
Initializing notification preferences:
- Has stored preferences: ${prefsJson != null}
- Raw preferences: $prefsJson
''');

      final preferences = prefsJson != null
          ? NotificationPreferences.fromJson(
              Map<String, dynamic>.from(
                jsonDecode(prefsJson),
              ),
            )
          : const NotificationPreferences();

      Logger.data('''
Notification preferences initialized:
- Master enabled: ${preferences.masterEnabled}
- Money transfers received: ${preferences.moneyTransfersReceived}
- Hide preview content: ${preferences.hidePreviewContent}
''');

      // Ensure preferences are saved even if this is the first initialization
      if (prefsJson == null) {
        await _prefs.setString(
          _prefsKey,
          jsonEncode(preferences.toJson()),
        );
        Logger.data('Default preferences saved to storage');
      }

      emit(NotificationsLoaded(preferences));
    } catch (e, stackTrace) {
      Logger.error('Error initializing notification preferences', e, stackTrace);
      emit(NotificationsError('Failed to load notification preferences'));
    }
  }

  Future<void> _onUpdatePreference(
    UpdateNotificationPreference event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state is! NotificationsLoaded) return;

    try {
      // Save to SharedPreferences
      final prefsJson = jsonEncode(event.preferences.toJson());
      Logger.data('''
Updating notification preferences:
- New preferences: $prefsJson
''');

      await _prefs.setString(_prefsKey, prefsJson);
      Logger.data('Notification preferences saved successfully');

      emit(NotificationsLoaded(event.preferences));
    } catch (e, stackTrace) {
      Logger.error('Error updating notification preferences', e, stackTrace);
      // Revert to previous state on error
      if (state is NotificationsLoaded) {
        emit(NotificationsLoaded((state as NotificationsLoaded).preferences));
      }
      emit(NotificationsError('Failed to update notification preferences'));
    }
  }
}
