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
  final String voiceName;
  final String audioUrl;
  final DateTime createdAt;
  bool isFavorite;
  final int? duration; // Duration in seconds
  final FileModel? file;

  HistoryModel({
    required this.id,
    required this.userId,
    required this.fileId,
    required this.voiceType,
    required this.voiceName,
    required this.audioUrl,
    required this.createdAt,
    required this.isFavorite,
    this.duration,
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
      voiceName: json['voice_name'] ?? json['voice_type'], // 兼容旧数据
      audioUrl: json['audio_url'],
      createdAt: DateTime.parse(json['created_at']),
      isFavorite: json['is_favorite'] ?? false,
      duration: json['duration'],
      file: json['file'] != null ? FileModel.fromJson(json['file']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'file_id': fileId,
      'voice_type': voiceType,
      'voice_name': voiceName,
      'audio_url': audioUrl,
      'created_at': createdAt.toIso8601String(),
      'is_favorite': isFavorite,
      'duration': duration,
      'file': file?.toJson(),
    };
  }
}

/// 语音类型模型（符合指南.md 8.13规范）
class VoiceTypeModel {
  final String id; // 客户端本地唯一 Key，等于 voiceId
  final String voiceId; // 服务端的 voiceId（保持一致）
  final String name; // 语音名称
  final String language; // 语言（如 zh-CN、en-US）
  final String gender; // 性别（如 male、female）
  final String previewUrl; // 试听链接
  final String description; // 描述文本
  final String? provider; // 供应商（如 minimax / openai / deepseek）
  final String? model; // 所属模型（如 speech-01、gpt-4o-mini-tts）
  final String? voiceType; // 语音类型（如 normal、emotion、clone）

  VoiceTypeModel({
    required this.id,
    required this.voiceId,
    required this.name,
    required this.language,
    required this.gender,
    required this.previewUrl,
    required this.description,
    this.provider,
    this.model,
    this.voiceType,
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

    // id 和 voice_id 应该保持一致，如果只有 id 则使用 id 作为 voice_id
    final voiceId = ensureString(json['voice_id'] ?? json['id']);
    final id = ensureString(json['id'] ?? voiceId);

    return VoiceTypeModel(
      id: id,
      voiceId: voiceId,
      name: ensureString(json['name']),
      language: ensureString(json['language']),
      gender: ensureString(json['gender']),
      previewUrl: ensureString(json['preview_url']),
      description: ensureString(json['description']),
      provider: json.containsKey('provider') ? ensureString(json['provider']) : null,
      model: json.containsKey('model') ? ensureString(json['model']) : null,
      voiceType: json.containsKey('voice_type') ? ensureString(json['voice_type']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'voice_id': voiceId,
      'name': name,
      'language': language,
      'gender': gender,
      'preview_url': previewUrl,
      'description': description,
      if (provider != null) 'provider': provider,
      if (model != null) 'model': model,
      if (voiceType != null) 'voice_type': voiceType,
    };
  }
}
