import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/localization_service.dart';
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

  // 缓存过滤结果，避免重复计算
  String _lastSearchKeyword = '';
  String _lastFilter = '';

  // 基础语言标签
  static const Map<String, String> _baseLanguageLabels = {
    'all': 'All',
    'zh': '中文',
    'en': 'English',
  };
  
  // 动态语言标签（从云端声线中提取）
  Map<String, String> _languageLabels = Map.from(_baseLanguageLabels);
  
  // 语言代码到显示名称的映射（支持基础语言代码和完整语言代码）
  static const Map<String, String> _languageCodeToName = {
    'zh': '中文',
    'zh-cn': '中文',
    'zh-tw': '繁體中文',
    'en': 'English',
    'en-us': 'English (US)',
    'en-gb': 'English (UK)',
    'ja': '日本語',
    'ko': '한국어',
    'fr': 'Français',
    'de': 'Deutsch',
    'es': 'Español',
    'it': 'Italiano',
    'pt': 'Português',
    'ru': 'Русский',
    'ar': 'العربية',
    'th': 'ไทย',
    'vi': 'Tiếng Việt',
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
      
      // 从声线中提取所有唯一的语言代码，并更新语言标签
      _updateLanguageLabels(voices);
      
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
    
    print('[VoiceLibrary] Applying filters - keyword: "$keyword", voices count: ${_voices.length}');
    
    // 使用 compute 在后台线程进行过滤，避免阻塞 UI
    final filtered = _voices.where((voice) {
        final matchesKeyword = keyword.isEmpty ||
            voice.name.toLowerCase().contains(keyword) ||
            voice.description.toLowerCase().contains(keyword);
        return matchesKeyword;
      }).toList();

    print('[VoiceLibrary] Filtered voices count: ${filtered.length}');

    if (mounted) {
      setState(() {
        _filteredVoices = filtered;
      });
    }
  }

  // 从语言代码中提取基础语言代码（如 zh-CN -> zh）
  String _extractBaseLanguage(String language) {
    if (language.isEmpty) return language;
    // 提取语言代码的前缀部分（如 zh-CN -> zh, en-US -> en）
    final parts = language.split('-');
    return parts[0].toLowerCase();
  }

  // 从声线列表中提取语言代码并更新语言标签
  void _updateLanguageLabels(List<VoiceTypeModel> voices) {
    // 提取所有唯一的语言代码（使用基础语言代码，如 zh-CN -> zh）
    final Set<String> baseLanguages = voices
        .map((v) => _extractBaseLanguage(v.language))
        .where((lang) => lang.isNotEmpty)
        .toSet();
    
    // 更新语言标签映射
    final updatedLabels = Map<String, String>.from(_baseLanguageLabels);
    
    // 为每个基础语言代码添加标签
    for (final lang in baseLanguages) {
      if (lang.isNotEmpty && !updatedLabels.containsKey(lang)) {
        // 使用映射表获取显示名称，如果没有则使用语言代码本身
        final displayName = _languageCodeToName[lang] ?? lang.toUpperCase();
        updatedLabels[lang] = displayName;
        print('[VoiceLibrary] Added language label: $lang -> $displayName');
      }
    }
    
    // 如果语言标签有变化，更新状态
    if (updatedLabels.length != _languageLabels.length ||
        !updatedLabels.keys.every((k) => _languageLabels.containsKey(k) && _languageLabels[k] == updatedLabels[k])) {
      setState(() {
        _languageLabels = updatedLabels;
      });
      print('[VoiceLibrary] Updated language labels: ${_languageLabels.keys.toList()}');
    }
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
    final localizations = AppLocalizations.of(context)!;

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
                _buildHeader(textColor, localizations),
                const SizedBox(height: 24),
                _buildSearchBar(textColor, localizations),
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

  Widget _buildHeader(Color textColor, AppLocalizations localizations) {
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
                localizations.translate('voice_library'),
                style: TextStyle(
                  color: textColor,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                localizations.translate('select_voice'),
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

  Widget _buildSearchBar(Color textColor, AppLocalizations localizations) {
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
                hintText: localizations.translate('search'),
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
        itemCount: _languageLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final key = _languageLabels.keys.elementAt(index);
          final label = _languageLabels[key]!;
          final isActive = _activeFilter == key;
          return ChoiceChip(
            label: Text(label),
            selected: isActive,
            onSelected: (selected) {
              if (!selected) return;
              setState(() {
                _activeFilter = key;
              });
              _loadVoices();
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
          ),
        );
      },
    );
  }

  Future<void> _previewVoice(VoiceTypeModel voice) async {
    try {
      await _audioService.play(voice.previewUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing preview: $e')),
      );
    }
  }
}
