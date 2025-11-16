import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../config/api_keys.dart';

/// 音频下载服务
/// 负责从服务器下载音频文件到本地，并管理本地缓存
class AudioDownloadService {
  static final AudioDownloadService _instance = AudioDownloadService._internal();
  factory AudioDownloadService() => _instance;
  AudioDownloadService._internal();

  // 本地音频缓存目录
  Directory? _audioCacheDir;

  /// 初始化音频缓存目录
  Future<void> _ensureCacheDir() async {
    if (_audioCacheDir != null && await _audioCacheDir!.exists()) {
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    _audioCacheDir = Directory(path.join(appDir.path, 'audio_cache'));
    
    if (!await _audioCacheDir!.exists()) {
      await _audioCacheDir!.create(recursive: true);
    }
  }

  /// 从服务器URL获取完整URL
  String _getFullUrl(String serverUrl) {
    if (serverUrl.startsWith('http://') || serverUrl.startsWith('https://')) {
      return serverUrl;
    }
    // 如果是相对路径，拼接baseUrl
    final baseUrl = ApiKeys.baseUrl;
    if (serverUrl.startsWith('/')) {
      return '$baseUrl$serverUrl';
    }
    return '$baseUrl/$serverUrl';
  }

  /// 根据URL生成本地文件名（使用URL的hash值）
  String _getLocalFileName(String url) {
    // 提取URL中的文件名，如果没有则使用hash
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    if (segments.isNotEmpty) {
      final fileName = segments.last;
      if (fileName.isNotEmpty && fileName.contains('.')) {
        return fileName;
      }
    }
    
    // 如果没有文件名，使用URL的hash值
    final hash = url.hashCode.abs();
    return 'audio_$hash.mp3';
  }

  /// 检查本地文件是否存在
  Future<bool> isFileCached(String serverUrl) async {
    await _ensureCacheDir();
    final fileName = _getLocalFileName(serverUrl);
    final file = File(path.join(_audioCacheDir!.path, fileName));
    return await file.exists();
  }

  /// 获取本地文件路径（如果已缓存）
  Future<String?> getLocalFilePath(String serverUrl) async {
    await _ensureCacheDir();
    final fileName = _getLocalFileName(serverUrl);
    final file = File(path.join(_audioCacheDir!.path, fileName));
    
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  /// 下载音频文件到本地
  /// [serverUrl] 服务器音频URL（可以是相对路径或绝对路径）
  /// [onProgress] 下载进度回调 (0.0 - 1.0)
  /// 返回本地文件路径
  Future<String> downloadAudio(
    String serverUrl, {
    Function(double progress)? onProgress,
  }) async {
    await _ensureCacheDir();

    // 检查是否已缓存
    final cachedPath = await getLocalFilePath(serverUrl);
    if (cachedPath != null) {
      return cachedPath;
    }

    // 获取完整URL
    final fullUrl = _getFullUrl(serverUrl);
    final fileName = _getLocalFileName(serverUrl);
    final localFile = File(path.join(_audioCacheDir!.path, fileName));

    try {
      // 发起下载请求
      final request = http.Request('GET', Uri.parse(fullUrl));
      final streamedResponse = await http.Client().send(request);

      if (streamedResponse.statusCode != 200) {
        throw Exception('Download failed: ${streamedResponse.statusCode}');
      }

      final contentLength = streamedResponse.contentLength ?? 0;
      final fileSink = localFile.openWrite();
      int downloadedBytes = 0;

      // 流式下载并更新进度
      await streamedResponse.stream.listen(
        (chunk) {
          fileSink.add(chunk);
          downloadedBytes += chunk.length;
          
          if (contentLength > 0 && onProgress != null) {
            final progress = downloadedBytes / contentLength;
            onProgress(progress.clamp(0.0, 1.0));
          }
        },
        onDone: () {
          fileSink.close();
          if (onProgress != null) {
            onProgress(1.0);
          }
        },
        onError: (error) {
          fileSink.close();
          localFile.deleteSync(); // 删除不完整的文件
          throw Exception('Download error: $error');
        },
        cancelOnError: true,
      ).asFuture();

      return localFile.path;
    } catch (e) {
      // 如果下载失败，尝试删除可能创建的不完整文件
      if (await localFile.exists()) {
        await localFile.delete();
      }
      throw Exception('Download audio error: $e');
    }
  }

  /// 删除本地缓存的音频文件
  Future<bool> deleteCachedFile(String serverUrl) async {
    await _ensureCacheDir();
    final fileName = _getLocalFileName(serverUrl);
    final file = File(path.join(_audioCacheDir!.path, fileName));
    
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  /// 清除所有缓存的音频文件
  Future<void> clearCache() async {
    await _ensureCacheDir();
    
    if (await _audioCacheDir!.exists()) {
      final files = _audioCacheDir!.listSync();
      for (var file in files) {
        if (file is File) {
          await file.delete();
        }
      }
    }
  }

  /// 获取缓存目录大小（字节）
  Future<int> getCacheSize() async {
    await _ensureCacheDir();
    
    if (!await _audioCacheDir!.exists()) {
      return 0;
    }

    int totalSize = 0;
    final files = _audioCacheDir!.listSync();
    for (var file in files) {
      if (file is File) {
        totalSize += await file.length();
      }
    }
    return totalSize;
  }

  /// 下载 titles 文件到本地
  /// [audioUrl] 音频文件URL，用于生成对应的 titles URL
  /// 返回本地文件路径，如果下载失败返回 null
  Future<String?> downloadTitles(String audioUrl) async {
    try {
      await _ensureCacheDir();
      
      // 生成 titles URL（将音频文件扩展名替换为 .titles）
      String titlesUrl = audioUrl.replaceAll(RegExp(r'\.(mp3|wav|m4a|ogg|aac|flac)$'), '.titles');
      
      // 获取完整URL
      final fullUrl = _getFullUrl(titlesUrl);
      
      // 生成本地文件名
      final uri = Uri.parse(titlesUrl);
      final segments = uri.pathSegments;
      String fileName;
      if (segments.isNotEmpty) {
        final lastSegment = segments.last;
        if (lastSegment.isNotEmpty && lastSegment.contains('.')) {
          fileName = lastSegment.replaceAll(RegExp(r'\.(mp3|wav|m4a|ogg|aac|flac)$'), '.titles');
        } else {
          fileName = 'titles_${titlesUrl.hashCode.abs()}.titles';
        }
      } else {
        fileName = 'titles_${titlesUrl.hashCode.abs()}.titles';
      }
      
      final localFile = File(path.join(_audioCacheDir!.path, fileName));
      
      // 检查是否已缓存
      if (await localFile.exists()) {
        return localFile.path;
      }
      
      // 下载文件
      final response = await http.get(Uri.parse(fullUrl));
      
      if (response.statusCode == 200) {
        await localFile.writeAsBytes(response.bodyBytes);
        return localFile.path;
      } else {
        // titles 文件不存在是正常的（某些音频可能没有 titles）
        return null;
      }
    } catch (e) {
      // titles 文件不存在是正常的，不抛出异常
      print('Download titles error (may not exist): $e');
      return null;
    }
  }

  /// 获取 titles 文件的本地路径（如果已缓存）
  /// [audioUrl] 音频文件URL
  /// 返回本地文件路径，如果不存在返回 null
  Future<String?> getTitlesLocalPath(String audioUrl) async {
    try {
      await _ensureCacheDir();
      
      // 生成 titles URL
      String titlesUrl = audioUrl.replaceAll(RegExp(r'\.(mp3|wav|m4a|ogg|aac|flac)$'), '.titles');
      
      // 生成本地文件名
      final uri = Uri.parse(titlesUrl);
      final segments = uri.pathSegments;
      String fileName;
      if (segments.isNotEmpty) {
        final lastSegment = segments.last;
        if (lastSegment.isNotEmpty && lastSegment.contains('.')) {
          fileName = lastSegment.replaceAll(RegExp(r'\.(mp3|wav|m4a|ogg|aac|flac)$'), '.titles');
        } else {
          fileName = 'titles_${titlesUrl.hashCode.abs()}.titles';
        }
      } else {
        fileName = 'titles_${titlesUrl.hashCode.abs()}.titles';
      }
      
      final localFile = File(path.join(_audioCacheDir!.path, fileName));
      
      if (await localFile.exists()) {
        return localFile.path;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

