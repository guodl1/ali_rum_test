import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 使用统计服务
/// 跟踪用户的字符使用情况
class UsageStatsService {
  static final UsageStatsService _instance = UsageStatsService._internal();
  factory UsageStatsService() => _instance;
  UsageStatsService._internal();

  static const String _usedCharactersKey = 'usage_stats_used_characters';
  static const String _totalCharactersKey = 'usage_stats_total_characters';
  static const String _isMemberKey = 'usage_stats_is_member';
  static const String _lastResetDateKey = 'usage_stats_last_reset_date';

  /// 获取使用统计
  Future<Map<String, dynamic>> getUsageStats() async {
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(_usedCharactersKey) ?? 0;
    final total = prefs.getInt(_totalCharactersKey) ?? 10000; // 默认10000字符
    final isMember = prefs.getBool(_isMemberKey) ?? false;
    
    return {
      'used_characters': used,
      'total_characters': total,
      'is_member': isMember,
    };
  }

  /// 增加使用的字符数
  Future<void> addUsedCharacters(int characters) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_usedCharactersKey) ?? 0;
    await prefs.setInt(_usedCharactersKey, current + characters);
  }

  /// 设置总字符限额
  Future<void> setTotalCharacters(int total) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_totalCharactersKey, total);
  }

  /// 设置会员状态
  Future<void> setIsMember(bool isMember) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isMemberKey, isMember);
    
    // 如果是会员，增加限额
    if (isMember) {
      await setTotalCharacters(1000000); // 会员100万字符
    } else {
      await setTotalCharacters(10000); // 免费用户1万字符
    }
  }

  /// 重置使用统计（每月重置）
  Future<void> resetMonthlyStats() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastReset = prefs.getString(_lastResetDateKey);
    
    if (lastReset != null) {
      final lastResetDate = DateTime.parse(lastReset);
      // 如果还在同一个月，不重置
      if (now.year == lastResetDate.year && now.month == lastResetDate.month) {
        return;
      }
    }
    
    // 重置使用量
    await prefs.setInt(_usedCharactersKey, 0);
    await prefs.setString(_lastResetDateKey, now.toIso8601String());
  }

  /// 检查是否有足够的字符额度
  Future<bool> hasEnoughCharacters(int required) async {
    final stats = await getUsageStats();
    final used = stats['used_characters'] as int;
    final total = stats['total_characters'] as int;
    return (total - used) >= required;
  }
}

