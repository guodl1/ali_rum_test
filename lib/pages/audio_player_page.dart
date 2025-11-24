import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../services/audio_service.dart';
import '../services/api_service.dart';
import '../services/local_history_service.dart';
import '../models/models.dart';
import '../models/titles_model.dart';
import 'package:audioplayers/audioplayers.dart';
import '../widgets/waveform_visualizer.dart';

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
  final ApiService _apiService = ApiService();
  final LocalHistoryService _localHistoryService = LocalHistoryService();
  
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  PlayerState _playerState = PlayerState.stopped;
  bool _isLoading = true;
  
  // 用于文本滚动
  final ScrollController _scrollController = ScrollController();
  AnimationController? _textAnimationController;
  
  // Titles 数据
  List<TitleSegment> _titlesSegments = [];
  int? _currentSegmentIndex; // 当前正在播放的段落索引
  bool _titlesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadTitles();
    _initializePlayer();
    _setupListeners();
    _textAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );
  }

  /// 加载 titles 文件
  Future<void> _loadTitles() async {
    try {
      // 根据 audio_url 推断 titles_url
      final audioUrl = widget.history.audioUrl;
      if (audioUrl.isEmpty) return;
      
      String titlesJson;
      
      // 检查是否是本地文件路径
      if (!audioUrl.startsWith('http://') && !audioUrl.startsWith('https://')) {
        // 本地文件路径，尝试从本地文件系统读取
        try {
          final titlesPath = audioUrl.replaceAll(RegExp(r'\.(mp3|wav|m4a|ogg|aac|flac)$'), '.titles');
          final titlesFile = File(titlesPath);
          
          if (await titlesFile.exists()) {
            titlesJson = await titlesFile.readAsString();
      } else {
            // 本地文件不存在，使用普通文本显示
            if (mounted) {
              setState(() {
                _titlesLoaded = true;
              });
            }
            return;
          }
        } catch (e) {
          // 读取本地文件失败，使用普通文本显示
          print('Failed to read local titles file: $e');
          if (mounted) {
            setState(() {
              _titlesLoaded = true;
            });
          }
          return;
        }
      } else {
        // 服务器 URL，从服务器下载
        String titlesUrl = audioUrl.replaceAll(RegExp(r'\.(mp3|wav|m4a|ogg|aac|flac)$'), '.titles');

      final baseUrl = _apiService.baseUrl;
      final fullUrl = titlesUrl.startsWith('http') ? titlesUrl : '$baseUrl$titlesUrl';
      
      final response = await http.get(Uri.parse(fullUrl)).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
          titlesJson = utf8.decode(response.bodyBytes);
        } else {
          // titles 文件不存在，使用普通文本显示
          if (mounted) {
            setState(() {
              _titlesLoaded = true;
            });
          }
          return;
        }
      }
      
      // 解析 titles JSON
        final segments = TitlesParser.parseTitles(titlesJson);
        
        if (mounted) {
          setState(() {
            _titlesSegments = segments;
            _titlesLoaded = true;
          });
      }
    } catch (e) {
      // titles 文件不存在或加载失败，使用普通文本显示
      print('Failed to load titles file: $e');
      if (mounted) {
        setState(() {
          _titlesLoaded = true;
        });
      }
    }
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
        setState(() {
          _currentPosition = position;
          // 根据当前播放位置更新高亮的段落
          _updateCurrentSegment(position);
        });
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
              _buildHeader(foregroundColor, accentColor),
              
              // Content - 文本显示区域
              Expanded(
                child: _buildContentArea(foregroundColor, backgroundColor),
              ),
              
              // Waveform Visualizer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      _formatDuration(_currentPosition),
                      style: TextStyle(
                        fontSize: 12,
                        color: foregroundColor.withOpacity(0.5),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: WaveformVisualizer(
                          isPlaying: _playerState == PlayerState.playing,
                          color: foregroundColor,
                          barCount: 40,
                        ),
                      ),
                    ),
                    Text(
                      _formatDuration(_totalDuration),
                      style: TextStyle(
                        fontSize: 12,
                        color: foregroundColor.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),

              // 进度条和时间显示
              _buildProgressBar(foregroundColor, accentColor),
              
              // const SizedBox(height: 16),
              
              // Footer - 控制区域（Nav）
              _buildFooter(foregroundColor, accentColor),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建顶部标题栏（参考 Header.svg 和 header-structure.json）
  Widget _buildHeader(Color foregroundColor, Color accentColor) {
    // 根据 header-structure.json: 宽度 343, 高度 48, gap 91
    // 左侧：48x48 圆形按钮（返回）
    // 中间：157x22 章节信息（"1 Chapter - Loomings"格式，gap 6）
    // 右侧：48x48 圆形按钮（更多选项）
    return Container(
      width: 343,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧返回按钮 - group-1 (48x48)
          _buildCircleButton(
            icon: Icons.arrow_back,
            color: const Color(0xFF191815), // rgb(25, 24, 21)
            foregroundColor: const Color(0xFFF1EEE3), // rgb(241, 238, 227)
            onTap: () => Navigator.of(context).pop(),
          ),
          
          // 中间章节信息 - frame-34104 (gap 6)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // "1 Chapter -" (Arial, 16px, 400)
                  Text(
                    '1 Chapter -',
                    style: TextStyle(
                      fontFamily: 'Arial',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: foregroundColor,
                    ),
                  ),
                  const SizedBox(width: 6), // gap 6
                  // 章节名称 (Albra, 16px, 500)
                  Flexible(
                    child: Text(
                      widget.history.fileName ?? 'Audio',
                      style: TextStyle(
                        fontFamily: 'Albra',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: foregroundColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 右侧更多选项按钮 - group-2 (48x48)
          _buildCircleButton(
            icon: Icons.more_horiz,
            color: const Color(0xFF191815), // rgb(25, 24, 21)
            foregroundColor: const Color(0xFFF1EEE3), // rgb(241, 238, 227)
            onTap: _showMoreOptions,
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

  /// 构建文本显示区域（支持 titles 高亮）
  Widget _buildContentArea(Color foregroundColor, Color backgroundColor) {
    Widget content;
    if (_isLoading) {
      content = Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    } else if (_titlesSegments.isNotEmpty) {
      // 如果有 titles 数据，使用段落高亮显示
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80), // Add padding for fade area
            child: _buildTitlesContent(foregroundColor),
          ),
        ),
      );
    } else {
      // 普通文本显示
      final displayText = _getDisplayText();
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80), // Add padding for fade area
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
        ),
      );
    }

    return Stack(
      children: [
        content,
        // Bottom fade-out gradient
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 80,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    backgroundColor.withOpacity(0.0),
                    backgroundColor,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建带高亮的 titles 内容
  Widget _buildTitlesContent(Color foregroundColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _titlesSegments.asMap().entries.map((entry) {
        final index = entry.key;
        final segment = entry.value;
        final isCurrent = index == _currentSegmentIndex;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            segment.text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: isCurrent ? Colors.red : foregroundColor,
              height: 1.8,
              letterSpacing: 0.3,
              backgroundColor: isCurrent ? Colors.red.withOpacity(0.1) : Colors.transparent,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getPlaceholderText() {
    return 'Call me Ishmael. Some years ago--never mind how long precisely--having little or no money in my purse, and nothing particular to interest me on shore, I thought I would sail about a little and see the watery part of the world...';
  }

  /// 滚动到当前播放的段落
  void _scrollToCurrentSegment() {
    if (_currentSegmentIndex == null || _titlesSegments.isEmpty) return;
    if (!_scrollController.hasClients) return;

    // 根据段落索引计算滚动位置
    // 每个段落大约占用一定高度（考虑 padding 和 line height）
    const double segmentHeight = 50.0; // 估算每个段落的高度（包括 padding 和 line height）
    final scrollOffset = _currentSegmentIndex! * segmentHeight;
    
    if (scrollOffset <= _scrollController.position.maxScrollExtent) {
      _scrollController.animateTo(
        scrollOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// 根据当前播放位置更新高亮的段落
  void _updateCurrentSegment(Duration position) {
    if (_titlesSegments.isEmpty) return;
    
    final positionMs = position.inMilliseconds.toDouble();
    int? newIndex;
    
    for (int i = 0; i < _titlesSegments.length; i++) {
      final segment = _titlesSegments[i];
      if (positionMs >= segment.timeBegin && positionMs <= segment.timeEnd) {
        newIndex = i;
        break;
      }
    }
    
    if (newIndex != _currentSegmentIndex) {
      setState(() {
        _currentSegmentIndex = newIndex;
      });
      
      // 如果段落改变，自动滚动到当前段落
      if (newIndex != null) {
        _scrollToCurrentSegment();
      }
    }
  }

  /// 获取显示的文本
  String _getDisplayText() {
    if (_titlesSegments.isNotEmpty) {
      return TitlesParser.getFullText(_titlesSegments);
    }
    return widget.history.resultText ?? _getPlaceholderText();
  }

  /// 构建底部控制区域（参考 Nav.svg 和 nav-structure.json）
  Widget _buildFooter(Color foregroundColor, Color accentColor) {
    // 根据 Nav.svg: 宽度 343, 高度 81, 圆角 40.5
    // 左侧：后退按钮（卡带图标样式）
    // 中间：播放按钮（红色圆形，带白色播放图标）
    // 右侧：前进按钮和设置按钮
    return Container(
      width: 343,
      height: 81,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF191815), // rgb(25, 24, 21)
        borderRadius: BorderRadius.circular(40.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 左侧：后退15秒按钮（卡带图标样式，参考 Nav.svg）
          _buildNavButton(
            icon: Icons.replay_10,
            onTap: () {
              final newPosition = _currentPosition - const Duration(seconds: 15);
              _audioService.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
            },
            color: const Color(0xFFA5A296), // stroke color #A5A296
          ),
          
          // 中间：播放/暂停按钮（红色圆形，参考 Nav.svg）
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
              width: 53,
              height: 53,
              decoration: const BoxDecoration(
                color: Color(0xFFE06065), // rgb(224, 96, 101) - 红色
                shape: BoxShape.circle,
              ),
              child: Icon(
                _playerState == PlayerState.playing ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          
          // 右侧：快进15秒按钮（参考 Nav.svg）
              _buildNavButton(
                icon: Icons.forward_10,
                onTap: () {
                  final newPosition = _currentPosition + const Duration(seconds: 15);
                  _audioService.seek(newPosition > _totalDuration ? _totalDuration : newPosition);
                },
                color: const Color(0xFFA5A296),
          ),
        ],
      ),
    );
  }

  /// 构建导航按钮（参考 Nav.svg 中的按钮样式）
  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Icon(
          icon,
          color: color,
          size: 20,
        ),
      ),
    );
  }

  /// 构建进度条（参考 Nav.svg 中的时间显示）
  Widget _buildProgressBar(Color foregroundColor, Color accentColor) {
    // Nav.svg 中显示了时间格式 "10:25 / 43:17"
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 当前时间 - 参考 SVG 中的样式（F1EEE3 颜色）
          Text(
            _formatDuration(_currentPosition),
            style: TextStyle(
              fontSize: 16,
              color: const Color(0xFFF1EEE3), // rgb(241, 238, 227)
              fontWeight: FontWeight.w400,
            ),
          ),
          // 分隔符和总时长
          Text(
            ' / ${_formatDuration(_totalDuration)}',
            style: TextStyle(
              fontSize: 16,
              color: const Color(0xFFF1EEE3).withOpacity(0.7),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  /// 显示更多选项
void _showMoreOptions() {
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
                title: '播放速度',
                foregroundColor: foregroundColor,
                onTap: () {
                  Navigator.pop(context);
                  _showSpeedOptions();
                },
              ),
              
              _buildOptionItem(
                icon: widget.history.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                title: widget.history.isFavorite ? '取消收藏' : '添加到收藏',
                foregroundColor: foregroundColor,
                onTap: () async {
                  Navigator.pop(context);
                  await _toggleFavorite();
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
void _showSpeedOptions() {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final backgroundColor = isDark ? const Color(0xFF191815) : const Color(0xFFEEEFDF);
      final foregroundColor = isDark ? const Color(0xFFF1EEE3) : const Color(0xFF191815);
      
      final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
      
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
              
              ...speeds.map((speed) => _buildOptionItem(
                icon: Icons.speed,
                title: '${speed}x',
                foregroundColor: foregroundColor,
                onTap: () async {
                  Navigator.pop(context);
                  await _audioService.setPlaybackRate(speed);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('播放速度已设置为 ${speed}x'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              )),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    },
  );
}

  /// 切换收藏状态
  Future<void> _toggleFavorite() async {
    final newFavoriteState = !widget.history.isFavorite;
    await _localHistoryService.toggleFavorite(widget.history.id, newFavoriteState);
    setState(() {
      widget.history.isFavorite = newFavoriteState;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.history.isFavorite ? '已添加到收藏' : '已取消收藏'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
}
