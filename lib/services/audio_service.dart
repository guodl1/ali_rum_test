import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'audio_download_service.dart';

/// 音频服务类
/// 管理音频播放、暂停、停止等功能，支持断点续播
/// 音频文件会先下载到本地，然后从本地播放
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioDownloadService _downloadService = AudioDownloadService();
  
  // 状态流
  final StreamController<PlayerState> _stateController = StreamController<PlayerState>.broadcast();
  Stream<PlayerState> get stateStream => _stateController.stream;
  
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  Stream<Duration> get positionStream => _positionController.stream;
  
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  Stream<Duration> get durationStream => _durationController.stream;

  // 下载进度流
  final StreamController<double> _downloadProgressController = StreamController<double>.broadcast();
  Stream<double> get downloadProgressStream => _downloadProgressController.stream;

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String? _currentUrl; // 服务器URL
  String? _currentLocalPath; // 本地文件路径
  int? _currentHistoryId; // 当前播放的历史记录ID
  
  // 自动保存进度的定时器
  Timer? _progressSaveTimer;
  static const String _progressKey = 'audio_playback_progress';

  AudioService._internal() {
    _initializeListeners();
    _startAutoSaveProgress();
  }

  void _initializeListeners() {
    // 监听播放状态
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _stateController.add(state);
      
      // 播放完成时清除进度
      if (state == PlayerState.completed) {
        _clearProgress();
      }
    });

    // 监听播放位置
    _audioPlayer.onPositionChanged.listen((position) {
      _currentPosition = position;
      _positionController.add(position);
    });

    // 监听总时长
    _audioPlayer.onDurationChanged.listen((duration) {
      _totalDuration = duration;
      _durationController.add(duration);
    });
  }

  /// 开始自动保存播放进度（每5秒保存一次）
  void _startAutoSaveProgress() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_audioPlayer.state == PlayerState.playing) {
        _saveProgress();
      }
    });
  }

  /// 保存播放进度到本地
  Future<void> _saveProgress() async {
    if (_currentUrl == null || _currentHistoryId == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressData = {
        'url': _currentUrl,
        'historyId': _currentHistoryId,
        'position': _currentPosition.inMilliseconds,
        'duration': _totalDuration.inMilliseconds,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_progressKey, jsonEncode(progressData));
    } catch (e) {
      print('Save progress error: $e');
    }
  }

  /// 获取保存的播放进度
  Future<Map<String, dynamic>?> getSavedProgress(int historyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressJson = prefs.getString(_progressKey);
      if (progressJson == null) return null;
      
      final progressData = jsonDecode(progressJson) as Map<String, dynamic>;
      
      // 只返回匹配的历史记录进度
      if (progressData['historyId'] == historyId) {
        return progressData;
      }
      return null;
    } catch (e) {
      print('Get saved progress error: $e');
      return null;
    }
  }

  /// 清除播放进度
  Future<void> _clearProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_progressKey);
      _currentHistoryId = null;
    } catch (e) {
      print('Clear progress error: $e');
    }
  }

  /// 播放音频，支持从保存的进度恢复
  /// [url] 服务器音频URL（可以是相对路径或绝对路径）
  /// [historyId] 历史记录ID，用于保存播放进度
  /// [resumePosition] 恢复播放的位置
  /// [onDownloadProgress] 下载进度回调 (0.0 - 1.0)
  Future<void> play(
    String url, {
    int? historyId,
    Duration? resumePosition,
    Function(double progress)? onDownloadProgress,
  }) async {
    try {
      if (_currentUrl != url) {
        await _audioPlayer.stop();
        _currentUrl = url;
        _currentHistoryId = historyId;
        
        // 先检查本地是否已有缓存
        String localPath;
        final cachedPath = await _downloadService.getLocalFilePath(url);
        
        if (cachedPath != null) {
          // 使用缓存的本地文件
          localPath = cachedPath;
          _currentLocalPath = localPath;
          if (onDownloadProgress != null) {
            onDownloadProgress(1.0); // 已缓存，进度为100%
          }
        } else {
          // 下载音频文件到本地
          localPath = await _downloadService.downloadAudio(
            url,
            onProgress: (progress) {
              _downloadProgressController.add(progress);
              if (onDownloadProgress != null) {
                onDownloadProgress(progress);
              }
            },
          );
          _currentLocalPath = localPath;
        }
        
        // 使用本地文件路径播放
        await _audioPlayer.play(DeviceFileSource(localPath));
        
        // 如果有恢复位置，跳转到该位置
        if (resumePosition != null && resumePosition > Duration.zero) {
          await Future.delayed(const Duration(milliseconds: 500)); // 等待音频加载
          await seek(resumePosition);
        }
      } else {
        await _audioPlayer.resume();
      }
    } catch (e) {
      throw Exception('Play error: $e');
    }
  }

  /// 播放并自动恢复进度
  /// [url] 服务器音频URL
  /// [historyId] 历史记录ID
  /// [onDownloadProgress] 下载进度回调 (0.0 - 1.0)
  Future<void> playWithResume(
    String url,
    int historyId, {
    Function(double progress)? onDownloadProgress,
  }) async {
    final savedProgress = await getSavedProgress(historyId);
    Duration? resumePosition;
    
    if (savedProgress != null) {
      final position = savedProgress['position'] as int;
      final duration = savedProgress['duration'] as int;
      
      // 如果播放进度小于95%，则恢复播放位置
      if (duration > 0 && (position / duration) < 0.95) {
        resumePosition = Duration(milliseconds: position);
      }
    }
    
    await play(
      url,
      historyId: historyId,
      resumePosition: resumePosition,
      onDownloadProgress: onDownloadProgress,
    );
  }

  /// 暂停播放
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      throw Exception('Pause error: $e');
    }
  }

  /// 停止播放
  Future<void> stop() async {
    try {
      await _saveProgress(); // 停止前保存进度
      await _audioPlayer.stop();
      _currentUrl = null;
      _currentLocalPath = null;
      _currentPosition = Duration.zero;
    } catch (e) {
      throw Exception('Stop error: $e');
    }
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      throw Exception('Seek error: $e');
    }
  }

  /// 设置音量 (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer.setVolume(volume);
    } catch (e) {
      print('Error setting volume: $e');
    }
  }

  /// 设置播放速度 (0.5 - 2.0)
  Future<void> setPlaybackRate(double rate) async {
    try {
      await _audioPlayer.setPlaybackRate(rate);
    } catch (e) {
      print('Error setting playback rate: $e');
    }
  }

  /// 获取当前播放状态
  PlayerState get currentState => _audioPlayer.state;

  /// 获取当前位置
  Duration get currentPosition => _currentPosition;

  /// 获取总时长
  Duration get totalDuration => _totalDuration;

  /// 当前播放的URL
  String? get currentUrl => _currentUrl;

  /// 当前播放的历史记录ID
  int? get currentHistoryId => _currentHistoryId;

  /// 是否正在播放
  bool get isPlaying => _audioPlayer.state == PlayerState.playing;

  /// 获取指定历史记录的播放进度百分比
  Future<double> getProgressPercentage(int historyId) async {
    final savedProgress = await getSavedProgress(historyId);
    if (savedProgress == null) return 0.0;
    
    final position = savedProgress['position'] as int;
    final duration = savedProgress['duration'] as int;
    
    if (duration <= 0) return 0.0;
    return (position / duration).clamp(0.0, 1.0);
  }

  /// 获取当前本地文件路径
  String? get currentLocalPath => _currentLocalPath;

  /// 释放资源
  void dispose() {
    _progressSaveTimer?.cancel();
    _saveProgress(); // 释放前保存最后的进度
    _audioPlayer.dispose();
    _stateController.close();
    _positionController.close();
    _durationController.close();
    _downloadProgressController.close();
  }
}
