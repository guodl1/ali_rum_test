import 'dart:io';
import 'package:path/path.dart' as path;
import '../config/api_keys.dart';

/// 文件服务类
/// 管理文件验证、读取和处理
class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  /// 验证文件大小
  bool validateFileSize(File file) {
    final fileSize = file.lengthSync();
    return fileSize <= ApiKeys.maxFileSize;
  }

  /// 验证文件类型
  bool validateFileType(File file) {
    final ext = path.extension(file.path).toLowerCase();
    return ApiKeys.supportedImageTypes.contains(ext) ||
           ApiKeys.supportedDocTypes.contains(ext);
  }

  /// 获取文件类型
  String getFileType(File file) {
    final ext = path.extension(file.path).toLowerCase();
    
    if (ApiKeys.supportedImageTypes.contains(ext)) {
      return 'image';
    } else if (ext == '.pdf') {
      return 'pdf';
    } else if (ext == '.docx') {
      return 'docx';
    } else if (ext == '.txt') {
      return 'txt';
    } else if (ext == '.epub') {
      return 'epub';
    }
    
    return 'unknown';
  }

  /// 读取文本文件内容
  Future<String?> readTextFile(File file) async {
    try {
      final ext = path.extension(file.path).toLowerCase();
      
      if (ext == '.txt') {
        return await file.readAsString();
      }
      
      // 其他文件类型需要特殊处理
      // TODO: 实现 PDF、DOCX、EPUB 的文本提取
      return null;
    } catch (e) {
      throw Exception('Read file error: $e');
    }
  }

  /// 获取文件信息
  Map<String, dynamic> getFileInfo(File file) {
    return {
      'name': path.basename(file.path),
      'size': file.lengthSync(),
      'type': getFileType(file),
      'extension': path.extension(file.path),
      'path': file.path,
    };
  }

  /// 格式化文件大小
  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }
}
