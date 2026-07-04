import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/utils/utils.dart';

/// Bridges VPN status between the Flutter app and the macOS Control Center widget.
/// Writes connection status to shared UserDefaults (App Group)
/// and polls for toggle requests from the widget.
class WidgetSync {
  static const _channel = MethodChannel('com.hiddify/widget_sync');
  static Timer? _pollTimer;
  static bool _listening = false;

  static final _loggy = AppLogger();

  /// Start polling for widget toggle requests. Call once on app startup.
  static void startPolling({required Future<void> Function() onToggle}) {
    if (!Platform.isMacOS || _listening) return;
    _listening = true;

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final hasToggled = await _channel.invokeMethod<bool>('checkToggleRequest');
        if (hasToggled == true) {
          _loggy.debug('Widget toggle request detected');
          await onToggle();
        }
      } catch (e) {
        // Widget sync is best-effort
      }
    });
  }

  /// Sync current connection status to the widget
  static Future<void> syncStatus(ConnectionStatus status, int delay) async {
    if (!Platform.isMacOS) return;
    try {
      final connected = status is Connected;
      await _channel.invokeMethod('updateStatus', {
        'connected': connected,
        'delay': delay,
      });
    } catch (e) {
      // Widget sync is best-effort
    }
  }

  static void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _listening = false;
  }
}
