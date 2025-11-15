/// 数据模型
/// 用户模型
class UserModel {
  final int id;
  final String username;
  final DateTime createdAt;
  final String language;

  UserModel({
    required this.id,
    required this.username,
    required this.createdAt,
    required this.language,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      createdAt: DateTime.parse(json['created_at']),
      language: json['language'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'created_at': createdAt.toIso8601String(),
      'language': language,
    };
  }
}

/// 文件模型
class FileModel {
  final int id;
  final int userId;
  final String type;
  final String originalName;
  final int size;
  final DateTime uploadTime;
  final String status;
  final String? resultText;

  FileModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.originalName,
    required this.size,
    required this.uploadTime,
    required this.status,
    this.resultText,
  });

  factory FileModel.fromJson(Map<String, dynamic> json) {
    return FileModel(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'],
      originalName: json['original_name'],
      size: json['size'],
      uploadTime: DateTime.parse(json['upload_time']),
      status: json['status'],
      resultText: json['result_text'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'original_name': originalName,
      'size': size,
      'upload_time': uploadTime.toIso8601String(),
      'status': status,
      'result_text': resultText,
    };
  }
}

/// 历史记录模型
class HistoryModel {
  final int id;
  final int userId;
  final int fileId;
  final String voiceType;
  final String audioUrl;
  final DateTime createdAt;
  bool isFavorite;
  final FileModel? file;

  HistoryModel({
    required this.id,
    required this.userId,
    required this.fileId,
    required this.voiceType,
    required this.audioUrl,
    required this.createdAt,
    required this.isFavorite,
    this.file,
  });

  // 便捷方法：获取文件名
  String? get fileName => file?.originalName;
  
  // 便捷方法：获取文本内容
  String? get resultText => file?.resultText;

  factory HistoryModel.fromJson(Map<String, dynamic> json) {
    return HistoryModel(
      id: json['id'],
      userId: json['user_id'],
      fileId: json['file_id'],
      voiceType: json['voice_type'],
      audioUrl: json['audio_url'],
      createdAt: DateTime.parse(json['created_at']),
      isFavorite: json['is_favorite'] ?? false,
      file: json['file'] != null ? FileModel.fromJson(json['file']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'file_id': fileId,
      'voice_type': voiceType,
      'audio_url': audioUrl,
      'created_at': createdAt.toIso8601String(),
      'is_favorite': isFavorite,
      'file': file?.toJson(),
    };
  }
}

/// 语音类型模型
class VoiceTypeModel {
  final String id;
  final String name;
  final String language;
  final String gender;
  final String previewUrl;
  final String description;

  VoiceTypeModel({
    required this.id,
    required this.name,
    required this.language,
    required this.gender,
    required this.previewUrl,
    required this.description,
  });

  factory VoiceTypeModel.fromJson(Map<String, dynamic> json) {
    // 辅助函数：确保值是字符串类型
    String ensureString(dynamic value, [String defaultValue = '']) {
      if (value == null) return defaultValue;
      if (value is String) return value;
      if (value is List && value.isNotEmpty) {
        return value.first.toString();
      }
      return value.toString();
    }

    return VoiceTypeModel(
      id: ensureString(json['id']),
      name: ensureString(json['name']),
      language: ensureString(json['language']),
      gender: ensureString(json['gender']),
      previewUrl: ensureString(json['preview_url']),
      description: ensureString(json['description']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'language': language,
      'gender': gender,
      'preview_url': previewUrl,
      'description': description,
    };
  }
}
