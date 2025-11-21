import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../widgets/liquid_glass_card.dart';
import '../widgets/voice_card_widget.dart';

/// 语音库页面 - 基于 referPhoto/yuyinku.json 设计
class VoiceLibraryPage extends StatefulWidget {
  const VoiceLibraryPage({Key? key}) : super(key: key);

  @override
  State<VoiceLibraryPage> createState() => _VoiceLibraryPageState();
}

class _VoiceLibraryPageState extends State<VoiceLibraryPage> {
  final ApiService _apiService = ApiService();
  final AudioService _audioService = AudioService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<VoiceTypeModel> _voices = [];
  List<VoiceTypeModel> _filteredVoices = [];
  String _activeFilter = 'all';
  bool _isLoading = false;
  String? _versionTag; // 存储当前版本标签
  String? _loadingPreviewVoiceId; // 当前正在加载试听的 voice id

  // 缓存过滤结果，避免重复计算
  String _lastSearchKeyword = '';
  String _lastFilter = '';

  // 基础语言标签 - 添加普通话、粤语、英文、其他分类
  static const Map<String, String> _baseLanguageLabels = {
    'all': 'All',
    'mandarin': '普通话',
    'cantonese': '粤语',
    'english': 'English',
    'other': '其他',
  };

  @override
  void initState() {
    super.initState();
    _initializeVoices();
    _searchController.addListener(_applyFilters);
  }

  // 初始化语音库：进入app时同步
  Future<void> _initializeVoices() async {
    // 从本地存储读取版本标签
    final prefs = await SharedPreferences.getInstance();
    _versionTag = prefs.getString('voice_library_version_tag');
    // 读取本地缓存的声线数据（如果存在）
    final cached = prefs.getString('voice_library_data');
    if (cached != null && cached.isNotEmpty) {
      try {
        final List<dynamic> arr = jsonDecode(cached);
        final List<VoiceTypeModel> cachedVoices = arr.map((e) => VoiceTypeModel.fromJson(Map<String, dynamic>.from(e))).toList();
        if (cachedVoices.isNotEmpty) {
          setState(() {
            _voices = cachedVoices;
            _filteredVoices = cachedVoices;
          });
        }
      } catch (e) {
        print('[VoiceLibrary] Failed to load cached voices: $e');
      }
    }
    
    // 同步检查（进入app时）
    await _syncVoices();
  }

  // 同步语音库：检查数量，如果不同则获取完整数据
  Future<void> _syncVoices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('[VoiceLibrary] Syncing voices, version_tag: $_versionTag');
      
      // 先检查数量
      final checkResult = await _apiService.checkVoiceTypesCount(
        versionTag: _versionTag,
      );
      
      if (!mounted) return;
      
      final bool needsUpdate = checkResult['needs_update'] ?? true;
      final String? newVersionTag = checkResult['version_tag'];
      final int serverCount = checkResult['count'] ?? 0;
      
      print('[VoiceLibrary] Count check - needs_update: $needsUpdate, server_count: $serverCount, local_count: ${_voices.length}');
      
