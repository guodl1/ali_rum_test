
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/liquid_glass_card.dart';
import '../widgets/url_input_dialog.dart';
import '../services/file_service.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../services/local_history_service.dart';
import '../services/audio_download_service.dart';
import '../services/usage_stats_service.dart';
import '../models/models.dart';
import 'voice_library_page.dart';
import 'audio_player_page.dart';

enum UploadInteractionMode {
  none,
  urlInput,
  textInput,
  galleryPreview,
  filePreview,
}

/// 响应式尺寸辅助类 - 统一管理跨机型适配
class ResponsiveSizes {
  final BuildContext context;
  late final double screenWidth;
  late final double screenHeight;
  late final double safeHeight; // 减去安全区域后的高度
  late final EdgeInsets safeArea;
  late final bool isSmallScreen;
  late final bool isTablet;
  late final double aspectRatio;
  
  ResponsiveSizes(this.context) {
    final mediaQuery = MediaQuery.of(context);
    screenWidth = mediaQuery.size.width;
    screenHeight = mediaQuery.size.height;
    safeArea = mediaQuery.padding;
    safeHeight = screenHeight - safeArea.top - safeArea.bottom;
    isSmallScreen = safeHeight < 600;
    isTablet = screenWidth > 600;
    aspectRatio = screenHeight / screenWidth;
  }
  
  // 动态间距
  double get tinySpacing => isSmallScreen ? 4.0 : 6.0;
  double get smallSpacing => isSmallScreen ? 8.0 : 12.0;
  double get mediumSpacing => isSmallScreen ? 12.0 : 16.0;
  double get largeSpacing => isSmallScreen ? 16.0 : 24.0;
  double get extraLargeSpacing => isSmallScreen ? 24.0 : 32.0;
  
  // 动态高度
  double get textPreviewHeight {
    // 文本预览占可用高度的 35-45%，根据屏幕大小调整
    if (isSmallScreen) {
      return safeHeight * 0.35;
    } else if (safeHeight > 800) {
      return safeHeight * 0.45;
    } else {
      return safeHeight * 0.4;
    }
  }
  
  double get buttonHeight => isSmallScreen ? 48.0 : 56.0;
  double get iconSize => isSmallScreen ? 20.0 : 24.0;
  double get largeIconSize => isSmallScreen ? 28.0 : 32.0;
  double get imagePreviewHeight => isSmallScreen ? 80.0 : 90.0;
  double get textInputHeight => isSmallScreen ? 180.0 : 220.0;
  
  // 动态字体
  double get titleFontSize => isSmallScreen ? 18.0 : 22.0;
  double get bodyFontSize => isSmallScreen ? 14.0 : 16.0;
  double get smallFontSize => isSmallScreen ? 12.0 : 14.0;
  
  // 动态内边距
  EdgeInsets get horizontalPadding => EdgeInsets.symmetric(
    horizontal: isTablet ? screenWidth * 0.1 : 20,
  );
  
  EdgeInsets get cardPadding => EdgeInsets.all(mediumSpacing);
}

/// 上传页面
class UploadPage extends StatefulWidget {
  final String? initialText;

  const UploadPage({Key? key, this.initialText}) : super(key: key);

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final FileService _fileService = FileService();
  final ApiService _apiService = ApiService();
  final AudioService _audioService = AudioService();
  final LanguageService _languageService = LanguageService();
  final LocalHistoryService _localHistoryService = LocalHistoryService();
  final AudioDownloadService _downloadService = AudioDownloadService();
  final UsageStatsService _usageStatsService = UsageStatsService();
  final TextEditingController _urlController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final ScrollController _textScrollController = ScrollController();

  File? _selectedFile;
  VoiceTypeModel? _selectedVoice;
  bool _isUploading = false;
  double _generateProgress = 0.0; // 生成进度 0.0 - 1.0
  String? _extractedText;
  UploadInteractionMode _interactionMode = UploadInteractionMode.none;
  final TextEditingController _inlineUrlController =
      TextEditingController(text: 'https://');
  final TextEditingController _inlineTextController = TextEditingController();
  List<File> _galleryImages = [];
  static const double _cardHeight = 400;
  bool _showUrlCompleteButton = true;
  bool _showTextCompleteButton = true;
  bool _showPhotoCompleteButton = true;
  // 文本预览可编辑控制器
  final TextEditingController _previewTextController = TextEditingController();
  final FocusNode _previewFocusNode = FocusNode();
  int _playStartIndex = 0; // 文本播放起点（字符索引）
  int _playEndIndex = 0; // 文本播放终点（字符索引，0表示到结尾）

