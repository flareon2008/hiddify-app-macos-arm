import 'package:freezed_annotation/freezed_annotation.dart';

part 'proxy_app.freezed.dart';
part 'proxy_app.g.dart';

@freezed
class ProxyApp with _$ProxyApp {
  const factory ProxyApp({
    required String id,
    required String name,
    required String processName,
    String? processPath,
    @Default(true) bool enabled,
  }) = _ProxyApp;

  factory ProxyApp.fromJson(Map<String, dynamic> json) => _$ProxyAppFromJson(json);
}
