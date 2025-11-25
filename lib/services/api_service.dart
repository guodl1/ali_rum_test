import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../config/api_keys.dart';
import '../config/app_config.dart';
import '../models/models.dart';

/// API服务类
/// 统一管理所有后端API调用
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _initDio();
  }

  final String baseUrl = ApiKeys.baseUrl;
  late final Dio _dio;

  void _initDio() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(milliseconds: AppConfig.connectionTimeout),
      receiveTimeout: Duration(milliseconds: AppConfig.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Add interceptors if needed (e.g. for logging or auth)
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print('Dio: $obj'),
    ));
  }

  /// 上传文件
  Future<Map<String, dynamic>> uploadFile({
    required File file,
    required String fileType,
    String? userId,
  }) async {
    try {
      String fileName = file.path.split('/').last;
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
        'file_type': fileType,
        if (userId != null) 'user_id': userId,
      });

      final response = await _dio.post(
        '/api/upload',
        data: formData,
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Upload error: ${e.message}');
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
      final multipartFiles = <MultipartFile>[];
      for (var file in files) {
        String fileName = file.path.split('/').last;
        multipartFiles.add(await MultipartFile.fromFile(file.path, filename: fileName));
      }

      FormData formData = FormData.fromMap({
        'files': multipartFiles,
        if (userId != null) 'user_id': userId,
      });

      final response = await _dio.post(
        '/api/upload/images',
        data: formData,
        options: Options(
          receiveTimeout: Duration(milliseconds: AppConfig.connectionTimeout * 3),
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Upload images failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Upload images error: ${e.message}');
    } catch (e) {
      throw Exception('Upload images error: $e');
    }
  }

  /// 提交文本进行TTS转换（统一接口）
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

      final response = await _dio.post(
        '/api/generate-audio',
        data: body,
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Generate audio failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Generate audio error: ${e.message}');
    } catch (e) {
      throw Exception('Generate audio error: $e');
    }
  }

  /// 发送阿里一键登录 accessToken 给服务器
  Future<Map<String, dynamic>> loginWithAliToken(String accessToken) async {
    try {
      final response = await _dio.post(
        '/api/auth/ali/token-login',
        data: {'access_token': accessToken},
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Login token exchange failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Login token exchange error: ${e.message}');
    } catch (e) {
      throw Exception('Login token exchange error: $e');
    }
  }

  /// 华为一键登录
  Future<Map<String, dynamic>> loginWithHuaweiCode(String authorizationCode) async {
    try {
      final response = await _dio.post(
        '/api/auth/huawei/quick-login',
        data: {'authorization_code': authorizationCode},
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Huawei login failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Huawei login error: ${e.message}');
    } catch (e) {
      throw Exception('Huawei login error: $e');
    }
  }

  /// 获取用户信息
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final response = await _dio.get(
        '/api/auth/profile',
        queryParameters: {'user_id': userId},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['error'] ?? 'Failed to get profile');
        }
      } else {
        throw Exception('Get profile failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Get profile error: ${e.message}');
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
        'page': page,
        'page_size': pageSize,
        if (userId != null) 'user_id': userId,
        if (isFavorite != null) 'is_favorite': isFavorite,
      };

      final response = await _dio.get(
        '/api/history',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> historyList = data['data'];
        return historyList.map((json) => HistoryModel.fromJson(json)).toList();
      } else {
        throw Exception('Get history failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Get history error: ${e.message}');
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
      final response = await _dio.put(
        '/api/history/$historyId/favorite',
        data: {'is_favorite': isFavorite},
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('Toggle favorite error: ${e.message}');
    } catch (e) {
      throw Exception('Toggle favorite error: $e');
    }
  }

  /// 删除历史记录
  Future<bool> deleteHistory(int historyId) async {
    try {
      final response = await _dio.delete('/api/history/$historyId');
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('Delete history error: ${e.message}');
    } catch (e) {
      throw Exception('Delete history error: $e');
    }
  }

  /// 检查语音类型数量
  Future<Map<String, dynamic>> checkVoiceTypesCount({
    String? versionTag,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'check_only': 'true',
      };
      if (versionTag != null) {
        queryParams['version_tag'] = versionTag;
      }

      final response = await _dio.get(
        '/api/voice-types',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'count': data['count'] ?? 0,
          'version_tag': data['version_tag'],
          'needs_update': data['needs_update'] ?? true,
        };
      } else {
        throw Exception('Check voice types count failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Check voice types count error: ${e.message}');
    } catch (e) {
      throw Exception('Check voice types count error: $e');
    }
  }

  /// 获取语音类型列表
  Future<Map<String, dynamic>> getVoiceTypes({
    String? language,
    String? versionTag,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (language != null) {
        queryParams['language'] = language;
      }
      if (versionTag != null) {
        queryParams['version_tag'] = versionTag;
      }

      final response = await _dio.get(
        '/api/voice-types',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
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
    } on DioException catch (e) {
      throw Exception('Get voice types error: ${e.message}');
    } catch (e) {
      throw Exception('Get voice types error: $e');
    }
  }

  /// 获取 Minimax 声线列表
  Future<List<Map<String, dynamic>>> getMinimaxVoices() async {
    try {
      final response = await _dio.get('/api/minimax/voices');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        } else {
          throw Exception('Failed to get Minimax voices');
        }
      } else {
        throw Exception('Get Minimax voices failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Get Minimax voices error: ${e.message}');
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
      final response = await _dio.post(
        '/api/submit-url',
        data: {
          'url': url,
          'user_id': userId,
        },
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Submit URL failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Submit URL error: ${e.message}');
    } catch (e) {
      throw Exception('Submit URL error: $e');
    }
  }

  /// 获取任务状态
  Future<Map<String, dynamic>> getTaskStatus(String taskId) async {
    try {
      final response = await _dio.get('/api/task/$taskId');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Get task status failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Get task status error: ${e.message}');
    } catch (e) {
      throw Exception('Get task status error: $e');
    }
  }

  /// 获取任务进度
  Future<Map<String, dynamic>> getProgress(String taskId) async {
    try {
      final response = await _dio.get('/api/progress/$taskId');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        // Dio throws for 404 by default unless validateStatus is changed, 
        // but we can catch it.
        throw Exception('Get progress failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Task not found or expired');
      }
      throw Exception('Get progress error: ${e.message}');
    } catch (e) {
      throw Exception('Get progress error: $e');
    }
  }

  /// 获取文件处理状态
  Future<Map<String, dynamic>> getFileStatus(int fileId) async {
    try {
      final response = await _dio.get('/api/upload/$fileId');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Get file status failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('File not found');
      }
      throw Exception('Get file status error: ${e.message}');
    } catch (e) {
      throw Exception('Get file status error: $e');
    }
  }

  /// 获取用户使用统计
  Future<Map<String, dynamic>> getUserUsageStats({String? userId}) async {
    try {
      final queryParams = userId != null ? {'user_id': userId} : null;
      final response = await _dio.get(
        '/api/usage-stats',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Get usage stats failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Get usage stats error: ${e.message}');
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
      final response = await _dio.post(
        '/api/voice-types/preview',
        data: {
          'voice_id': voiceId,
          if (model != null) 'model': model,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
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
    } on DioException catch (e) {
      throw Exception('Get voice preview error: ${e.message}');
    } catch (e) {
      throw Exception('Get voice preview error: $e');
    }
  }

  void dispose() {
    _dio.close();
  }
}
