import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../services/localization_service.dart';
import '../models/models.dart';
import 'package:audioplayers/audioplayers.dart';

/// 音频播放页面
/// 基于 Figma 设计的播放界面
class AudioPlayerPage extends StatefulWidget {
  final HistoryModel history;

  const AudioPlayerPage({
    Key? key,
    required this.history,
  }) : super(key: key);

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> with SingleTickerProviderStateMixin {
  final AudioService _audioService = AudioService();
  
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  PlayerState _playerState = PlayerState.stopped;
  bool _isLoading = true;
  
  // 用于文本滚动
  final ScrollController _scrollController = ScrollController();
  AnimationController? _textAnimationController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _setupListeners();
    _textAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() => _isLoading = true);
      
      // 使用断点续播功能
      await _audioService.playWithResume(
        widget.history.audioUrl,
        widget.history.id,
      );
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _setupListeners() {
    _audioService.stateStream.listen((state) {
      if (mounted) {
        setState(() => _playerState = state);
      }
    });

    _audioService.positionStream.listen((position) {
      if (mounted) {
        setState(() => _currentPosition = position);
      }
    });

    _audioService.durationStream.listen((duration) {
      if (mounted) {
        setState(() => _totalDuration = duration);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textAnimationController?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context)!;
    
    // Figma 设计的颜色
    final backgroundColor = isDark 
        ? const Color(0xFF191815) // rgb(25, 24, 21)
        : const Color(0xFFEEEFDF); // rgb(238, 239, 223)
    
    final foregroundColor = isDark
        ? const Color(0xFFF1EEE3) // rgb(241, 238, 227)
        : const Color(0xFF191815);
    
    final accentColor = isDark
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
              // Header - 基于 Figma 设计
              _buildHeader(foregroundColor, accentColor, localizations),
              
              // Content - 文本显示区域
              Expanded(
                child: _buildContentArea(foregroundColor),
              ),
              
              // Footer - 控制区域
              _buildFooter(foregroundColor, accentColor, localizations),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建顶部标题栏
  Widget _buildHeader(Color foregroundColor, Color accentColor, AppLocalizations localizations) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 返回按钮
          _buildCircleButton(
            icon: Icons.arrow_back,
            color: accentColor,
            foregroundColor: foregroundColor,
            onTap: () => Navigator.of(context).pop(),
          ),
          
          // 章节信息
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.history.fileName ?? 'Audio',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: accentColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          
          // 更多选项按钮
          _buildCircleButton(
            icon: Icons.more_horiz,
            color: accentColor,
            foregroundColor: foregroundColor,
            onTap: () => _showMoreOptions(localizations),
          ),
        ],
      ),
    );
  }

  /// 构建圆形按钮
  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required Color foregroundColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: foregroundColor,
          size: 24,
        ),
      ),
    );
  }

  /// 构建文本显示区域
  Widget _buildContentArea(Color foregroundColor) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    }

    // 显示文件内容或占位文本
    final displayText = widget.history.resultText ?? _getPlaceholderText();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: foregroundColor,
            height: 1.8,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  String _getPlaceholderText() {
    return 'Call me Ishmael. Some years ago--never mind how long precisely--having little or no money in my purse, and nothing particular to interest me on shore, I thought I would sail about a little and see the watery part of the world...';
  }

  /// 构建底部控制区域
  Widget _buildFooter(Color foregroundColor, Color accentColor, AppLocalizations localizations) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          _buildProgressBar(foregroundColor, accentColor),
          
          const SizedBox(height: 24),
          
          // 播放控制按钮
          _buildPlayControls(foregroundColor, accentColor, localizations),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 构建进度条
  Widget _buildProgressBar(Color foregroundColor, Color accentColor) {
    return Column(
      children: [
        // 进度条
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: accentColor,
            inactiveTrackColor: accentColor.withOpacity(0.3),
            thumbColor: accentColor,
            overlayColor: accentColor.withOpacity(0.2),
          ),
          child: Slider(
            value: _totalDuration.inMilliseconds > 0
                ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
                : 0.0,
            onChanged: (value) {
              final position = Duration(
                milliseconds: (value * _totalDuration.inMilliseconds).round(),
              );
              _audioService.seek(position);
            },
          ),
        ),
        
        // 时间显示
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_currentPosition),
                style: TextStyle(
                  fontSize: 12,
                  color: foregroundColor.withOpacity(0.7),
                ),
              ),
              Text(
                _formatDuration(_totalDuration),
                style: TextStyle(
                  fontSize: 12,
                  color: foregroundColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建播放控制按钮
  Widget _buildPlayControls(Color foregroundColor, Color accentColor, AppLocalizations localizations) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 后退15秒
        IconButton(
          onPressed: () {
            final newPosition = _currentPosition - const Duration(seconds: 15);
            _audioService.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
          },
          icon: Icon(Icons.replay_outlined, color: accentColor, size: 32),
        ),
        
        const SizedBox(width: 32),
        
        // 播放/暂停按钮
        GestureDetector(
          onTap: () async {
            if (_playerState == PlayerState.playing) {
              await _audioService.pause();
            } else {
              await _audioService.play(
                widget.history.audioUrl,
                historyId: widget.history.id,
              );
            }
          },
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              _playerState == PlayerState.playing ? Icons.pause : Icons.play_arrow,
              color: foregroundColor,
              size: 36,
            ),
          ),
        ),
        
        const SizedBox(width: 32),
        
        // 快进15秒
        IconButton(
          onPressed: () {
            final newPosition = _currentPosition + const Duration(seconds: 15);
            _audioService.seek(newPosition > _totalDuration ? _totalDuration : newPosition);
          },
          icon: Icon(Icons.forward_outlined, color: accentColor, size: 32),
        ),
      ],
    );
  }

  /// 显示更多选项
  void _showMoreOptions(AppLocalizations localizations) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final backgroundColor = isDark ? const Color(0xFF191815) : const Color(0xFFEEEFDF);
        final foregroundColor = isDark ? const Color(0xFFF1EEE3) : const Color(0xFF191815);
        
        return Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: foregroundColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                
                _buildOptionItem(
                  icon: Icons.speed,
                  title: localizations.translate('playback_speed'),
                  foregroundColor: foregroundColor,
                  onTap: () {
                    Navigator.pop(context);
                    _showSpeedOptions(localizations);
                  },
                ),
                
                _buildOptionItem(
                  icon: Icons.bookmark_border,
                  title: localizations.translate('add_to_favorites'),
                  foregroundColor: foregroundColor,
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: 实现收藏功能
                  },
                ),
                
                _buildOptionItem(
                  icon: Icons.share,
                  title: localizations.translate('share'),
                  foregroundColor: foregroundColor,
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: 实现分享功能
                  },
                ),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required Color foregroundColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: foregroundColor),
      title: Text(
        title,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
    );
  }

  /// 显示播放速度选项
  void _showSpeedOptions(AppLocalizations localizations) {
    // TODO: 实现播放速度调整
  }
}
