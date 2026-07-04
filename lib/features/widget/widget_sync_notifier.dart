import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Bridges VPN status between the Flutter app and the macOS Control Center widget.
/// Writes connection status to shared UserDefaults (App Group)
/// and polls for toggle requests from the widget.
class WidgetSyncNotifier extends Notifier<void> with AppLogger {
  static const _channel = MethodChannel('com.hiddify/widget_sync');

  Timer? _pollTimer;

  @override
  void build() {
    if (!Platform.isMacOS) return;

    // Poll for widget toggle requests every 2 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final hasToggled = await _channel.invokeMethod<bool>('checkToggleRequest');
        if (hasToggled == true) {
          loggy.debug('Widget toggle request detected, toggling VPN');
          await ref.read(connectionNotifierProvider.notifier).toggleConnection();
        }
      } catch (e) {
        // Widget sync is best-effort, ignore errors
      }
    });

    ref.onDispose(() {
      _pollTimer?.cancel();
    });
  }

  /// Call this to sync current connection status to the widget
  static Future<void> syncStatus(ConnectionStatus status, int delay) async {
    if (!Platform.isMacOS) return;
    try {
      final connected = status is Connected;
      await _channel.invokeMethod('updateStatus', {
        'connected': connected,
        'delay': delay,
      });
    } catch (e) {
      // Widget sync is best-effort, ignore errors
    }
  }
}
