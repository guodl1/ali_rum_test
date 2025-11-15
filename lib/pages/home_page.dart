import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';
import 'audio_player_page.dart';

/// 主页 - 严格按照 home-structure.json 设计
/// 参考 home.svg 的视觉效果
class HomePage extends StatefulWidget {
  final Function(Locale)? onLanguageChange;
  final VoidCallback? onNavigateToUpload;

  const HomePage({Key? key, this.onLanguageChange, this.onNavigateToUpload}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  final DateFormat _dateLabelFormat = DateFormat('MM-dd');
  final DateFormat _timeFormat = DateFormat('HH:mm');

  List<HistoryModel> _history = [];
  bool _isLoading = false;
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final history = await _apiService.getHistory(pageSize: 20);
      if (!mounted) return;

      setState(() {
        _history = history;
        _isLoading = false;
        _hasLoadedOnce = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasLoadedOnce = true;
      });
    }
  }

  Map<String, List<HistoryModel>> _groupHistory(List<HistoryModel> items, AppLocalizations localizations) {
    final Map<String, List<HistoryModel>> grouped = {};
    final now = DateTime.now();

    for (final history in items) {
      final created = history.createdAt;
      String label;

      if (_isSameDay(created, now)) {
        label = localizations.translate('today');
      } else if (_isSameDay(created, now.subtract(const Duration(days: 1)))) {
        label = localizations.translate('yesterday');
      } else {
        label = _dateLabelFormat.format(created);
      }

      grouped.putIfAbsent(label, () => []).add(history);
    }

    return grouped;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 严格按照 home-structure.json 的背景色 rgb(238, 239, 223)
    final backgroundColor = isDark
        ? const Color(0xFF191815)
        : const Color(0xFFEEEFDF); // rgb(238, 239, 223)

    final textColor = isDark
        ? const Color(0xFFF1EEE3)
        : const Color(0xFF191815);

    final localizations = AppLocalizations.of(context)!;
    final groupedHistory = _groupHistory(_history, localizations);

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
              // 顶部标题栏 - 参考 home-structure.json 的 title frame (343x48)
              _buildTopBar(textColor),
              
              // 内容区域 - 历史记录列表
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadHistory,
                  color: const Color(0xFF3742D7),
                  backgroundColor: backgroundColor,
                  child: _isLoading && !_hasLoadedOnce
                      ? _buildLoadingState(textColor)
                      : groupedHistory.isEmpty
                          ? _buildEmptyState(textColor, localizations)
                          : ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              children: [
                                ...groupedHistory.entries.expand((entry) {
                                  final label = entry.key;
                                  final items = entry.value;
                                  return [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          color: textColor.withValues(alpha: 0.6),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    ...items.map(
                                      (history) => _buildHistoryCard(history, textColor),
                                    ),
                                  ];
                                }),
                              ],
                            ),
                ),
              ),
              
              // 底部导航栏 - 参考 home-structure.json 的 nav frame (345x81)
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部标题栏 - 参考 home-structure.json title frame
  /// 左侧：头像 (48x48)，右侧：加号按钮 (48x48)
  Widget _buildTopBar(Color textColor) {
    return Container(
      width: 343,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧头像 - frame-34078 (48x48)
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9), // rgb(217, 217, 217)
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person,
              color: textColor,
            ),
          ),
          // 右侧加号按钮 - plus frame (48x48)
        GestureDetector(
          onTap: () {
            // 使用和bottom bar一样的导航方式
            if (widget.onNavigateToUpload != null) {
              widget.onNavigateToUpload!();
            }
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        ],
      ),
    );
  }

  /// 历史记录卡片 - 参考 home-structure.json 的 rounded-rectangle (307x77)
  Widget _buildHistoryCard(HistoryModel history, Color textColor) {
    return Container(
      width: 307,
      height: 77,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E1C4), // rgb(232, 225, 196)
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // 左侧：时间和播放源
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 时间标签
                  Text(
                    _timeFormat.format(history.createdAt),
                    style: const TextStyle(
                      color: Color(0xFF716161), // rgb(113, 97, 97)
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 播放声音源
                  Text(
                    history.voiceType,
                    style: const TextStyle(
                      color: Color(0xFF716161),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // 标题
                  Text(
                    history.file?.originalName ?? 'title',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 右侧：播放图标
            GestureDetector(
              onTap: () => _openAudioPlayer(history),
              child: Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF757575), // rgb(117, 117, 117)
                    width: 4,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  size: 16,
                  color: Color(0xFF757575),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildLoadingState(Color textColor) {
    return Center(
      child: CircularProgressIndicator(
        color: textColor,
      ),
    );
  }

  Widget _buildEmptyState(Color textColor, AppLocalizations localizations) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            color: textColor.withValues(alpha: 0.5),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            localizations.translate('no_recent_history'),
            style: TextStyle(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAudioPlayer(HistoryModel history) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AudioPlayerPage(history: history),
      ),
    );
    if (mounted) {
      _loadHistory();
    }
  }
}
