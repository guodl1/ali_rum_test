
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/liquid_glass_card.dart';
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
  int _playStartIndex = 0; // 文本播放起点（字符索引）
  int _playEndIndex = 0; // 文本播放终点（字符索引，0表示到结尾）

  @override
  void initState() {
    super.initState();
    _inlineUrlController.addListener(_onUrlChanged);
    _inlineTextController.addListener(_onTextChanged);
    // 只使用传入的文本，不加载缓存
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _extractedText = widget.initialText;
      _previewTextController.text = widget.initialText!;
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

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        // 确保所有内容在安全区域内，底部留出额外空间避免手势条遮挡
        minimum: EdgeInsets.only(
          bottom: sizes.safeArea.bottom > 0 ? 0 : sizes.mediumSpacing,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: sizes.isTablet ? sizes.screenWidth * 0.1 : 20,
            vertical: sizes.smallSpacing,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: sizes.smallSpacing),
              SizedBox(height: sizes.largeSpacing),
              
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
    );
  }

  /// 基于 upload-structure.json 的上传选项卡片


  Widget _buildDefaultOptionsContent(Color textColor) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildOptionButton(
                icon: Icons.file_upload,
                label: '导入',
                onTap: () => _pickFile('document'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildOptionButton(
                icon: Icons.text_fields,
                label: '输入文本',
                onTap: () {
                  setState(() {
                    _inlineTextController.text = _extractedText ?? '';
                    _interactionMode = UploadInteractionMode.textInput;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildOptionButton(
                icon: Icons.link,
                label: '打开网址',
                onTap: () {
                  setState(() {
                    _inlineUrlController.text =
                        _urlController.text.isNotEmpty ? _urlController.text : 'https://';
                    _interactionMode = UploadInteractionMode.urlInput;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildOptionButton(
                icon: Icons.camera_alt,
                label: '拍照',
                onTap: _pickFromCamera,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildOptionButton(
                icon: Icons.photo_library,
                label: '图库',
                onTap: _pickImagesFromGallery,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardContent(Color textColor) {
    switch (_interactionMode) {
      case UploadInteractionMode.urlInput:
        return _buildUrlInputContent(textColor);
      case UploadInteractionMode.textInput:
        return _buildTextInputContent(textColor);
      case UploadInteractionMode.galleryPreview:
        return _buildGalleryPreviewContent(textColor);
      case UploadInteractionMode.filePreview:
        return _buildFilePreviewContent(textColor);
      case UploadInteractionMode.none:
        return _buildDefaultOptionsContent(textColor);
    }
  }

  Widget _buildUrlInputContent(Color textColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '输入网址',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: _resetInteractionMode,
                icon: Icon(Icons.close, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inlineUrlController,
            autofocus: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.link),
              hintText: 'https://',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_showUrlCompleteButton)
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final entered = _inlineUrlController.text.trim();
                  if (entered.isEmpty) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入网址')));
                    return;
                  }
                  String normalized = entered;
                  if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
                    normalized = 'https://$normalized';
                  }
                  setState(() {
                    _showUrlCompleteButton = false;
                    _interactionMode = UploadInteractionMode.none;
                  });
                  await _submitUrl(normalized);
                },
                icon: const Icon(Icons.check),
                label: const Text('完成'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextInputContent(Color textColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '输入文本',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: _resetInteractionMode,
                icon: Icon(Icons.close, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: TextField(
              controller: _inlineTextController,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '请输入要转换的文本...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_showTextCompleteButton)
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  final entered = _inlineTextController.text.trim();
                  setState(() {
                    _showTextCompleteButton = false;
                    _extractedText = entered;
                    _interactionMode = UploadInteractionMode.none;
                  });
                  if (mounted && entered.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入要转换的文本')));
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('完成'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGalleryPreviewContent(Color textColor) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '图库预览 (${_galleryImages.length})',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _galleryImages.clear();
                        _interactionMode = UploadInteractionMode.none;
                        _showPhotoCompleteButton = true;
                      });
                    },
                    icon: Icon(Icons.close, color: textColor),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_galleryImages.isEmpty)
                Text(
                  '暂无图片，尝试重新选择。',
                  style: TextStyle(color: textColor.withValues(alpha: 0.7)),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _galleryImages.asMap().entries.map((entry) {
                    final index = entry.key;
                    final file = entry.value;
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            file,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeGalleryImage(index),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: _pickImagesFromGallery,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('继续添加'),
                  ),
                ],
              ),
              // 为完成按钮留出空间，避免遮挡
              if (_showPhotoCompleteButton) const SizedBox(height: 60),
            ],
          ),
        ),
        // 悬浮完成按钮 - 固定在右下角，始终在最上层
        if (_showPhotoCompleteButton)
          Positioned(
            bottom: 0,
            right: 0,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showPhotoCompleteButton = false;
                  });
                },
                icon: const Icon(Icons.check),
                label: const Text('完成'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilePreviewContent(Color textColor) {
    if (_selectedFile == null) {
      return _buildDefaultOptionsContent(textColor);
    }
    final info = _fileService.getFileInfo(_selectedFile!);
    final isImage = _fileService.getFileType(_selectedFile!) == 'image';
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '文件预览',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedFile = null;
                  _interactionMode = UploadInteractionMode.none;
                });
              },
              icon: Icon(Icons.close, color: textColor),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: isImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.file(
                          _selectedFile!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.insert_drive_file,
                            color: Theme.of(context).colorScheme.primary,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            info['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _fileService.formatFileSize(info['size']),
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _interactionMode = UploadInteractionMode.none;
                    });
                  },
                  icon: const Icon(Icons.edit),
                  tooltip: '重新选择',
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedFile = null;
                      _interactionMode = UploadInteractionMode.none;
                    });
                  },
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '移除文件',
                ),
              ],
            ),
          ],
        ),
        ],
      ),
    );
  }

  void _resetInteractionMode() {
    setState(() {
      _interactionMode = UploadInteractionMode.none;
      _showUrlCompleteButton = true;
      _showTextCompleteButton = true;
    });
  }


  void _removeGalleryImage(int index) {
    if (index < 0 || index >= _galleryImages.length) return;
    setState(() {
      _galleryImages.removeAt(index);
      if (_galleryImages.isEmpty) {
        _selectedFile = null;
        _interactionMode = UploadInteractionMode.none;
        _showPhotoCompleteButton = true;
      } else {
        _selectedFile = _galleryImages.first;
        // 删除图片后显示完成按钮
        _showPhotoCompleteButton = true;
      }
    });
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFF1EEE3)
        : const Color(0xFF191815);
    final screenHeight = MediaQuery.of(context).size.height;
    final buttonHeight = screenHeight < 600 ? 80.0 : 100.0;
    final iconSize = screenHeight < 600 ? 28.0 : 32.0;
    final fontSize = screenHeight < 600 ? 12.0 : 14.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: buttonHeight,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(isDark ? 0.1 : 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: textColor,
              size: iconSize,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImagesFromGallery() async {
    try {
      await _requestStoragePermission();

      final pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFiles.isEmpty) {
        return;
      }

      final files = pickedFiles.map((x) => File(x.path)).toList();

      setState(() {
        // 继续添加而不是替换现有图片
        _galleryImages.addAll(files);
        if (_selectedFile == null && files.isNotEmpty) {
          _selectedFile = files.first;
        }
        _interactionMode = UploadInteractionMode.galleryPreview;
        _extractedText = '请输入编辑文本';
        // 添加图片后显示完成按钮
        _showPhotoCompleteButton = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  /// 从相机拍照
  Future<void> _pickFromCamera() async {
    try {
      await _requestCameraPermission();
      
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        if (_fileService.validateFileSize(file)) {
          setState(() {
            _selectedFile = file;
            _interactionMode = UploadInteractionMode.filePreview;
            _galleryImages.clear();
          });
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件大小超过限制（最大10MB）')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e')),
        );
      }
    }
  }



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
        SizedBox(
          height: sizes.textPreviewHeight,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: sizes.smallSpacing,
                  ),
                  child: TextField(
                    controller: _previewTextController,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(
                      fontSize: sizes.bodyFontSize,
                      height: 1.5,
                      color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.8),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      hintText: '在此输入或编辑文本...',
                      hintStyle: TextStyle(color: Colors.grey),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (text) {
                      setState(() {
                        _extractedText = text;
                      });
                    },
                  ),
                ),
              ),
              // 底部工具栏：设为起点、删除选中、插入文本、显示起点位置
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: sizes.tinySpacing,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmall = constraints.maxWidth < 400;
                    return isSmall
                        ? Wrap(
                            spacing: sizes.tinySpacing,
                            runSpacing: sizes.tinySpacing,
                            children: [
                              TextButton(
                                onPressed: _setPlayStartFromSelection,
                                child: Text(
                                  '设为起点',
                                  style: TextStyle(
                                    fontSize: sizes.smallFontSize,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _deleteSelectionInPreview,
                                child: Text(
                                  '删除选中',
                                  style: TextStyle(
                                    fontSize: sizes.smallFontSize,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _insertTextAtCursor,
                                child: Text(
                                  '插入文本',
                                  style: TextStyle(
                                    fontSize: sizes.smallFontSize,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(
                                  top: sizes.smallSpacing,
                                  left: sizes.tinySpacing,
                                ),
                                child: Text(
                                  '起点: $_playStartIndex',
                                  style: TextStyle(
                                    fontSize: sizes.smallFontSize,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              TextButton(
                                onPressed: _setPlayStartFromSelection,
                                child: const Text(
                                  '设为起点',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              SizedBox(width: sizes.tinySpacing),
                              TextButton(
                                onPressed: _deleteSelectionInPreview,
                                child: const Text(
                                  '删除选中',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              SizedBox(width: sizes.tinySpacing),
                              TextButton(
                                onPressed: _insertTextAtCursor,
                                child: const Text(
                                  '插入文本',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '起点: $_playStartIndex',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          );
                  },
                ),
              ),
            ],
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
    setState(() {
      _playStartIndex = sel.start;
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已设置播放起点')));
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

  Future<void> _insertTextAtCursor() async {
    final toInsert = await showDialog<String?>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('插入文本'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('插入')),
          ],
        );
      },
    );
    if (toInsert == null || toInsert.isEmpty) return;
    final sel = _previewTextController.selection;
    final pos = sel.start >= 0 ? sel.start : _previewTextController.text.length;
    final text = _previewTextController.text;
    final newText = text.replaceRange(pos, pos, toInsert);
    setState(() {
      _previewTextController.text = newText;
      _previewTextController.selection = TextSelection.collapsed(offset: pos + toInsert.length);
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
              _extractedText = text;
              // 自动检测语言
              final detectedLang = _languageService.detectLanguage(text);
              if (detectedLang != 'unknown') {
                final voices = _languageService.getRecommendedVoices(detectedLang);
                if (voices.isNotEmpty && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('检测到${detectedLang == "zh" ? "中文" : "英文"}内容'),
                    ),
                  );
                }
              }
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

  Future<void> _submitUrl([String? url]) async {
    final target = (url ?? _urlController.text).trim();
    if (target.isEmpty) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final result = await _apiService.submitUrl(url: target);
      setState(() {
        _extractedText = result['text'];
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() { _isUploading = false; });
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
            _extractedText = txt;
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
    try {
      // 根据指南.md 8.13规范，使用新字段结构
      final voice = _selectedVoice!;
      final provider = voice.provider ?? 'azure';
      final voiceId = voice.voiceId; // 使用 voiceId 字段
      final model = voice.model; // 使用 model 字段
      String? voiceTypeParam;
      String? voiceIdParam;
      String? modelParam;

      if (provider == 'minimax') {
        // Minimax 使用 voiceId 和 model
        voiceIdParam = voiceId;
        modelParam = model;
      } else {
        // Azure/Google 使用 voiceType（即 voiceId）
        voiceTypeParam = voiceId;
      }
      
      final genResp = await _apiService.generateAudio(
        text: _extractedText ?? '',
        provider: provider,
        voiceType: voiceTypeParam,
        voiceId: voiceIdParam,
        model: modelParam,
        fileId: fileIdToSend,
      );

      // 统一使用轮询方式：检查是否有 taskId
      if (genResp['taskId'] == null) {
        // 如果没有 taskId，说明请求失败
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Generate failed: ${genResp['error'] ?? 'No taskId returned'}')));
        }
        return;
      }

      final String taskId = genResp['taskId'].toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task submitted: $taskId'), duration: const Duration(seconds: 2)),
        );
      }

      // 开始轮询任务状态
      int attempts = 0;
      const maxAttempts = 180; // 最多轮询 6 分钟
      const interval = Duration(seconds: 2);
      bool taskCompleted = false;

      while (attempts < maxAttempts && !taskCompleted) {
        await Future.delayed(interval);
        attempts += 1;
        
        try {
          final statusResp = await _apiService.getTaskStatus(taskId);
          final data = statusResp['data'] ?? statusResp;
          final st = (data != null && data['status'] != null) ? data['status'].toString() : '';
          final progress = data != null && data['progress'] != null ? data['progress'] : null;
          final message = data != null && data['message'] != null ? data['message'] : null;

          // 更新进度
          if (mounted && progress != null) {
            setState(() {
              _generateProgress = (progress as num).toDouble() / 100.0;
            });
          }

          // 检查任务状态
          if (st == 'completed' || st == 'done') {
            // 任务完成，提取音频URL
            final audioUrl = data['result'] != null && data['result']['audio_url'] != null
                ? data['result']['audio_url'].toString()
                : (data['audio_url'] != null ? data['audio_url'].toString() : null);
            
            if (audioUrl != null && audioUrl.isNotEmpty) {
              // 下载音频、保存历史、跳转页面
              await _downloadAndPlayAudio(audioUrl);
              taskCompleted = true;
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
          // 忽略单次轮询的错误，继续重试
          print('Polling task error: $e');
          // 如果页面已销毁，停止轮询
          if (!mounted) {
            break;
          }
        }
      }

      // 如果轮询超时
      if (!taskCompleted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task timeout, please try again')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _generateProgress = 0.0;
        });
      }
    }
  }

  /// 下载音频和 titles 文件，然后播放
  /// [audioUrl] 服务器音频URL
  Future<void> _downloadAndPlayAudio(String audioUrl) async {
    try {
      if (!mounted) return;
      
      setState(() {
        _generateProgress = 0.8; // 开始下载，进度设为80%
      });

      // 下载 mp3 文件
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloading audio...'), duration: Duration(seconds: 1)),
        );
      }

      final localAudioPath = await _downloadService.downloadAudio(
        audioUrl,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              // 下载进度：80% - 95%
              _generateProgress = 0.8 + (progress * 0.15);
            });
          }
        },
      );

      // 下载 titles 文件（如果存在）
      if (mounted) {
        setState(() {
          _generateProgress = 0.95; // titles 下载开始
        });
      }

      await _downloadService.downloadTitles(audioUrl);

      if (mounted) {
        setState(() {
          _generateProgress = 1.0; // 下载完成
        });
      }
      // 更新使用统计（记录使用的字符数）
      if (_extractedText != null && _extractedText!.isNotEmpty) {
        await _usageStatsService.addUsedCharacters(_extractedText!.length);
      }

      // 保存到本地历史记录（使用本地文件路径）
      final history = await _localHistoryService.saveHistory(
        audioUrl: localAudioPath, // 使用本地路径
        voiceType: _selectedVoice!.voiceId ?? _selectedVoice!.name,
        resultText: _extractedText,
        fileName: _selectedFile?.path.split('/').last,
      );
      
      // 标记需要刷新首页历史
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('history_needs_refresh', true);
      } catch (_) {}
      // 播放本地文件
      await _audioService.play(localAudioPath);

      if (mounted) {
        await _openPlayerForUrl(history);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio ready and playing')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download error: $e')),
        );
        setState(() {
          _isUploading = false;
          _generateProgress = 0.0;
        });
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
