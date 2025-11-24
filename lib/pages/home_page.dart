import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';

import '../services/local_history_service.dart';
import '../widgets/upload_options_dialog.dart';
import 'audio_player_page.dart';
import 'upload_page.dart';
import 'login_page.dart';
import '../widgets/bottom_nav_bar.dart';

/// 主页 - 严格按照 home-structure.json 设计
/// 参考 home.svg 的视觉效果
class HomePage extends StatefulWidget {
  final Function(Locale)? onLanguageChange;

  const HomePage({Key? key, this.onLanguageChange}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  final LocalHistoryService _localHistoryService = LocalHistoryService();
  final DateFormat _dateLabelFormat = DateFormat('MM-dd');
  final DateFormat _timeFormat = DateFormat('HH:mm');

  List<HistoryModel> _history = [];
  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  int _navIndex = 0;
  bool _isProcessingFile = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    // 监听音频状态变化以更新UI
    AudioService().stateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 每次页面显示时检查是否需要刷新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRefreshHistory();
      if (mounted) setState(() {}); // 刷新播放状态
    });
  }

  Future<void> _checkAndRefreshHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final needsRefresh = prefs.getBool('history_needs_refresh') ?? false;
      if (needsRefresh) {
        await prefs.setBool('history_needs_refresh', false);
        await _loadHistory();
        // 刷新后更新UI
        if (mounted) {
          setState(() {});
        }
      }
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 使用本地历史记录服务
      final history = await _localHistoryService.getHistory(pageSize: 20);
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

  Map<String, List<HistoryModel>> _groupHistory(List<HistoryModel> items) {
    final Map<String, List<HistoryModel>> grouped = {};
    final now = DateTime.now();

    for (final history in items) {
      final created = history.createdAt;
      String label;

      if (_isSameDay(created, now)) {
        label = '今天';
      } else if (_isSameDay(created, now.subtract(const Duration(days: 1)))) {
        label = '昨天';
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

  void _showUploadOptionsDialog(BuildContext context) async {
    // 获取上传按钮的位置
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    
    // 计算位置：在按钮下方，右对齐
    final dialogWidth = 240.0; // 降低宽度
    final top = offset.dy + size.height + 8; 
    final left = offset.dx + size.width - dialogWidth; 

    final result = await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent, // 不暗置背景
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            // 点击空白处关闭
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.translucent,
              ),
            ),
            // 对话框定位在上传按钮附近
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: RepaintBoundary(
                  child: UploadOptionsDialog(
                    onOptionSelected: (option, {File? file, List<File>? files, String? text}) {
                      Navigator.pop(context, {
                        'option': option,
                        'file': file,
                        'files': files,
                        'text': text,
                      });
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );

    if (result != null && mounted) {
      final resultMap = result as Map<String, dynamic>;
      final option = resultMap['option'] as String;
      final file = resultMap['file'] as File?;
      final files = resultMap['files'] as List<File>?;
      final textFromDialog = resultMap['text'] as String?;

      // 如果对话框直接返回了已处理的文本（dialog 已完成上传并返回text），直接跳转
      if (textFromDialog != null) {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UploadPage(initialText: textFromDialog),
          ),
        );
        return;
      }

      // 根据选项处理文件
      if (option == 'file' && file != null) {
        final text = await _handleFileUpload(file);
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UploadPage(initialText: text),
          ),
        );
      } else if (option == 'gallery' && files != null && files.isNotEmpty) {
        final text = await _handleImagesUpload(files);
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UploadPage(initialText: text),
          ),
        );
      } else if (option == 'camera' && file != null) {
        final text = await _handleFileUpload(file);
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UploadPage(initialText: text),
          ),
        );
      } else if (option == 'text') {
        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const UploadPage(),
            ),
          );
        }
      } else if (option == 'url') {
        // 弹出输入网址对话框，自动补全 https://
        final urlController = TextEditingController(text: 'https://');
        final submitted = await showDialog<String?>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('输入网址'),
            content: TextField(
              controller: urlController,
              decoration: const InputDecoration(hintText: 'https://example.com'),
              keyboardType: TextInputType.url,
              autofocus: true,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
              TextButton(onPressed: () => Navigator.pop(context, urlController.text.trim()), child: const Text('确定')),
            ],
          ),
        );

        if (submitted != null && submitted.isNotEmpty) {
          // 确保以 https:// 开头
          String normalized = submitted;
          if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
            normalized = 'https://$normalized';
          }
          try {
            setState(() {
              _isProcessingFile = true;
            });
            final resp = await _apiService.submitUrl(url: normalized);
            String? text;
            if (resp['text'] != null && resp['text'].toString().isNotEmpty) {
              text = resp['text'].toString();
            }
            if (!mounted) return;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => UploadPage(initialText: text),
              ),
            );
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('提交网址失败: $e')));
          } finally {
            if (mounted) setState(() { _isProcessingFile = false; });
          }
        }
      }
    }
  }

  Future<String?> _handleFileUpload(File file) async {
    if (!mounted) return null;

    setState(() {
      _isProcessingFile = true;
    });

    try {
      // 判断文件类型
      final ext = file.path.split('.').last.toLowerCase();
      String fileType = 'txt';
      if (['jpg', 'jpeg', 'png', 'bmp'].contains(ext)) {
        fileType = 'image';
      } else if (ext == 'pdf') {
        fileType = 'pdf';
      } else if (['docx', 'doc'].contains(ext)) {
        fileType = 'docx';
      }

      // 上传文件到服务器
      final result = await _apiService.uploadFile(
        file: file,
        fileType: fileType,
      );

      // 保存处理后的文本到SharedPreferences，供upload页读取
      String? extracted;
      if (result['text'] != null && result['text'].toString().isNotEmpty) {
        extracted = result['text'].toString();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('upload_processed_text', extracted);
      }

      // 文件上传成功，文本已处理
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件处理完成')),
        );
      }
      return extracted;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('处理文件失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingFile = false;
        });
      }
    }

    return null;
  }

  Future<String?> _handleImagesUpload(List<File> files) async {
    if (!mounted) return null;

    setState(() {
      _isProcessingFile = true;
    });

    try {
      // 批量上传图片
      final result = await _apiService.uploadImages(files: files);

      String? extracted;
      // 保存处理后的文本到SharedPreferences，供upload页读取
      if (result['text'] != null && result['text'].toString().isNotEmpty) {
        extracted = result['text'].toString();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('upload_processed_text', extracted);
      }

      // 图片处理成功，文本已提取
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('图片处理完成')),
        );
      }
      return extracted;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('处理图片失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingFile = false;
        });
      }
    }

    return null;
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

    final groupedHistory = _groupHistory(_history);

    // 在每次构建后检查是否需要刷新历史（由生成流程设置）
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkHistoryRefresh());

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Stack(
            children: [
              Column(
                children: [
                  // 顶部标题栏 - 参考 home-structure.json 的 title frame (343x48)
                  _buildTopBar(textColor),
                  
                  // 内容区域 - 历史记录列表
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadHistory,
                      color: const Color(0xFF3742D7),
                      backgroundColor: Colors.transparent,
                      child: _isLoading && !_hasLoadedOnce
                          ? _buildLoadingState(textColor)
                          : groupedHistory.isEmpty
                              ? _buildEmptyState(textColor)
                              : ListView(
                                  padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
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
                ],
              ),
              // 底部导航栏
              // Positioned(
              //   bottom: 0,
              //   left: 0,
              //   right: 0,
              //   child: BottomNavBar(
              //     currentIndex: _navIndex,
              //     onTap: (index) {
              //       setState(() {
              //         _navIndex = index;
              //       });
              //       if (index == 1) {
              //         Navigator.of(context).push(
              //           MaterialPageRoute(builder: (context) => const LoginPage()),
              //         ).then((_) {
              //           if (mounted) {
              //             setState(() {
              //               _navIndex = 0;
              //             });
              //           }
              //         });
              //       }
              //     },
              //   ),
              // ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Future<void> _checkHistoryRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final needs = prefs.getBool('history_needs_refresh') ?? false;
      if (needs) {
        await prefs.setBool('history_needs_refresh', false);
        await _loadHistory();
      }
    } catch (e) {
      print('Check history refresh error: $e');
    }
  }

  /// 顶部标题栏 - 参考 home-structure.json title frame
  /// 左侧：头像 (48x48)，右侧：加号按钮 (48x48)
  Widget _buildTopBar(Color textColor) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧头像 - frame-34078 (48x48)，点击跳转到登录页
          GestureDetector(
            onTap: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const LoginPage(),
                ),
              );
              // 如果登录成功，可以在这里更新UI
              if (result == true) {
                // TODO: 更新用户信息显示
              }
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFD9D9D9), // rgb(217, 217, 217)
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: textColor,
              ),
            ),
          ),
          
          // 中间标题
          Text(
            '听阅',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),

          // 右侧加号按钮 - plus frame (48x48)
          Builder(
            builder: (btnContext) {
              return GestureDetector(
                onTap: () {
                  _showUploadOptionsDialog(btnContext);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              );
            }
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(HistoryModel history) async {
    await _localHistoryService.toggleFavorite(history.id, !history.isFavorite);
    _loadHistory();
  }

  Future<void> _deleteHistory(HistoryModel history) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条记录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    if (confirm == true) {
      await _localHistoryService.deleteHistory(history.id);
      _loadHistory();
    }
  }

  Future<void> _handlePlayButtonTap(HistoryModel history) async {
    final audioService = AudioService();
    final isCurrent = audioService.currentHistoryId == history.id;
    
    if (isCurrent) {
      if (audioService.isPlaying) {
        await audioService.pause();
      } else {
        await audioService.play(history.audioUrl, historyId: history.id);
      }
    } else {
      await audioService.playWithResume(history.audioUrl, history.id);
    }
    if (mounted) setState(() {});
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(
          icon,
          size: 20,
          color: color ?? Colors.black54,
        ),
      ),
    );
  }

  /// 历史记录卡片 - 液态玻璃风格
  Widget _buildHistoryCard(HistoryModel history, Color textColor) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 40).clamp(280.0, 600.0);
    
    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: GestureDetector(
            onTap: () => _openAudioPlayer(history), // 点击卡片进入播放页
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Voice Name & Date
                    Row(
                      children: [
                        Icon(Icons.record_voice_over, size: 16, color: textColor.withOpacity(0.6)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            history.voiceName,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(history.createdAt),
                          style: TextStyle(
                            color: textColor.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Middle: Title & Content
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                history.fileName ?? 'Untitled',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (history.resultText != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  history.resultText!,
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 8),
                              // Size and Duration
                              Text(
                                '${_formatSize(history.file?.size ?? 0)} • ${_formatDuration(history.duration ?? 0)}',
                                style: TextStyle(
                                  color: textColor.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Play Button
                        GestureDetector(
                          onTap: () => _handlePlayButtonTap(history), // 点击按钮播放/暂停
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50), // Green
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4CAF50).withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              (AudioService().currentHistoryId == history.id && AudioService().isPlaying)
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    // Bottom Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildActionButton(Icons.download, () {}), // Download placeholder
                        _buildActionButton(Icons.delete_outline, () => _deleteHistory(history)),
                        _buildActionButton(
                          history.isFavorite ? Icons.star : Icons.star_border,
                          () => _toggleFavorite(history),
                          color: history.isFavorite ? Colors.amber : null,
                        ),
                        _buildActionButton(Icons.language, () {}), // Globe placeholder
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
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

  Widget _buildEmptyState(Color textColor) {
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
            '暂无历史记录',
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
      _checkAndRefreshHistory();
    }
  }
}
