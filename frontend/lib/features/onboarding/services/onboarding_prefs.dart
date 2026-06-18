// features/onboarding/services/onboarding_prefs.dart
// Purpose: Manages reading and writing local settings configuration to a JSON file (~/.kivo_workspace_config.json).

import 'dart:convert';
import 'dart:io';

class OnboardingPrefs {
  static Future<File> get _file async {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    return File('$home/.kivo_workspace_config.json');
  }

  static Future<Map<String, dynamic>> read() async {
    try {
      final file = await _file;
      if (await file.exists()) {
        final content = await file.readAsString();
        return json.decode(content) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  static Future<void> write(Map<String, dynamic> data) async {
    try {
      final file = await _file;
      final existing = await read();
      existing.addAll(data);
      await file.writeAsString(json.encode(existing));
    } catch (_) {}
  }

  // --- Convenience Getters ---
  static Future<bool> isOnboardingComplete() async {
    final data = await read();
    return data['onboardingCompleted'] as bool? ?? false;
  }

  static Future<bool> isTutorialComplete() async {
    final data = await read();
    return data['tutorialCompleted'] as bool? ?? false;
  }

  static Future<List<String>> getSelectedModels() async {
    final data = await read();
    final list = data['selectedModels'] as List<dynamic>?;
    return list?.map((e) => e.toString()).toList() ?? ['qwen2.5:1.5b'];
  }

  static Future<List<String>> getDownloadedModels() async {
    final data = await read();
    final list = data['downloadedModels'] as List<dynamic>?;
    return list?.map((e) => e.toString()).toList() ?? [];
  }

  static Future<String> getThemeMode() async {
    final data = await read();
    return data['themeMode'] as String? ?? 'light';
  }

  static Future<String> getFontFamily() async {
    final data = await read();
    return data['fontFamily'] as String? ?? 'sans';
  }

  static Future<String> getAccentColor() async {
    final data = await read();
    return data['accentColor'] as String? ?? '#0075DE';
  }

  static Future<String> getOllamaUrl() async {
    final data = await read();
    return data['ollamaUrl'] as String? ?? 'http://localhost:11434';
  }

  static Future<String> getActiveModel() async {
    final data = await read();
    return data['activeModel'] as String? ?? 'qwen2.5:1.5b';
  }
}
