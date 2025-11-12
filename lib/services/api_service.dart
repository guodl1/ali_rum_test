import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';
import '../config/app_config.dart';
import '../models/models.dart';

/// API服务类
/// 统一管理所有后端API调用
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String baseUrl = ApiKeys.baseUrl;

  // HTTP客户端
  final http.Client _client = http.Client();

  /// 上传文件
  Future<Map<String, dynamic>> uploadFile({
    required File file,
    required String fileType,
    String? userId,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/upload'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      request.fields['file_type'] = fileType;
      if (userId != null) {
        request.fields['user_id'] = userId;
      }

      var response = await request.send().timeout(
        Duration(milliseconds: AppConfig.connectionTimeout),
      );

      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        return json.decode(responseData);
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  /// 提交文本进行TTS转换
  Future<Map<String, dynamic>> generateAudio({
    required String text,
    required String voiceType,
    String? userId,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/generate-audio'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'text': text,
              'voice_type': voiceType,
              'user_id': userId,
            }),
          )
          .timeout(Duration(milliseconds: AppConfig.receiveTimeout));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Generate audio failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Generate audio error: $e');
    }
  }

  /// 获取历史记录
  Future<List<HistoryModel>> getHistory({
    String? userId,
    int page = 1,
    int pageSize = 20,
    bool? isFavorite,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        if (userId != null) 'user_id': userId,
        if (isFavorite != null) 'is_favorite': isFavorite.toString(),
      };

      final uri = Uri.parse('$baseUrl/api/history').replace(
        queryParameters: queryParams,
      );

      final response = await _client.get(uri).timeout(
            Duration(milliseconds: AppConfig.connectionTimeout),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> historyList = data['data'];
        return historyList.map((json) => HistoryModel.fromJson(json)).toList();
      } else {
        throw Exception('Get history failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Get history error: $e');
    }
  }

  /// 切换收藏状态
  Future<bool> toggleFavorite({
    required int historyId,
    required bool isFavorite,
  }) async {
    try {
      final response = await _client
          .put(
            Uri.parse('$baseUrl/api/history/$historyId/favorite'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'is_favorite': isFavorite}),
          )
          .timeout(Duration(milliseconds: AppConfig.connectionTimeout));

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Toggle favorite error: $e');
    }
  }

  /// 删除历史记录
  Future<bool> deleteHistory(int historyId) async {
    try {
      final response = await _client
          .delete(Uri.parse('$baseUrl/api/history/$historyId'))
          .timeout(Duration(milliseconds: AppConfig.connectionTimeout));

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Delete history error: $e');
    }
  }

  /// 获取语音类型列表
  Future<List<VoiceTypeModel>> getVoiceTypes({String? language}) async {
    try {
      final queryParams = language != null ? {'language': language} : null;
      final uri = Uri.parse('$baseUrl/api/voice-types').replace(
        queryParameters: queryParams,
      );

      final response = await _client.get(uri).timeout(
            Duration(milliseconds: AppConfig.connectionTimeout),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> voiceList = data['data'];
        return voiceList.map((json) => VoiceTypeModel.fromJson(json)).toList();
      } else {
        throw Exception('Get voice types failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Get voice types error: $e');
    }
  }

  /// 提交URL进行内容抓取
  Future<Map<String, dynamic>> submitUrl({
    required String url,
    String? userId,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/submit-url'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'url': url,
              'user_id': userId,
            }),
          )
          .timeout(Duration(milliseconds: AppConfig.receiveTimeout));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Submit URL failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Submit URL error: $e');
    }
  }

  /// 获取任务状态
  Future<Map<String, dynamic>> getTaskStatus(String taskId) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/task/$taskId'))
          .timeout(Duration(milliseconds: AppConfig.connectionTimeout));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Get task status failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Get task status error: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
