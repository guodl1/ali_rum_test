
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/liquid_glass_card.dart';
import '../services/file_service.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../models/models.dart';
import 'voice_library_page.dart';
import '../widgets/tts_progress_dialog.dart';

enum UploadInteractionMode {
  none,
  urlInput,
  textInput,
  galleryPreview,
  filePreview,
}

/// 上传页面
class UploadPage extends StatefulWidget {
  const UploadPage({Key? key}) : super(key: key);

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final FileService _fileService = FileService();
  final ApiService _apiService = ApiService();
  final AudioService _audioService = AudioService();
  final LanguageService _languageService = LanguageService();
  final TextEditingController _urlController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  File? _selectedFile;
  VoiceTypeModel? _selectedVoice;
  bool _isUploading = false;
  ValueNotifier<int>? _progressNotifier;
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

  @override
  void initState() {
    super.initState();
    _inlineUrlController.addListener(_onUrlChanged);
    _inlineTextController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _inlineUrlController.removeListener(_onUrlChanged);
    _inlineTextController.removeListener(_onTextChanged);
    _inlineUrlController.dispose();
    _inlineTextController.dispose();
    _urlController.dispose();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Figma 颜色
    final backgroundColor = 
    isDark
        ? const Color(0xFF191815) // rgb(25, 24, 21)
        : const Color(0xFFEEEFDF); // rgb(238, 238, 253)
    
    final textColor = isDark
        ? const Color(0xFFF1EEE3) // rgb(241, 238, 227)
        : const Color(0xFF191815);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题
              Text(
                'Upload',
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              
              // 上传选项卡片 (基于 upload-structure.json)
              _buildUploadOptionsCard(textColor),
              
              const SizedBox(height: 24),

              const SizedBox(height: 24),
              // 语音选择
              _buildVoiceSelection(),
              const SizedBox(height: 24),
              // 提取的文本预览
              if (_extractedText != null) _buildTextPreview(),
              const SizedBox(height: 24),
              // 生成按钮
              _buildGenerateButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// 基于 upload-structure.json 的上传选项卡片
  Widget _buildUploadOptionsCard(Color textColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2A2F24) : const Color(0xFFE0F5DA);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: SizedBox(
        key: ValueKey(_interactionMode),
        height: _cardHeight,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(30),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ScrollConfiguration(
                behavior: const ScrollBehavior().copyWith(overscroll: false),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: _buildCardContent(textColor),
                  ),
                ),
              );
            },
          ),
        ),
      ),
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
                onPressed: () {
                  setState(() {
                    _showUrlCompleteButton = false;
                  });
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
                  setState(() {
                    _showTextCompleteButton = false;
                  });
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
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
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
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
        _extractedText = null;
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



  Widget _buildVoiceSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Voice',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        LiquidGlassCard(
          onTap: () => _navigateToVoiceLibrary(),
          child: Row(
            children: [
              Icon(
                Icons.record_voice_over,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedVoice?.name ?? 'Choose a voice',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Text Preview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        LiquidGlassCard(
          child: Text(
            _extractedText!,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    final canGenerate = !_isUploading && _selectedVoice != null && (_selectedFile != null || _extractedText != null);
    return ElevatedButton(
      onPressed: canGenerate ? _generateAudio : null,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isUploading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text(
              'Generate Audio',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
          _extractedText = null;
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

  Future<void> _submitUrl() async {
    if (_urlController.text.isEmpty) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final result = await _apiService.submitUrl(url: _urlController.text);
      setState(() {
        _extractedText = result['text'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _generateAudio() async {
    print('in _generateAudio');
    
    if (_selectedVoice == null) return;
    setState(() {
      _isUploading = true;
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
        if ((_extractedText == null || _extractedText!.isEmpty) && uploadResp['text'] != null) {
          _extractedText = uploadResp['text'];
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
      final genResp = await _apiService.generateAudio(
        text: _extractedText ?? '',
        voiceType: _selectedVoice!.id,
        fileId: fileIdToSend,
      );

      // 处理生成响应：如果返回已完成并包含 audio_url，则直接播放；
      // 如果返回 taskId（异步），开始轮询 /api/task/:taskId
        // 兼容不同后端响应结构
        final bool success = genResp['success'] == true || genResp['status'] == 'completed' || genResp['status'] == 200;

        if (genResp['status'] == 'completed' && genResp['audio_url'] != null) {
          final audioUrl = genResp['audio_url'];
          await _audioService.play(audioUrl);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio ready and playing')));
        } else if (genResp['taskId'] != null) {
          final String taskId = genResp['taskId'].toString();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task submitted: $taskId')));

          // 显示进度对话框
          _progressNotifier = ValueNotifier<int>(0);
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => TtsProgressDialog(
                progressNotifier: _progressNotifier!,
              ),
            );
          }

          // 开始轮询
          int attempts = 0;
          const maxAttempts = 180; // 最多轮询 6 分钟
          const interval = Duration(seconds: 2);

          while (attempts < maxAttempts) {
            await Future.delayed(interval);
            attempts += 1;
            try {
              final statusResp = await _apiService.getTaskStatus(taskId);
              final data = statusResp['data'] ?? statusResp;
              final st = (data != null && data['status'] != null) ? data['status'].toString() : '';
              final progress = data != null && data['progress'] != null ? data['progress'] : null;
              final message = data != null && data['message'] != null ? data['message'] : null;

              if (mounted && _progressNotifier != null && progress != null) {
                _progressNotifier!.value = (progress as num).toInt();
              }

              if (st == 'completed' || st == 'done') {
                // 关闭进度对话框
                if (mounted) {
                  try {
                    Navigator.of(context, rootNavigator: true).pop();
                  } catch (_) {}
                }
                _progressNotifier = null;

                final audioUrl = data['result'] != null ? data['result']['audio_url'] : data['audio_url'] ?? (data['result'] != null ? data['result']['audio_url'] : null);
                final resolvedUrl = audioUrl ?? (data['result'] != null ? data['result']['audio_url'] : null);
                if (resolvedUrl != null) {
                  await _audioService.play(resolvedUrl);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio ready and playing')));
                } else {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task completed but audio URL missing')));
                }
                break;
              } else if (st == 'failed') {
                // 关闭进度对话框
                if (mounted) {
                  try {
                    Navigator.of(context, rootNavigator: true).pop();
                  } catch (_) {}
                }
                _progressNotifier = null;
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('TTS failed: ${message ?? ''}')));
                break;
              }
            } catch (e) {
              // 忽略单次轮询的错误，继续重试
              print('Polling task error: $e');
            }
          }
        } else if (genResp['audio_url'] != null) {
          // 某些实现直接返回 audio_url
          final audioUrl = genResp['audio_url'];
          await _audioService.play(audioUrl);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio ready and playing')));
        } else if (!success) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generate failed: ${genResp['error'] ?? genResp}')));
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generation request submitted')));
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
    }
  }
}
