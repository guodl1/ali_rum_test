import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

/// 后台音频处理器
/// 桥接 audio_service（提供后台播放和媒体控制）和 audioplayers（实际播放）
class BackgroundAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  
  // 流订阅
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;

  BackgroundAudioHandler() {
    _init();
  }

  void _init() {
    // 监听播放器状态变化并更新 audio_service 状态
    _playerStateSubscription = _player.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      final processingState = _getProcessingState(state);
      
      playbackState.add(playbackState.value.copyWith(
        controls: [
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
        },
        androidCompactActionIndices: const [0],
        processingState: processingState,
        playing: playing,
      ));
    });

    // 监听播放位置
    _positionSubscription = _player.onPositionChanged.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });

    // 监听总时长
    _durationSubscription = _player.onDurationChanged.listen((duration) {
      mediaItem.add(mediaItem.value?.copyWith(
        duration: duration,
      ));
    });

    // 初始化播放状态
    playbackState.add(PlaybackState(
      controls: [MediaControl.play],
      processingState: AudioProcessingState.idle,
      playing: false,
      updatePosition: Duration.zero,
      speed: 1.0,
    ));
  }

  /// 将 audioplayers 状态转换为 audio_service 处理状态
  AudioProcessingState _getProcessingState(PlayerState state) {
    switch (state) {
      case PlayerState.playing:
      case PlayerState.paused:
        return AudioProcessingState.ready;
      case PlayerState.completed:
        return AudioProcessingState.completed;
      case PlayerState.stopped:
        return AudioProcessingState.idle;
      default:
        return AudioProcessingState.idle;
    }
  }

  /// 从本地文件加载音频
  Future<void> loadAudioFromFile(String filePath, MediaItem item) async {
    try {
      mediaItem.add(item);
      await _player.setSource(DeviceFileSource(filePath));
      
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.ready,
      ));
    } catch (e) {
      print('Error loading audio: $e');
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
      ));
    }
  }

  @override
  Future<void> play() async {
    try {
      await _player.resume();
    } catch (e) {
      print('Error playing: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      print('Error pausing: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
        updatePosition: Duration.zero,
      ));
    } catch (e) {
      print('Error stopping: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      print('Error seeking: $e');
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    try {
      await _player.setPlaybackRate(speed);
      playbackState.add(playbackState.value.copyWith(speed: speed));
    } catch (e) {
      print('Error setting speed: $e');
    }
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume);
    } catch (e) {
      print('Error setting volume: $e');
    }
  }

  /// 获取底层 AudioPlayer 实例（用于 AudioService 集成）
  AudioPlayer get player => _player;

  /// 释放资源
  Future<void> dispose() async {
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _player.dispose();
  }
}
