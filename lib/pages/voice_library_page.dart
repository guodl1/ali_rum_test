import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/system_tts_service.dart';
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
  final SystemTTSService _systemTtsService = SystemTTSService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<VoiceTypeModel> _voices = [];
  List<VoiceTypeModel> _filteredVoices = [];
  String _activeFilter = 'all';
  String _selectedTier = 'free'; // 'free', 'basic', 'premium'
  bool _isLoading = false;
  String? _versionTagBasic; // 存储 Basic 版本标签
  String? _versionTagPremium; // 存储 Premium 版本标签
  String? _loadingPreviewVoiceId; // 当前正在加载试听的 voice id

  // 缓存过滤结果，避免重复计算
  String _lastSearchKeyword = '';
  String _lastFilter = '';
  String _lastTier = '';

  // 基础语言标签 - 添加普通话、粤语、英文、其他分类
  static const Map<String, String> _baseLanguageLabels = {
    'all': 'All',
    'mandarin': '普通话',
    'cantonese': '粤语',
    'english': 'English',
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
    _versionTagBasic = prefs.getString('voice_library_version_tag_basic');
    _versionTagPremium = prefs.getString('voice_library_version_tag_premium');
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
      print('[VoiceLibrary] Syncing voices');
      

      

      final currentTier = _selectedTier;
      String? currentVersionTag;
      if (currentTier == 'basic') currentVersionTag = _versionTagBasic;
      else if (currentTier == 'premium') currentVersionTag = _versionTagPremium;

      print('[VoiceLibrary] Syncing voices for tier: $currentTier, version_tag: $currentVersionTag');
      
      List<VoiceTypeModel> voices = [];

      if (currentTier == 'free') {
        // Free tier: System TTS
        voices = await _systemTtsService.getVoices();
      } else if (currentTier == 'basic' || currentTier == 'premium') {
        // Basic/Premium tier: Fetch from API with tier parameter
        
        // 1. Check count/version first
        final checkResult = await _apiService.checkVoiceTypesCount(
          versionTag: currentVersionTag,
          tier: currentTier,
        );
        
        if (!mounted) return;
        
        final bool needsUpdate = checkResult['needs_update'] ?? true;
        final String? newVersionTag = checkResult['version_tag'];
        
        // If no update needed, try to load from local cache (if we have logic for per-tier cache, 
        // but currently we only have one global cache file in the code structure shown previously.
        // To support per-tier offline cache properly, we should split the cache key.
        // For now, let's just fetch if needsUpdate is true, or if _voices is empty/wrong tier.
        
        // Simplified logic: If needs update OR current voices are empty OR current voices don't match tier
        
        // Let's try to fetch if needsUpdate.
        if (needsUpdate) {
           print('[VoiceLibrary] Update needed for tier $currentTier');
           final result = await _apiService.getVoiceTypes(
            language: _activeFilter == 'all' ? null : _activeFilter,
            versionTag: null, // Force fetch
            tier: currentTier,
          );
          voices = result['voices'] ?? [];
          final String? finalVersionTag = result['version_tag'];
          
          // Update version tag
          if (finalVersionTag != null) {
            final prefs = await SharedPreferences.getInstance();
            if (currentTier == 'basic') {
              _versionTagBasic = finalVersionTag;
              await prefs.setString('voice_library_version_tag_basic', finalVersionTag);
            } else {
              _versionTagPremium = finalVersionTag;
              await prefs.setString('voice_library_version_tag_premium', finalVersionTag);
            }
          }
          
          // Cache voices locally (per tier)
          try {
            final prefs = await SharedPreferences.getInstance();
            final List<Map<String, dynamic>> serialized = voices.map((v) => v.toJson()).toList();
            await prefs.setString('voice_library_data_$currentTier', jsonEncode(serialized));
          } catch (e) {
            print('[VoiceLibrary] Failed to cache voices: $e');
          }
        } else {
          print('[VoiceLibrary] No update needed for tier $currentTier, loading from cache');
          // Load from cache
          final prefs = await SharedPreferences.getInstance();
          final cached = prefs.getString('voice_library_data_$currentTier');
          if (cached != null) {
             final List<dynamic> arr = jsonDecode(cached);
             voices = arr.map((e) => VoiceTypeModel.fromJson(Map<String, dynamic>.from(e))).toList();
          } else {
            // Fallback to fetch if cache missing
            final result = await _apiService.getVoiceTypes(
              language: _activeFilter == 'all' ? null : _activeFilter,
              tier: currentTier,
            );
            voices = result['voices'] ?? [];
          }
        }
      }
      
      if (!mounted) return;
      
      // Double check we are still on the same tier (async race condition)
      if (_selectedTier != currentTier) return;
      
      print('[VoiceLibrary] Received ${voices.length} voices for tier $currentTier');
      
      setState(() {
        _voices = voices;
        _filteredVoices = voices;
        _lastFilter = _activeFilter;
        _lastTier = _selectedTier;
      });
      // 应用过滤
      _applyFilters(force: true);
      
      // 滚动到上次选中的位置
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedVoice();
      });
    } catch (e) {
      if (!mounted) return;
      print('[VoiceLibrary] Error syncing voices: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading voices: $e')),
      );
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
    
    // 如果搜索关键词、筛选器和层级都没变，且不是强制更新，不重新计算
    if (!force && keyword == _lastSearchKeyword && _activeFilter == _lastFilter && _selectedTier == _lastTier) {
      return;
    }

    _lastSearchKeyword = keyword;
    _lastFilter = _activeFilter;
    _lastTier = _selectedTier;
    
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
        final voiceLanguage = _classifyLanguage(voice);
        
        // 始终过滤掉 'other' 语言
        if (voiceLanguage == 'other') {
          return false;
        }

        if (_activeFilter != 'all') {
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

  // 根据 voice 信息分类语言
  String _classifyLanguage(VoiceTypeModel voice) {
    // 1. 优先使用 language 字段判断
    final lang = voice.language.toLowerCase();
    if (lang.startsWith('zh')) {
      if (lang.contains('hk') || lang.contains('cantonese')) {
        return 'cantonese';
      }
      return 'mandarin';
    }
    if (lang.startsWith('en')) {
      return 'english';
    }

    // 2. 如果 language 字段不明确，回退到使用 ID 判断 (兼容旧逻辑)
    final lowerVoiceId = voice.voiceId.toLowerCase();
    
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
    
    return 'other';
  }
  
  Future<void> _onVoiceSelected(VoiceTypeModel voice) async {
    // 保存选中的 voice id
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_selected_voice_id', voice.id);
    
    if (!mounted) return;
    // 选中即确认，直接返回
    Navigator.pop(context, voice);
  }

  // 滚动到上次选中的位置
  Future<void> _scrollToSelectedVoice() async {
    final prefs = await SharedPreferences.getInstance();
    final lastVoiceId = prefs.getString('last_selected_voice_id');
    
    if (lastVoiceId != null && _filteredVoices.isNotEmpty) {
      final index = _filteredVoices.indexWhere((v) => v.id == lastVoiceId);
      if (index != -1) {
        // 延时一小段时间确保列表已渲染
        await Future.delayed(const Duration(milliseconds: 300));
        if (_scrollController.hasClients) {
          // 估算高度：每个 item 约 100 (card) + 12 (separator)
          // 这里的 100 是估计值，LiquidGlassCard 内容高度约为 70-80 + padding
          const double estimatedItemHeight = 110.0; 
          final double offset = index * estimatedItemHeight;
          
          // 确保不超过最大滚动范围
          final maxScroll = _scrollController.position.maxScrollExtent;
          final targetOffset = offset > maxScroll ? maxScroll : offset;
          
          _scrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
      }
    }
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
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                // 固定头部区域
                Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                children: [
                  _buildHeader(textColor),
                  const SizedBox(height: 16),
                  _buildSegmentedControl(textColor, accentColor),
                  const SizedBox(height: 16),
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
                    backgroundColor: Colors.transparent,
                    child: _isLoading
                        ? _buildLoadingPlaceholder(textColor)
                        : _buildVoiceList(textColor),
                  ),
                ),
              ],
            ),
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
        // const SizedBox(width: 16),
        // Container(
        //   width: 45,
        //   height: 45,
        //   decoration: BoxDecoration(
        //     color: textColor.withValues(alpha: 0.1),
        //     shape: BoxShape.circle,
        //   ),
        //   child: Icon(
        //     Icons.graphic_eq,
        //     color: textColor,
        //   ),
        // ),
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

  Widget _buildSegmentedControl(Color textColor, Color accentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildSegmentItem('Free', 'free', textColor, accentColor),
          _buildSegmentItem('Basic', 'basic', textColor, accentColor),
          _buildSegmentItem('Premium', 'premium', textColor, accentColor),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(String label, String value, Color textColor, Color accentColor) {
    final isSelected = _selectedTier == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedTier != value) {
            setState(() {
              _selectedTier = value;
            });
            _loadVoices();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.black : textColor.withValues(alpha: 0.6),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
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
      // 检查 voice 是否有 preview_url (Free tier might not have one, but we handle it)
      if (_selectedTier == 'free') {
        // System TTS preview
        await _systemTtsService.preview(
          '晚上好啊.', 
          voice.name, 
          voice.language
        );
        return;
      }

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
