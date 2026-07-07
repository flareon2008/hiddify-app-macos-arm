import 'dart:io';

class InstalledApp {
  const InstalledApp({
    required this.name,
    required this.bundleId,
    required this.executableName,
    required this.appPath,
  });

  final String name;
  final String bundleId;
  final String executableName;
  final String appPath;
}

class MacOSAppScanner {
  static Future<List<InstalledApp>> getInstalledApps() async {
    if (!Platform.isMacOS) return [];

    final appsDir = Directory('/Applications');
    if (!await appsDir.exists()) return [];

    final apps = <InstalledApp>[];
    await for (final entity in appsDir.list()) {
      if (entity is Directory && entity.path.endsWith('.app')) {
        final app = await _parseApp(entity.path);
        if (app != null) apps.add(app);
      }
    }

    // Also scan user's home Applications
    final homeAppsDir = Directory('${Platform.environment['HOME']}/Applications');
    if (await homeAppsDir.exists()) {
      await for (final entity in homeAppsDir.list()) {
        if (entity is Directory && entity.path.endsWith('.app')) {
          final app = await _parseApp(entity.path);
          if (app != null) apps.add(app);
        }
      }
    }

    apps.sort((a, b) => a.name.compareTo(b.name));
    return apps;
  }

  static Future<InstalledApp?> _parseApp(String appPath) async {
    try {
      final plistFile = File('$appPath/Contents/Info.plist');
      if (!await plistFile.exists()) return null;

      final content = await plistFile.readAsString();
      final name = _extractPlistValue(content, 'CFBundleName');
      final bundleId = _extractPlistValue(content, 'CFBundleIdentifier');
      final executable = _extractPlistValue(content, 'CFBundleExecutable');

      if (name.isEmpty || executable.isEmpty) return null;

      return InstalledApp(
        name: name,
        bundleId: bundleId,
        executableName: executable,
        appPath: appPath,
      );
    } catch (_) {
      return null;
    }
  }

  static String _extractPlistValue(String plistContent, String key) {
    // Simple plist parser - extract string value after <key>key</key>
    final keyPattern = RegExp('<key>$key</key>\\s*<string>(.*?)</string>', dotAll: true);
    final match = keyPattern.firstMatch(plistContent);
    return match?.group(1)?.trim() ?? '';
  }
}