      // 如果数量相同，不需要更新
      if (!needsUpdate && _voices.isNotEmpty) {
        print('[VoiceLibrary] Count match, no update needed');
        // 更新版本标签（可能格式有变化但数量相同）
        if (newVersionTag != null && newVersionTag != _versionTag) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('voice_library_version_tag', newVersionTag);
          _versionTag = newVersionTag;
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // 如果数量不同或没有本地数据，获取完整数据
      print('[VoiceLibrary] Count mismatch or no local data, fetching full voice list...');
      final result = await _apiService.getVoiceTypes(
        language: _activeFilter == 'all' ? null : _activeFilter,
        versionTag: null, // 不传版本标签，强制获取完整数据
      );
      
      if (!mounted) return;
      
      final List<VoiceTypeModel> voices = result['voices'] ?? [];
      final String? finalVersionTag = result['version_tag'];
      
      print('[VoiceLibrary] Received ${voices.length} voices, version_tag: $finalVersionTag');
      
      // 保存新版本标签
      if (finalVersionTag != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('voice_library_version_tag', finalVersionTag);
        _versionTag = finalVersionTag;
      }
      // 将完整声线列表缓存到本地（以便离线或快速启动使用）
      try {
        final prefs = await SharedPreferences.getInstance();
        final List<Map<String, dynamic>> serialized = voices.map((v) => v.toJson()).toList();
        await prefs.setString('voice_library_data', jsonEncode(serialized));
        print('[VoiceLibrary] Cached ${serialized.length} voices to local storage');
      } catch (e) {
        print('[VoiceLibrary] Failed to cache voices locally: $e');
      }
      
      setState(() {
        _voices = voices;
        // 先更新过滤列表，再更新_lastFilter
        _filteredVoices = voices;
        _lastFilter = _activeFilter;
      });
      // 应用过滤（即使条件相同也要执行，因为_voices可能刚更新）
      _applyFilters(force: true);
    } catch (e) {
      if (!mounted) return;
      print('[VoiceLibrary] Error syncing voices: $e');
      // 如果同步失败，尝试加载本地缓存的数据
      if (_voices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing voices: $e')),
      );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 刷新语音库（手动刷新时调用）
  Future<void> _loadVoices() async {
    await _syncVoices();
  }

  void _applyFilters({bool force = false}) {
    final keyword = _searchController.text.trim().toLowerCase();
    
    // 如果搜索关键词和筛选器都没变，且不是强制更新，不重新计算
    if (!force && keyword == _lastSearchKeyword && _activeFilter == _lastFilter) {
      return;
    }

    _lastSearchKeyword = keyword;
    _lastFilter = _activeFilter;
    
    print('[VoiceLibrary] Applying filters - keyword: "$keyword", filter: $_activeFilter, voices count: ${_voices.length}');
    
    // 过滤逻辑：
    // 1. 只显示有 description 的声音
    // 2. 根据语言分类过滤
    // 3. 根据搜索关键词过滤
    final filtered = _voices.where((voice) {
        // 1. 过滤掉没有 description 的声音
        if (voice.description.isEmpty) {
          return false;
        }
        
        // 2. 语言过滤
        if (_activeFilter != 'all') {
          final voiceLanguage = _classifyLanguageFromVoiceId(voice.voiceId);
          if (voiceLanguage != _activeFilter) {
            return false;
          }
        }
        
        // 3. 关键词过滤
        final matchesKeyword = keyword.isEmpty ||
            voice.name.toLowerCase().contains(keyword) ||
            voice.description.toLowerCase().contains(keyword) ||
            voice.voiceId.toLowerCase().contains(keyword);
        
        return matchesKeyword;
      }).toList();

    print('[VoiceLibrary] Filtered voices count: ${filtered.length}');

    if (mounted) {
      setState(() {
        _filteredVoices = filtered;
      });
    }
  }

  // 从 voice_id 分类语言：Mandarin/Cantonese/English/Other
  String _classifyLanguageFromVoiceId(String voiceId) {
    final lowerVoiceId = voiceId.toLowerCase();
    
    // 检查是否包含 "chinese (mandarin)" 或 "mandarin"
    if (lowerVoiceId.contains('chinese (mandarin)') || 
        lowerVoiceId.contains('mandarin')) {
      return 'mandarin';
    }
    
    // 检查是否包含 "cantonese"
    if (lowerVoiceId.contains('cantonese')) {
      return 'cantonese';
    }
    
    // 检查是否包含 "english"
    if (lowerVoiceId.contains('english')) {
      return 'english';
    }
    // 其他语言
    return 'other';
  }
  
  void _onVoiceSelected(VoiceTypeModel voice) {
    // 选中即确认，直接返回
    Navigator.pop(context, voice);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF191815)
        : const Color(0xFFEEEFDF);
    final textColor = isDark
        ? const Color(0xFFF1EEE3)
        : const Color(0xFF272536);
    const accentColor = Color(0xFF3742D7);
    
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
              // 固定头部区域
              Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
              children: [
                _buildHeader(textColor),
                const SizedBox(height: 24),
                _buildSearchBar(textColor),
                const SizedBox(height: 16),
                _buildFilterChips(textColor, accentColor),
                const SizedBox(height: 20),
                  ],
                ),
              ),
              // 可滚动的列表区域
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadVoices,
                  color: accentColor,
                  backgroundColor: backgroundColor,
                  child: _isLoading
                      ? _buildLoadingPlaceholder(textColor)
                      : _buildVoiceList(textColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: textColor,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '语音库',
                style: TextStyle(
                  color: textColor,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '选择您喜欢的声音',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.graphic_eq,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(Color textColor) {
    return StatefulBuilder(
      builder: (context, setState) {
    return LiquidGlassCard(
      borderRadius: 22,
      backgroundColor: textColor.withValues(alpha: 0.05),
      child: Row(
        children: [
          Icon(Icons.search, color: textColor.withValues(alpha: 0.6)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: textColor),
                  onChanged: (value) {
                    setState(() {}); // 更新清除按钮的显示状态
                    _applyFilters();
                  },
              decoration: InputDecoration(
                hintText: '搜索',
                border: InputBorder.none,
                isCollapsed: true,
                hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
                    setState(() {}); // 更新清除按钮的显示状态
                _applyFilters();
              },
              icon: Icon(Icons.close, color: textColor.withValues(alpha: 0.6)),
            ),
        ],
      ),
        );
      },
    );
  }

  Widget _buildFilterChips(Color textColor, Color accentColor) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _baseLanguageLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final key = _baseLanguageLabels.keys.elementAt(index);
          final label = _baseLanguageLabels[key]!;
          final isActive = _activeFilter == key;
          return ChoiceChip(
            label: Text(label),
            selected: isActive,
            onSelected: (selected) {
              if (!selected) return;
              setState(() {
                _activeFilter = key;
              });
              // 应用过滤而不是重新加载
              _applyFilters(force: true);
            },
            labelStyle: TextStyle(
              color: isActive ? Colors.white : textColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: textColor.withValues(alpha: 0.06),
            selectedColor: accentColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingPlaceholder(Color textColor) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: LiquidGlassCard(
          backgroundColor: textColor.withValues(alpha: 0.05),
          child: SizedBox(
              height: 77, // 与实际 card 高度一致
            child: Row(
              children: [
                Container(
                    width: 36,
                    height: 36,
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                          width: 120,
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 12,
                        width: 160,
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  Widget _buildVoiceList(Color textColor) {
    if (_filteredVoices.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          LiquidGlassCard(
      backgroundColor: textColor.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(
                Icons.voice_over_off,
                color: textColor.withValues(alpha: 0.5),
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'No voices available',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
          ),
        ],
      );
    }

    // 使用 ListView.builder 进行懒加载，只渲染可见的 item
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filteredVoices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      // 添加缓存范围，提高滚动性能
      cacheExtent: 500,
      itemBuilder: (context, index) {
        final voice = _filteredVoices[index];
        // 使用 RepaintBoundary 减少重绘
        return RepaintBoundary(
          child: VoiceCardWidget(
            key: ValueKey('${voice.id}-${voice.model ?? ''}'), // 使用稳定的 key（包含id和model以确保唯一性）
          voice: voice,
            isSelected: false, // 移除选中状态，因为选中即确认
            onTap: () => _onVoiceSelected(voice),
            onPreview: () => _previewVoice(voice),
            isLoading: _loadingPreviewVoiceId == voice.id,
          ),
        );
      },
    );
  }

  Future<void> _previewVoice(VoiceTypeModel voice) async {
    // Prevent multiple clicks
    if (_loadingPreviewVoiceId != null) return;

    setState(() {
      _loadingPreviewVoiceId = voice.id;
    });

    try {
      // 检查 voice 是否有 preview_url
      if (voice.previewUrl.isEmpty) {
        // 没有试听URL，提示用户
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('试听音频尚未生成，请稍后再试'),
            duration: Duration(seconds: 2),
          ),
        );
        print('[VoiceLibrary] No preview_url for ${voice.voiceId}');
        return;
      }

      // 构建完整URL
      final previewUrl = voice.previewUrl.startsWith('http')
          ? voice.previewUrl
          : '${_apiService.baseUrl}${voice.previewUrl}';
      
      print('[VoiceLibrary] Playing preview: $previewUrl');
      
      // 播放试听音频
      await _audioService.play(previewUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('播放失败: $e')),
      );
      print('[VoiceLibrary] Preview playback failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingPreviewVoiceId = null;
        });
      }
    }
  }
}
