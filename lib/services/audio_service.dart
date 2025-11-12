import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

/// 音频服务类
/// 管理音频播放、暂停、停止等功能
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // 状态流
  final StreamController<PlayerState> _stateController = StreamController<PlayerState>.broadcast();
  Stream<PlayerState> get stateStream => _stateController.stream;
  
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  Stream<Duration> get positionStream => _positionController.stream;
  
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  Stream<Duration> get durationStream => _durationController.stream;

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String? _currentUrl;

  AudioService._internal() {
    _initializeListeners();
  }

  void _initializeListeners() {
    // 监听播放状态
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _stateController.add(state);
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

  /// 播放音频
  Future<void> play(String url) async {
    try {
      if (_currentUrl != url) {
        await _audioPlayer.stop();
        _currentUrl = url;
        await _audioPlayer.play(UrlSource(url));
      } else {
        await _audioPlayer.resume();
      }
    } catch (e) {
      throw Exception('Play error: $e');
    }
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
      await _audioPlayer.stop();
      _currentUrl = null;
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
      throw Exception('Set volume error: $e');
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

  /// 是否正在播放
  bool get isPlaying => _audioPlayer.state == PlayerState.playing;

  /// 释放资源
  void dispose() {
    _audioPlayer.dispose();
    _stateController.close();
    _positionController.close();
    _durationController.close();
  }
}
