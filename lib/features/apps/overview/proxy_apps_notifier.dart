import 'dart:convert';

import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/core/utils/preferences_utils.dart';
import 'package:hiddify/features/apps/model/proxy_app.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'proxy_apps_notifier.g.dart';

@Riverpod(keepAlive: true)
class ProxyApps extends _$ProxyApps {
  late final PreferencesEntry<String, String> _entry;

  @override
  List<ProxyApp> build() {
    final prefs = ref.watch(sharedPreferencesProvider).requireValue;
    _entry = PreferencesEntry(
      preferences: prefs,
      key: 'proxy_apps_list',
      defaultValue: '[]',
    );
    final raw = _entry.read();
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => ProxyApp.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addApp({
    required String name,
    required String processName,
    String? processPath,
  }) async {
    final app = ProxyApp(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      processName: processName,
      processPath: processPath,
    );
    state = [...state, app];
    await _save();
  }

  Future<void> removeApp(String id) async {
    state = state.where((a) => a.id != id).toList();
    await _save();
  }

  Future<void> toggleApp(String id) async {
    state = [
      for (final app in state)
        if (app.id == id) app.copyWith(enabled: !app.enabled) else app,
    ];
    await _save();
  }

  Future<void> updateApp({
    required String id,
    String? name,
    String? processName,
    String? processPath,
  }) async {
    state = [
      for (final app in state)
        if (app.id == id)
          app.copyWith(
            name: name ?? app.name,
            processName: processName ?? app.processName,
            processPath: processPath ?? app.processPath,
          )
        else
          app,
    ];
    await _save();
  }

  Future<void> _save() async {
    final json = jsonEncode(state.map((e) => e.toJson()).toList());
    await _entry.write(json);
  }
}
