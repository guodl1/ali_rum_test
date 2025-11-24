import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

import '../services/api_service.dart';
import '../models/models.dart';
import 'audio_player_page.dart';

/// 图片上传页面 - 严格按照 upload-structure.json 设计
/// 参考 upload.svg 的视觉效果
class ImageUploadPage extends StatefulWidget {
  final File imageFile;

  const ImageUploadPage({
    Key? key,
    required this.imageFile,
  }) : super(key: key);

  @override
  State<ImageUploadPage> createState() => _ImageUploadPageState();
}

class _ImageUploadPageState extends State<ImageUploadPage> {
  final ApiService _apiService = ApiService();
  bool _isUploading = false;
  String? _extractedText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 严格按照 upload-structure.json 的背景色 rgb(238, 239, 223)
    final backgroundColor = isDark
        ? const Color(0xFF191815)
        : const Color(0xFFEEEFDF); // rgb(238, 239, 223)

    final textColor = isDark
        ? const Color(0xFFF1EEE3)
        : const Color(0xFF191815);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // 顶部返回按钮
              _buildTopBar(textColor),
              
              // 内容区域
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // 图片显示区域 - 参考 upload-structure.json rectangle-394 (266x402)
                      _buildImagePreview(),
                      const SizedBox(height: 40),
                      // 文本预览区域（如果有）
                      if (_extractedText != null) _buildTextPreview(textColor),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              
              // 底部按钮区域
              _buildBottomButton(textColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: textColor,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 图片预览 - 参考 upload-structure.json rectangle-394 (266x402)
  Widget _buildImagePreview() {
    return Container(
      width: 266,
      height: 402,
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9), // rgb(217, 217, 217)
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.file(
          widget.imageFile,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.error_outline, size: 48),
            );
          },
        ),
      ),
    );
  }

  /// 文本预览
  Widget _buildTextPreview(Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '识别文本',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _extractedText ?? '',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.8),
              fontSize: 14,
              height: 1.6,
            ),
            maxLines: 10,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 底部按钮 - 参考 upload-structure.json rectangle-395 (305x76)
  Widget _buildBottomButton(Color textColor) {
    return Container(
      width: 305,
      height: 76,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9E9), // rgb(255, 233, 233)
        borderRadius: BorderRadius.circular(15),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isUploading ? null : _handleListen,
          borderRadius: BorderRadius.circular(15),
          child: Center(
            child: _isUploading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2C2C2C)),
                    ),
                  )
                : const Text(
                    '听一听',
                    style: TextStyle(
                      color: Color(0xFF2C2C2C), // rgb(44, 44, 44)
                      fontSize: 36,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// 处理"听一听"按钮点击（符合指南流程）
  Future<void> _handleListen() async {
    setState(() {
      _isUploading = true;
    });

    try {
      // 1. 上传图片到服务器
      final uploadResult = await _apiService.uploadFile(
        file: widget.imageFile,
        fileType: 'image',
      );

      if (!mounted) return;

      // 2. 获取提取的文本
      String? extractedText;
      final fileId = uploadResult['file_id'] as int?;
      final status = uploadResult['status'] as String?;

      if (uploadResult['text'] != null) {
        // 服务器立即返回文本
        extractedText = uploadResult['text'] as String;
      } else if (status == 'processing' && fileId != null) {
        // 需要轮询文件处理状态（OCR）
        extractedText = await _pollFileStatus(fileId);
      } else {
        throw Exception('服务器未返回文本或处理状态异常');
      }

      if (extractedText.isEmpty) {
        throw Exception('未能提取到文本内容');
      }

      setState(() {
        _extractedText = extractedText;
      });

      if (!mounted) return;

      // 3. 调用语音合成（使用 Azure 快速同步，或选择 Minimax 异步）
      // 这里使用 Azure 作为默认，可根据文本长度或用户选择切换
      final ttsResult = await _apiService.generateAudio(
        text: extractedText,
        provider: 'azure', // 可改为 'minimax' 测试异步流程
        voiceType: 'zh-CN-XiaoxiaoNeural', // Azure 默认声音
      );

      if (!mounted) return;

      // 4. 处理 TTS 响应
      final ttsProvider = ttsResult['provider'] as String?;
      final ttsStatus = ttsResult['status'] as String?;
      
      String? audioUrl;
      int? historyId;

      if (ttsStatus == 'completed') {
        // 同步返回（Azure/Google）
        audioUrl = ttsResult['audio_url'] as String?;
        historyId = ttsResult['history_id'] as int?;
      } else if (ttsStatus == 'processing' && ttsProvider == 'minimax') {
        // 异步处理（Minimax）
        final taskId = ttsResult['taskId'] as String?;
        if (taskId == null) {
          throw Exception('Minimax 未返回任务ID');
        }
        
        // 轮询任务状态
        final taskResult = await _pollTaskStatus(taskId);
        audioUrl = taskResult['audio_url'] as String?;
        historyId = taskResult['history_id'] as int?;
      } else {
        throw Exception('语音合成响应格式异常');
      }

      if (audioUrl == null) {
        throw Exception('未获取到音频URL');
      }

      // 将可空 audioUrl 提升为不可空类型，避免在后续 await 后失去类型提升
      final String resolvedAudioUrl = audioUrl;

      setState(() {
        _isUploading = false;
      });

      // 5. 构建历史记录并导航到播放页面
      if (!mounted) return;
      
      HistoryModel history;
      if (historyId != null) {
        final historyList = await _apiService.getHistory();
        history = historyList.firstWhere(
          (h) => h.id == historyId,
            orElse: () => _createHistoryFromResult(
            {'audio_url': resolvedAudioUrl, 'file_id': fileId},
            resolvedAudioUrl,
            extractedText,
          ),
        );
      } else {
        history = _createHistoryFromResult(
          {'audio_url': resolvedAudioUrl, 'file_id': fileId},
          resolvedAudioUrl,
          extractedText,
        );
      }

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => AudioPlayerPage(history: history),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('处理失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 轮询文件处理状态（OCR）
  Future<String> _pollFileStatus(int fileId) async {
    const maxAttempts = 30;
    const pollInterval = Duration(seconds: 2);

    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(pollInterval);

      if (!mounted) throw Exception('页面已关闭');

      try {
        final fileStatus = await _apiService.getFileStatus(fileId);
        final status = fileStatus['status'] as String?;

        if (status == 'done') {
          final text = fileStatus['result_text'] as String?;
          if (text != null && text.isNotEmpty) {
            return text;
          } else {
            throw Exception('文件处理完成但未提取到文本');
          }
        } else if (status == 'failed') {
          throw Exception('文件处理失败');
        }
        // 如果是 processing，继续轮询
      } catch (e) {
        if (i == maxAttempts - 1) {
          rethrow;
        }
      }
    }

    throw Exception('文件处理超时');
  }

  /// 轮询任务状态（TTS）
  Future<Map<String, dynamic>> _pollTaskStatus(String taskId) async {
    const maxAttempts = 60; // Minimax 可能需要更长时间
    const pollInterval = Duration(seconds: 2);

    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(pollInterval);

      if (!mounted) throw Exception('页面已关闭');

      try {
        final response = await _apiService.getTaskStatus(taskId);
        final data = response['data'] as Map<String, dynamic>?;
        
        if (data == null) {
          throw Exception('任务状态响应格式错误');
        }

        final taskStatus = data['status'] as String?;

        if (taskStatus == 'completed') {
          final result = data['result'] as Map<String, dynamic>?;
          if (result != null) {
            return {
              'audio_url': result['audio_url'],
              'history_id': data['history_id'],
            };
          } else {
            throw Exception('任务完成但未返回结果');
          }
        } else if (taskStatus == 'failed') {
          throw Exception(data['message'] ?? '任务处理失败');
        }
        // 如果状态是 processing，继续轮询
      } catch (e) {
        if (i == maxAttempts - 1) {
          rethrow;
        }
      }
    }

    throw Exception('任务处理超时');
  }

  /// 从服务器结果创建历史记录
  HistoryModel _createHistoryFromResult(
    Map<String, dynamic> result,
    String audioUrl,
    String? extractedText,
  ) {
    return HistoryModel(
      id: result['history_id'] as int? ?? 0,
      userId: result['user_id'] as int? ?? 0,
      fileId: result['file_id'] as int? ?? 0,
      voiceType: result['voice_type'] as String? ?? 'default',
      voiceName: result['voice_name'] as String? ?? result['voice_type'] as String? ?? '默认声音',
      audioUrl: audioUrl,
      createdAt: DateTime.now(),
      isFavorite: false,
      file: result['file'] != null
          ? FileModel.fromJson(result['file'] as Map<String, dynamic>)
          : FileModel(
              id: result['file_id'] as int? ?? 0,
              userId: result['user_id'] as int? ?? 0,
              type: 'image',
              originalName: widget.imageFile.path.split('/').last,
              size: widget.imageFile.lengthSync(),
              uploadTime: DateTime.now(),
              status: 'done',
              resultText: extractedText,
            ),
    );
  }
}

