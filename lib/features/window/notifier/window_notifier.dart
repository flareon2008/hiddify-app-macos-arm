import 'dart:io' as io;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

part 'window_notifier.g.dart';

const minimumWindowSize = Size(368, 568);
const defaultWindowSize = Size(868, 668);

/// Method channel for communicating with native macOS code
const _dockVisibilityChannel = MethodChannel('com.hiddify/dock_visibility');

@Riverpod(keepAlive: true)
class WindowNotifier extends _$WindowNotifier with AppLogger {
  @override
  Future<void> build() async {
    if (!PlatformUtils.isDesktop) return;

    // if (io.Platform.isWindows) {
    //   loggy.debug("ensuring single instance");
    //   await WindowsSingleInstance.ensureSingleInstance([], "Hiddify");
    // }

    await windowManager.ensureInitialized();
    await initWindowState();
  }

  Future<void> saveWindowState() async {
    if (await windowManager.isMaximized()) {
      await ref.read(Preferences.windowMaximized.notifier).update(true);
    } else {
      final size = await windowManager.getSize();
      final position = await windowManager.getPosition();

      await ref.read(Preferences.windowMaximized.notifier).update(false);
      await ref.read(Preferences.windowSize.notifier).update(size);
      await ref.read(Preferences.windowPosition.notifier).update(position);
    }
  }

  Future<void> initWindowState() async {
    final isMaximized = ref.read(Preferences.windowMaximized);
    loggy.debug("window state. maximized: $isMaximized");
    final size = ref.read(Preferences.windowSize);
    loggy.debug("window state. size: $size");
    final position = ref.read(Preferences.windowPosition);
    final isWindowVisible = position != null && await checkWindowVisivility(position, size);
    loggy.debug("window state. position: ${isWindowVisible ? position : "centered"}");
    final silentStart = ref.read(Preferences.silentStart);
    loggy.debug("window state. silent start: ${silentStart ? "Enabled" : "Disabled"}");
    final hideFromDock = ref.read(Preferences.hideFromDock);
    loggy.debug("window state. hide from dock: ${hideFromDock ? "Enabled" : "Disabled"}");

    // Do NOT apply dock visibility here — window must show first.
    // Dock visibility is applied after the window is shown below.

    await windowManager.waitUntilReadyToShow(
      WindowOptions(size: size, center: !isWindowVisible, minimumSize: minimumWindowSize),
    );
    if (isWindowVisible) {
      await windowManager.setPosition(position);
      loggy.debug("restoring window to position: $position");
    } else {
      loggy.debug("no previous position found, centering window");
    }
    if (isMaximized) {
      await windowManager.maximize();
      loggy.debug("restoring window to maximized state");
    }
    if (!silentStart) {
      await ref.read(windowNotifierProvider.notifier).show(focus: false);
      loggy.debug("showing app window on start");
    } else {
      loggy.debug("silent start, remain hidden accessible via tray");
    }

    // NOW apply dock visibility AFTER window is shown
    if (io.Platform.isMacOS && hideFromDock) {
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        await _dockVisibilityChannel.invokeMethod('setDockVisibility', {'visible': false});
        loggy.debug("dock hidden after window shown");
      } catch (e) {
        loggy.warning("Failed to set dock visibility on startup", e);
      }
    }
  }

  Future<bool> checkWindowVisivility(Offset windowPos, Size windowSize, {double tolerance = 10.0}) async {
    final Rect windowRect = windowPos & windowSize;

    final displays = await screenRetriever.getAllDisplays();

    for (final display in displays) {
      if (display.visiblePosition == null || display.visibleSize == null) {
        continue;
      }
      final Rect monitorRect = display.visiblePosition! & display.visibleSize!;
      if (windowRect.left >= (monitorRect.left - tolerance) &&
          windowRect.top >= (monitorRect.top - tolerance) &&
          windowRect.right <= (monitorRect.right + tolerance) &&
          windowRect.bottom <= (monitorRect.bottom + tolerance)) {
        return true;
      }
    }
    return false;
  }

  Future<void> show({bool focus = true}) async {
    await windowManager.show();
    if (focus) await windowManager.focus();
    if (io.Platform.isMacOS) {
      await windowManager.setSkipTaskbar(false);
    }
  }

  Future<void> hide() async {
    await windowManager.hide();
    if (io.Platform.isMacOS) {
      await windowManager.setSkipTaskbar(true);
    }
  }

  Future<void> showOrHide() async {
    if (await windowManager.isVisible()) {
      await hide();
    } else {
      await show();
    }
  }

  /// Toggle dock visibility (macOS only)
  Future<void> setDockVisibility(bool visible) async {
    if (!io.Platform.isMacOS) return;
    try {
      await _dockVisibilityChannel.invokeMethod('setDockVisibility', {'visible': visible});
      loggy.debug("dock visibility set to: $visible");
    } catch (e) {
      loggy.warning("Failed to set dock visibility", e);
    }
  }

  Future<void> exit() async {
    await ref
        .read(connectionNotifierProvider.notifier)
        .abortConnection()
        .timeout(const Duration(seconds: 2))
        .catchError((e) {
          loggy.warning("error aborting connection on quit", e);
        });
    await trayManager.destroy();
    await windowManager.destroy();
    // Force terminate the app process (windowManager.destroy alone may not quit on macOS)
    io.exit(0);
  }
}
