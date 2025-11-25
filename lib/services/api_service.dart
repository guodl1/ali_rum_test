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

  /// 批量上传图片（用于图库选择）
  Future<Map<String, dynamic>> uploadImages({
    required List<File> files,
    String? userId,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/upload/images'),
      );

      for (var file in files) {
        request.files.add(await http.MultipartFile.fromPath('files', file.path));
      }
      
      if (userId != null) {
        request.fields['user_id'] = userId;
      }

      var response = await request.send().timeout(
        Duration(milliseconds: AppConfig.connectionTimeout * 3), // 图片处理可能需要更长时间
      );

      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        return json.decode(responseData);
      } else {
        throw Exception('Upload images failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Upload images error: $e');
    }
  }

  /// 提交文本进行TTS转换（统一接口）
  /// provider: 'azure', 'google', 'minimax'
  /// Azure/Google: 使用 voiceType
  /// Minimax: 使用 voiceId + model
  Future<Map<String, dynamic>> generateAudio({
    required String text,
    String provider = 'azure',
    String? voiceType,
    String? voiceId,
    String? model,
    int? fileId,
    String? userId,
  }) async {
    try {
      final body = {
        'text': text,
        'provider': provider,
        if (voiceType != null) 'voice_type': voiceType,
        if (voiceId != null) 'voice_id': voiceId,
        if (model != null) 'model': model,
        if (fileId != null) 'file_id': fileId,
        if (userId != null) 'user_id': userId,
      };

      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/generate-audio'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
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

  /// 发送阿里一键登录 accessToken 给服务器，换取手机号并创建/获取账号
  Future<Map<String, dynamic>> loginWithAliToken(String accessToken) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/auth/ali/token-login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'access_token': accessToken}),
          )
          .timeout(Duration(milliseconds: AppConfig.receiveTimeout));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Login token exchange failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Login token exchange error: $e');
    }
  }

  /// 华为一键登录 - 通过授权码获取手机号并创建/获取账号
  Future<Map<String, dynamic>> loginWithHuaweiCode(String authorizationCode) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/auth/huawei/quick-login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'authorization_code': authorizationCode}),
          )
          .timeout(Duration(milliseconds: AppConfig.receiveTimeout));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Huawei login failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Huawei login error: $e');
    }
  }

  /// 获取用户信息
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/auth/profile?user_id=$userId'))
          .timeout(Duration(milliseconds: AppConfig.connectionTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['error'] ?? 'Failed to get profile');
        }
      } else {
        throw Exception('Get profile failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Get profile error: $e');
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

  /// 检查语音类型数量（只检查数量，不返回完整数据）
  /// [versionTag] 当前版本标签，用于提取数量
  Future<Map<String, dynamic>> checkVoiceTypesCount({
    String? versionTag,
  }) async {
    try {
      final queryParams = <String, String>{
        'check_only': 'true',
      };
      if (versionTag != null) {
        queryParams['version_tag'] = versionTag;
      }
      
      final uri = Uri.parse('$baseUrl/api/voice-types').replace(
        queryParameters: queryParams,
      );

      final response = await _client.get(uri).timeout(
            Duration(milliseconds: AppConfig.connectionTimeout),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'count': data['count'] ?? 0,
          'version_tag': data['version_tag'],
          'needs_update': data['needs_update'] ?? true,
        };
      } else {
        throw Exception('Check voice types count failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Check voice types count error: $e');
    }
  }

  /// 获取语音类型列表（支持增量更新）
  /// [language] 语言过滤
  /// [versionTag] 当前版本标签，如果提供且服务器返回无更新，则返回空列表
  Future<Map<String, dynamic>> getVoiceTypes({
    String? language,
    String? versionTag,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (language != null) {
        queryParams['language'] = language;
      }
      if (versionTag != null) {
        queryParams['version_tag'] = versionTag;
      }
      
      final uri = Uri.parse('$baseUrl/api/voice-types').replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      final response = await _client.get(uri).timeout(
            Duration(milliseconds: AppConfig.connectionTimeout),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> voiceList = data['data'] ?? [];
        final String? newVersionTag = data['version_tag'];
        final bool updated = data['updated'] ?? true;
        
        return {
          'voices': voiceList.map((json) => VoiceTypeModel.fromJson(json)).toList(),
          'version_tag': newVersionTag,
          'updated': updated,
        };
      } else {
        throw Exception('Get voice types failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Get voice types error: $e');
    }
  }

  /// 获取 Minimax 声线列表
  Future<List<Map<String, dynamic>>> getMinimaxVoices() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/minimax/voices'))
          .timeout(Duration(milliseconds: AppConfig.connectionTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        } else {
          throw Exception('Failed to get Minimax voices');
        }
      } else {
        throw Exception('Get Minimax voices failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Get Minimax voices error: $e');
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

  /// 获取任务状态（含远程查询，用于 Minimax 等异步任务）
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

  /// 获取任务进度（仅本地缓存，快速接口）
  Future<Map<String, dynamic>> getProgress(String taskId) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/progress/$taskId'))
          .timeout(Duration(milliseconds: AppConfig.connectionTimeout));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw Exception('Task not found or expired');
      } else {
        throw Exception('Get progress failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Get progress error: $e');
    }
  }

  /// 获取文件处理状态（用于轮询 OCR 等处理）
  Future<Map<String, dynamic>> getFileStatus(int fileId) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/upload/$fileId'))
          .timeout(Duration(milliseconds: AppConfig.connectionTimeout));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw Exception('File not found');
      } else {
        throw Exception('Get file status failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Get file status error: $e');
    }
  }

  /// 获取用户使用统计
  Future<Map<String, dynamic>> getUserUsageStats({String? userId}) async {
    try {
      final queryParams = userId != null ? {'user_id': userId} : null;
      final uri = Uri.parse('$baseUrl/api/usage-stats').replace(
        queryParameters: queryParams,
      );

      final response = await _client.get(uri).timeout(
            Duration(milliseconds: AppConfig.connectionTimeout),
          );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Get usage stats failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Get usage stats error: $e');
    }
  }

  /// 获取语音试听
  Future<String> getVoicePreview({
    required String voiceId,
    String? model,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/voice-types/preview'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'voice_id': voiceId,
              if (model != null) 'model': model,
            }),
          )
          .timeout(Duration(milliseconds: AppConfig.receiveTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final audioUrl = data['audio_url'];
        if (audioUrl != null) {
          // 如果是相对路径，拼接 baseUrl
          if (!audioUrl.startsWith('http')) {
            return '$baseUrl$audioUrl';
          }
          return audioUrl;
        } else {
          throw Exception('No audio URL returned');
        }
      } else {
        throw Exception('Get voice preview failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Get voice preview error: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
