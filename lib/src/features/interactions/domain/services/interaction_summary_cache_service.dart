import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class InteractionSummaryCacheEntry {
  final String summary;
  final String severity;
  final String updatedAt;

  const InteractionSummaryCacheEntry({
    required this.summary,
    required this.severity,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'severity': severity,
        'updatedAt': updatedAt,
      };

  static InteractionSummaryCacheEntry? fromJsonString(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return InteractionSummaryCacheEntry(
        summary: decoded['summary']?.toString() ?? '',
        severity: decoded['severity']?.toString() ?? '',
        updatedAt: decoded['updatedAt']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

class InteractionSummaryCacheService {
  static const _prefix = 'interaction_summary_cache_v2_';

  Future<InteractionSummaryCacheEntry?> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;
    return InteractionSummaryCacheEntry.fromJsonString(raw);
  }

  Future<void> set(String key, InteractionSummaryCacheEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', jsonEncode(entry.toJson()));
  }
}
