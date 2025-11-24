import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// 本地历史记录服务
/// 负责在本地存储和管理历史记录，不依赖云端
class LocalHistoryService {
  static final LocalHistoryService _instance = LocalHistoryService._internal();
  factory LocalHistoryService() => _instance;
  LocalHistoryService._internal();

  static const String _historyKey = 'local_history_records';
  static int _nextId = 1;

  /// 初始化，获取当前最大ID
  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    if (historyJson != null) {
      final List<dynamic> historyList = jsonDecode(historyJson);
      if (historyList.isNotEmpty) {
        final maxId = historyList.map((h) => h['id'] as int).reduce((a, b) => a > b ? a : b);
        _nextId = maxId + 1;
      }
    }
  }

  /// 保存历史记录
  Future<HistoryModel> saveHistory({
    required String audioUrl,
    required String voiceType,
    required String voiceName,
    int duration = 0,
    String? resultText,
    String? fileName,
    int? fileId,
    int? userId,
  }) async {
    await _initialize();
    
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    List<Map<String, dynamic>> historyList = [];
    
    if (historyJson != null) {
      historyList = List<Map<String, dynamic>>.from(jsonDecode(historyJson));
    }

    final history = {
      'id': _nextId++,
      'user_id': userId ?? 0,
      'file_id': fileId ?? 0,
      'voice_type': voiceType,
      'voice_name': voiceName,
      'audio_url': audioUrl,
      'created_at': DateTime.now().toIso8601String(),
      'is_favorite': false,
      'duration': duration,
      'file': fileName != null || resultText != null
          ? {
              'id': fileId ?? 0,
              'user_id': userId ?? 0,
              'type': 'audio',
              'original_name': fileName ?? 'audio.mp3',
              'size': 0,
              'upload_time': DateTime.now().toIso8601String(),
              'status': 'done',
              'result_text': resultText,
            }
          : null,
    };

    historyList.insert(0, history);
    
    await prefs.setString(_historyKey, jsonEncode(historyList));
    
    return HistoryModel.fromJson(history);
  }

  /// 获取所有历史记录
  Future<List<HistoryModel>> getHistory({
    int? userId,
    int page = 1,
    int pageSize = 20,
    bool? isFavorite,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    
    if (historyJson == null) {
      return [];
    }

    List<Map<String, dynamic>> historyList = List<Map<String, dynamic>>.from(jsonDecode(historyJson));
    
    // 过滤
    if (userId != null) {
      historyList = historyList.where((h) => h['user_id'] == userId).toList();
    }
    
    if (isFavorite != null) {
      historyList = historyList.where((h) => h['is_favorite'] == isFavorite).toList();
    }

    // 分页
    final start = (page - 1) * pageSize;
    final end = start + pageSize;
    final paginatedList = historyList.sublist(
      start < historyList.length ? start : historyList.length,
      end < historyList.length ? end : historyList.length,
    );

    return paginatedList.map((json) => HistoryModel.fromJson(json)).toList();
  }

  /// 切换收藏状态
  Future<bool> toggleFavorite(int historyId, bool isFavorite) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    
    if (historyJson == null) {
      return false;
    }

    List<Map<String, dynamic>> historyList = List<Map<String, dynamic>>.from(jsonDecode(historyJson));
    final index = historyList.indexWhere((h) => h['id'] == historyId);
    
    if (index == -1) {
      return false;
    }

    historyList[index]['is_favorite'] = isFavorite;
    await prefs.setString(_historyKey, jsonEncode(historyList));
    
    return true;
  }

  /// 删除历史记录
  Future<bool> deleteHistory(int historyId) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    
    if (historyJson == null) {
      return false;
    }

    List<Map<String, dynamic>> historyList = List<Map<String, dynamic>>.from(jsonDecode(historyJson));
    historyList.removeWhere((h) => h['id'] == historyId);
    
    await prefs.setString(_historyKey, jsonEncode(historyList));
    
    return true;
  }

  /// 根据ID获取历史记录
  Future<HistoryModel?> getHistoryById(int historyId) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    
    if (historyJson == null) {
      return null;
    }

    List<Map<String, dynamic>> historyList = List<Map<String, dynamic>>.from(jsonDecode(historyJson));
    final history = historyList.firstWhere(
      (h) => h['id'] == historyId,
      orElse: () => {},
    );

    if (history.isEmpty) {
      return null;
    }

    return HistoryModel.fromJson(history);
  }

  /// 清除所有历史记录
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    _nextId = 1;
  }
}