  // 大文本处理
  bool get _isLargeText => (_extractedText?.length ?? 0) > _maxTextLength;
  List<String> _textParts = [];
  static const int _maxTextLength = 50000;
  static const int _splitChunkSize = 30000; // 分段大小，留出余量

  /// 处理提取的文本
  void _processExtractedText(String text) {
    _extractedText = text;
    _textParts.clear();
    
    if (text.length > _maxTextLength) {
      // 大文本模式下，PreviewController 不显示完整文本，避免卡顿
      _previewTextController.text = '文本过长（${text.length}字符），已隐藏预览内容。\n\n点击下方生成按钮开始处理。';
    } else {
      _previewTextController.text = text;
    }

    // 自动检测语言
    final detectedLang = _languageService.detectLanguage(text);
    if (detectedLang != 'unknown') {
      // 如果当前没有选中的语音，或者当前语音语言不匹配，提示用户
      // 这里简单起见，只显示提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('检测到${detectedLang == "zh" ? "中文" : "英文"}内容'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _inlineUrlController.addListener(_onUrlChanged);
    _inlineTextController.addListener(_onTextChanged);
    // 只使用传入的文本，不加载缓存
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      // 延迟到首帧之后再处理，避免在 initState 中访问 InheritedWidget（如 ScaffoldMessenger）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _processExtractedText(widget.initialText!);
      });
    }
    // 尝试加载上次选中的语音（如果有），否则尝试设置一个默认语音
    _loadLastSelectedVoice();
  }

  Future<void> _loadLastSelectedVoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('last_selected_voice');
      if (saved != null && saved.isNotEmpty) {
        final Map<String, dynamic> json = jsonDecode(saved);
        setState(() {
          _selectedVoice = VoiceTypeModel.fromJson(json);
        });
        return;
      }

      // 如果没有保存的选择，尝试从缓存的语音库取第一个作为默认
      final cachedVoices = prefs.getString('voice_library_data');
      if (cachedVoices != null && cachedVoices.isNotEmpty) {
        final List<dynamic> arr = jsonDecode(cachedVoices);
        if (arr.isNotEmpty) {
          final first = VoiceTypeModel.fromJson(Map<String, dynamic>.from(arr.first));
          setState(() {
            _selectedVoice = first;
          });
        }
      }
    } catch (e) {
      // 忽略加载错误，不阻塞 UI
      print('Failed to load last selected voice: $e');
    }
  }


  @override
  void dispose() {
    _inlineUrlController.removeListener(_onUrlChanged);
    _inlineTextController.removeListener(_onTextChanged);
    _inlineUrlController.dispose();
    _inlineTextController.dispose();
    _urlController.dispose();
    _textScrollController.dispose();
    _previewTextController.dispose();
    _previewFocusNode.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    // 当URL输入框内容改变时，显示完成按钮
    if (!_showUrlCompleteButton && _inlineUrlController.text.isNotEmpty) {
      setState(() {
        _showUrlCompleteButton = true;
      });
    }
  }

  void _onTextChanged() {
    // 当文本输入框内容改变时，显示完成按钮
    if (!_showTextCompleteButton && _inlineTextController.text.isNotEmpty) {
      setState(() {
        _showTextCompleteButton = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizes = ResponsiveSizes(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF191815) // rgb(25, 24, 21)
        : const Color(0xFFEEEFDF); // rgb(238, 238, 253)
    
    final textColor = isDark
        ? const Color(0xFFF1EEE3) // rgb(241, 238, 227)
        : const Color(0xFF191815);

    // 保持 controller 与 _extractedText 同步（如果不同步且 _extractedText 有值）
    if (_previewTextController.text != (_extractedText ?? '') && _extractedText != null && _extractedText!.isNotEmpty) {
      _previewTextController.text = _extractedText!;
    }

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/background.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: GestureDetector(
        onTap: () {
          // 点击空白处收起键盘
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
        body: SafeArea(
          // 确保所有内容在安全区域内，底部留出额外空间避免手势条遮挡
          minimum: EdgeInsets.only(
            bottom: sizes.safeArea.bottom > 0 ? 0 : sizes.mediumSpacing,
          ),
          child: Column(
            children: [
              // 返回按钮
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF191815),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFFF1EEE3),
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 主内容区域
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: sizes.isTablet ? sizes.screenWidth * 0.1 : 20,
                    vertical: sizes.smallSpacing,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: sizes.smallSpacing),
                      
                      // 提取的文本预览（可滚动，超出渐隐）
                      _buildTextPreview(sizes),
                      SizedBox(height: sizes.largeSpacing),
                      
                      // 语音选择
                      _buildVoiceSelection(sizes),
                      SizedBox(height: sizes.largeSpacing),
                      
                      // 生成按钮
                      _buildGenerateButton(sizes),
                      
                      // 底部额外间距，确保按钮不被遮挡
                      SizedBox(height: sizes.mediumSpacing),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  /// 基于 upload-structure.json 的上传选项卡片

  Widget _buildVoiceSelection(ResponsiveSizes sizes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Voice',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: sizes.titleFontSize,
              ),
        ),
        SizedBox(height: sizes.smallSpacing),
        LiquidGlassCard(
          onTap: () => _navigateToVoiceLibrary(),
          child: Padding(
            padding: sizes.cardPadding,
            child: Row(
              children: [
                Icon(
                  Icons.record_voice_over,
                  size: sizes.largeIconSize,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: sizes.smallSpacing),
                Expanded(
                  child: Text(
                    _selectedVoice?.name ?? 'Choose a voice',
                    style: TextStyle(fontSize: sizes.bodyFontSize),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: sizes.iconSize * 0.75,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextPreview(ResponsiveSizes sizes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (mounted) _previewFocusNode.requestFocus();
          },
          child: Container(
            height: sizes.textPreviewHeight,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 1),
                left: BorderSide(color: Colors.grey.shade300, width: 1),
                right: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Stack(
              children: [
                // 全高度渐变背景层
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFEEEFDF), // 顶部实色背景
                          const Color(0xFFEEEFDF), // 中间保持实色
                          Colors.transparent, // 底部透明，显示页面背景
                        ],
                        stops: const [0.0, 1, 1.0], // 70%实色，30%渐变到透明
                      ),
                    ),
                  ),
                ),
                // 可滚动的文本编辑区域
                SingleChildScrollView(
                  controller: _textScrollController,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: sizes.smallSpacing,
                    ),
                    child: TextField(
                      focusNode: _previewFocusNode,
                      controller: _previewTextController,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      cursorColor: const Color(0xFF191815), // 使用深色光标
                      cursorWidth: 2.0, // 增加光标宽度
                      autofocus: false,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFF191815), // 文本颜色
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        _extractedText = value;
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _setPlayStartFromSelection() {
    final sel = _previewTextController.selection;
    if (sel.start < 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先选择或把光标放到想设置为起点的位置')));
      return;
    }
    
    // 删除起点之前的所有内容
    final text = _previewTextController.text;
    final newText = text.substring(sel.start);
    
    setState(() {
      _previewTextController.text = newText;
      _previewTextController.selection = TextSelection.collapsed(offset: 0);
      _extractedText = newText;
      _playStartIndex = 0; // 重置起点为0，因为已经删除了前面的内容
    });
    
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除起点前的内容')));
  }

  void _deleteSelectionInPreview() {
    final sel = _previewTextController.selection;
    if (sel.start < 0 || sel.start == sel.end) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先选择要删除的文本')));
      return;
    }
    final text = _previewTextController.text;
    final newText = text.replaceRange(sel.start, sel.end, '');
    setState(() {
      _previewTextController.text = newText;
      _previewTextController.selection = TextSelection.collapsed(offset: sel.start);
    });
  }

  Widget _buildGenerateButton(ResponsiveSizes sizes) {
    final canGenerate = !_isUploading && _selectedVoice != null && (_selectedFile != null || (_extractedText != null && _extractedText!.isNotEmpty));
    final text = _previewTextController.text;
    final hasText = text.trim().isNotEmpty;
    
    return SizedBox(
      height: sizes.buttonHeight,
      child: Stack(
        children: [
          ElevatedButton(
            onPressed: canGenerate && hasText ? _generateAudio : null,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: sizes.mediumSpacing),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(sizes.buttonHeight / 4),
              ),
              backgroundColor: canGenerate && hasText ? Colors.green : Colors.grey,
              disabledBackgroundColor: Colors.grey,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Center(
                child: _isUploading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: sizes.iconSize,
                            height: sizes.iconSize,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: sizes.smallSpacing),
                          Text(
                            'Generating... ${(_generateProgress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: sizes.bodyFontSize,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Generate Audio',
                        style: TextStyle(
                          fontSize: sizes.bodyFontSize,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
          // 绿色进度填充
          if (_isUploading && _generateProgress > 0)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(sizes.buttonHeight / 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _generateProgress,
                    child: Container(
                      color: Colors.green.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickFile(String type) async {
    try {
      // 请求权限
      if (type == 'image') {
        await _requestCameraPermission();
      } else {
        await _requestStoragePermission();
      }

      File? file;

      if (type == 'image') {
        // 图片选择 - 显示选择对话框
        final source = await showDialog<ImageSource>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('选择图片来源'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('拍照'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('从相册选择'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );

        if (source != null) {
          final XFile? pickedFile = await _imagePicker.pickImage(
            source: source,
            maxWidth: 1920,
            maxHeight: 1920,
            imageQuality: 85,
          );
          
          if (pickedFile != null) {
            file = File(pickedFile.path);
          }
        }
      } else {
        // 文件选择
        List<String> allowedExtensions = [];
        
        switch (type) {
          case 'pdf':
            allowedExtensions = ['pdf'];
            break;
          case 'document':
            allowedExtensions = ['docx', 'doc', 'epub'];
            break;
          case 'text':
            allowedExtensions = ['txt'];
            break;
        }

        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: allowedExtensions.isEmpty ? FileType.any : FileType.custom,
          allowedExtensions: allowedExtensions.isEmpty ? null : allowedExtensions,
          allowMultiple: false,
        );

        if (result != null && result.files.single.path != null) {
          file = File(result.files.single.path!);
        }
      }

      if (file != null) {
        // 验证文件
        if (!_fileService.validateFileSize(file)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('文件大小超过限制（最大10MB）')),
            );
          }
          return;
        }

        if (!_fileService.validateFileType(file)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('不支持的文件类型')),
            );
          }
          return;
        }

        setState(() {
          _selectedFile = file;
          _extractedText = '请输入编辑文本';
          _interactionMode = UploadInteractionMode.none;
          _galleryImages.clear();
        });

        // 如果是文本文件，直接读取
        final fileType = _fileService.getFileType(file);
        if (fileType == 'txt') {
          final text = await _fileService.readTextFile(file);
          if (text != null) {
            setState(() {
              _processExtractedText(text);
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $e')),
        );
      }
    }
  }

  /// 请求存储权限
  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Android 13+ 使用新的权限模型
      if (await Permission.photos.request().isGranted ||
          await Permission.storage.request().isGranted) {
        return;
      }
    } else if (Platform.isIOS) {
      if (await Permission.photos.request().isGranted) {
        return;
      }
    }
  }

  /// 请求相机权限
  Future<void> _requestCameraPermission() async {
    final cameraStatus = await Permission.camera.request();
    final storageStatus = Platform.isAndroid 
        ? await Permission.storage.request()
        : await Permission.photos.request();
    
    if (!cameraStatus.isGranted || !storageStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要相机和存储权限才能使用此功能')),
        );
      }
    }
  }

  void _showUrlInputDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final dialogKey = GlobalKey<UrlInputDialogState>();
        return Dialog(
          backgroundColor: Colors.transparent,
          child: UrlInputDialog(
            key: dialogKey,
            onSubmit: (url) async {
              await _submitUrl(
                url,
                onProgress: (progress) {
                  dialogKey.currentState?.updateProgress(progress);
                },
              );
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _submitUrl(String? url, {Function(double)? onProgress}) async {
    final target = (url ?? _urlController.text).trim();
    if (target.isEmpty) return;

    try {
      onProgress?.call(0.3);
      final result = await _apiService.submitUrl(url: target);
      onProgress?.call(0.7);
      setState(() {
      _processExtractedText(result['text']);
    });
      onProgress?.call(1.0);
      
      // 等待一下让用户看到100%
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  /// 处理单个生成任务（API调用 -> 轮询 -> 下载）
  /// 返回是否成功
  Future<bool> _processGeneration({
    required String text,
    int? fileId,
    required String provider,
    String? voiceId,
    String? voiceType,
    String? model,
    int? partIndex,
    int? totalParts,
  }) async {
    try {
      final genResp = await _apiService.generateAudio(
        text: text,
        provider: provider,
        voiceType: voiceType,
        voiceId: voiceId,
        model: model,
        fileId: fileId,
      );

      if (genResp['taskId'] == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Generate failed: ${genResp['error'] ?? 'No taskId returned'}')));
        }
        return false;
      }

      final String taskId = genResp['taskId'].toString();

      // 检查同步响应
      if (genResp['status'] == 'completed' && genResp['audio_url'] != null) {
        final audioUrl = genResp['audio_url'].toString();
        if (audioUrl.isNotEmpty) {
          await _downloadAndPlayAudio(audioUrl, partIndex: partIndex, totalParts: totalParts);
          return true;
        }
      }

      // 轮询
      int attempts = 0;
      const maxAttempts = 180;
      const interval = Duration(seconds: 2);
      bool taskCompleted = false;
      bool success = false;

      while (attempts < maxAttempts && !taskCompleted) {
        await Future.delayed(interval);
        attempts += 1;
        
        try {
          final statusResp = await _apiService.getTaskStatus(taskId);
          final data = statusResp['data'] ?? statusResp;
          final st = (data != null && data['status'] != null) ? data['status'].toString() : '';
          final progress = data != null && data['progress'] != null ? data['progress'] : null;
          final message = data != null && data['message'] != null ? data['message'] : null;

          if (mounted && progress != null && totalParts == null) {
             // 只有在非分段模式下才更新全局进度，分段模式下进度由外部控制
            setState(() {
              _generateProgress = (progress as num).toDouble() / 100.0;
            });
          }

          if (st == 'completed' || st == 'done') {
            final audioUrl = data['result'] != null && data['result']['audio_url'] != null
                ? data['result']['audio_url'].toString()
                : (data['audio_url'] != null ? data['audio_url'].toString() : null);
            
            if (audioUrl != null && audioUrl.isNotEmpty) {
              await _downloadAndPlayAudio(audioUrl, partIndex: partIndex, totalParts: totalParts);
              taskCompleted = true;
              success = true;
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Task completed but audio URL missing')),
                );
              }
              taskCompleted = true;
            }
            break;
          } else if (st == 'failed') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('TTS failed: ${message ?? 'Unknown error'}')),
              );
            }
            taskCompleted = true;
            break;
          }
        } catch (e) {
          print('Polling task error: $e');
          if (!mounted) break;
        }
      }
      
      if (!taskCompleted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task timeout, please try again')),
        );
      }
      
      return success;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      return false;
    }
  }

  Future<void> _generateAudio() async {
    if (_selectedVoice == null) return;
    
    setState(() {
      _isUploading = true;
      _generateProgress = 0.0;
    });

    // 如果存在选中文件，统一交给服务器处理：先上传，拿到 file_id 后把 file_id 一并传给 generateAudio
    int? fileIdToSend;
    if (_selectedFile != null) {
      try {
        final fileType = _fileService.getFileType(_selectedFile!);
        final uploadResp = await _apiService.uploadFile(file: _selectedFile!, fileType: fileType);
        if (uploadResp['file_id'] != null) {
          fileIdToSend = int.tryParse(uploadResp['file_id'].toString());
        }
        // 如果上传接口直接返回 text（短文本），也可用作优先文本
        if (uploadResp['text'] != null) {
          final txt = uploadResp['text'].toString();
          if (txt.trim().isEmpty) {
            // OCR 没有识别到文字，提示用户并中断流程
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请检查图片内是否有文字')));
            setState(() { _isUploading = false; });
            return;
          }
          if ((_extractedText == null || _extractedText!.isEmpty)) {
            _processExtractedText(txt);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        }
        setState(() {
          _isUploading = false;
        });
        return;
      }
    }

    // 如果没有文本且没有 fileId，提示并返回
    if ((_extractedText == null || _extractedText!.isEmpty) && fileIdToSend == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No text to synthesize')));
      }
      setState(() {
        _isUploading = false;
      });
      return;
    }

    // 准备参数
    final voice = _selectedVoice!;
    final provider = voice.provider ?? 'azure';
    final voiceId = voice.voiceId;
    final model = voice.model;
    String? voiceTypeParam;
    String? voiceIdParam;
    String? modelParam;

    if (provider == 'minimax') {
      voiceIdParam = voiceId;
      modelParam = model;
    } else {
      voiceTypeParam = voiceId;
    }

    // 大文本确认逻辑
    if (_isLargeText) {
      bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('超大文本确认'),
          content: Text('当前文本长度为 ${_extractedText?.length ?? 0} 字符，生成可能需要较长时间。\n\n是否继续？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('继续'),
            ),
          ],
        ),
      ) ?? false;

      if (!confirm) {
        setState(() {
          _isUploading = false;
        });
        return;
      }
    }

    // 单次生成逻辑
    await _processGeneration(
      text: _extractedText ?? '',
      fileId: fileIdToSend,
      provider: provider,
      voiceId: voiceIdParam,
      voiceType: voiceTypeParam,
      model: modelParam,
    );
    
    if (mounted) {
      setState(() {
        _isUploading = false;
        _generateProgress = 0.0;
      });
    }
  }

  /// 下载音频和 titles 文件，然后播放
  /// [audioUrl] 服务器音频URL
  Future<void> _downloadAndPlayAudio(String audioUrl, {int? partIndex, int? totalParts}) async {
    try {
      if (!mounted) return;
      
      // 如果不是分段生成，更新进度
      if (totalParts == null) {
        setState(() {
          _generateProgress = 0.8; // 开始下载，进度设为80%
        });
      }

      // 下载 mp3 文件
      final localAudioPath = await _downloadService.downloadAudio(
        audioUrl,
        onProgress: (progress) {
          if (mounted && totalParts == null) {
            setState(() {
              // 下载进度：80% - 95%
              _generateProgress = 0.8 + (progress * 0.15);
            });
          }
        },
      );

      // 下载 titles 文件（如果存在）
      if (mounted && totalParts == null) {
        setState(() {
          _generateProgress = 0.95; // titles 下载开始
        });
      }

      await _downloadService.downloadTitles(audioUrl);

      if (mounted && totalParts == null) {
        setState(() {
          _generateProgress = 1.0; // 下载完成
        });
      }
      // 更新使用统计（记录使用的字符数）
      if (_extractedText != null && _extractedText!.isNotEmpty && totalParts == null) {
        await _usageStatsService.addUsedCharacters(_extractedText!.length);
      }

      // 获取音频时长
      int durationSeconds = 0;
      try {
        final tempPlayer = AudioPlayer();
        await tempPlayer.setSourceDeviceFile(localAudioPath);
        final duration = await tempPlayer.getDuration();
        durationSeconds = duration?.inSeconds ?? 0;
        await tempPlayer.dispose();
      } catch (e) {
        print('Error getting duration: $e');
      }

      // 构造文件名
      String fileName = _selectedFile?.path.split('/').last ?? 'generated_audio.mp3';
      if (totalParts != null && partIndex != null) {
        // 如果是分段，文件名加上 Part X
        final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
        final ext = fileName.contains('.') ? fileName.split('.').last : 'mp3';
        fileName = '${nameWithoutExt}_Part${partIndex}_of_$totalParts.$ext';
      }

      // 保存到本地历史记录（使用本地文件路径）
      final history = await _localHistoryService.saveHistory(
        audioUrl: localAudioPath, // 使用本地路径
        voiceType: _selectedVoice!.voiceId ?? _selectedVoice!.name,
        voiceName: _selectedVoice!.name,
        duration: durationSeconds,
        resultText: totalParts != null ? 'Part $partIndex of $totalParts' : _extractedText,
        fileName: fileName,
      );
      
      // 标记需要刷新首页历史
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('history_needs_refresh', true);
      } catch (_) {}

      // 如果是分段生成，不自动播放和跳转，只显示提示
      if (totalParts != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Part $partIndex / $totalParts downloaded')),
          );
        }
        return;
      }

      // 播放本地文件
      await _audioService.play(localAudioPath);

      if (mounted) {
        await _openPlayerForUrl(history);
        // Removed 'Audio ready and playing' toast
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download error: $e')),
        );
        if (totalParts == null) {
          setState(() {
            _isUploading = false;
            _generateProgress = 0.0;
          });
        }
      }
    }
  }

  Future<void> _navigateToVoiceLibrary() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VoiceLibraryPage(),
      ),
    );
    
    if (result != null && result is VoiceTypeModel) {
      setState(() {
        _selectedVoice = result;
      });
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_selected_voice', jsonEncode(result.toJson()));
      } catch (e) {
        print('Failed to persist last selected voice: $e');
      }
    }
  }

  /// 在播放后跳转到 AudioPlayerPage，并设置首页刷新标记
  Future<void> _openPlayerForUrl(HistoryModel history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('history_needs_refresh', true);
    } catch (_) {}

    // 回到根页面（HomePage），再 push 播放页，这样返回时 HomePage 可以刷新
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => AudioPlayerPage(history: history)),
    );
  }
}
