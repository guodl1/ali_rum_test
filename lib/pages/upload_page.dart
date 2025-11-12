import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/liquid_glass_card.dart';
import '../services/file_service.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../models/models.dart';
import 'voice_library_page.dart';

/// 上传页面
class UploadPage extends StatefulWidget {
  const UploadPage({Key? key}) : super(key: key);

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final FileService _fileService = FileService();
  final ApiService _apiService = ApiService();
  final LanguageService _languageService = LanguageService();
  final TextEditingController _urlController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  File? _selectedFile;
  VoiceTypeModel? _selectedVoice;
  bool _isUploading = false;
  String? _extractedText;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Upload'),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 文件上传区域
                _buildUploadSection(),
                const SizedBox(height: 24),
                // URL输入区域
                _buildUrlSection(),
                const SizedBox(height: 24),
                // 已选文件显示
                if (_selectedFile != null) _buildSelectedFileCard(),
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
      ),
    );
  }

  Widget _buildUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload File',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildUploadButton(
                icon: Icons.image,
                label: 'Image',
                onTap: () => _pickFile('image'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildUploadButton(
                icon: Icons.picture_as_pdf,
                label: 'PDF',
                onTap: () => _pickFile('pdf'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildUploadButton(
                icon: Icons.description,
                label: 'Document',
                onTap: () => _pickFile('document'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildUploadButton(
                icon: Icons.text_snippet,
                label: 'Text',
                onTap: () => _pickFile('text'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUploadButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return LiquidGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildUrlSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Or Enter URL',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        LiquidGlassCard(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              hintText: 'https://example.com',
              border: InputBorder.none,
              prefixIcon: Icon(Icons.link),
              suffixIcon: Icon(Icons.send),
            ),
            onSubmitted: (value) => _submitUrl(),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedFileCard() {
    final fileInfo = _fileService.getFileInfo(_selectedFile!);
    return LiquidGlassCard(
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileInfo['name'],
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _fileService.formatFileSize(fileInfo['size']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _selectedFile = null;
                _extractedText = null;
              });
            },
          ),
        ],
      ),
    );
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
    return ElevatedButton(
      onPressed: _isUploading || _selectedFile == null || _selectedVoice == null
          ? null
          : _generateAudio,
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
    if (_extractedText == null || _selectedVoice == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      await _apiService.generateAudio(
        text: _extractedText!,
        voiceType: _selectedVoice!.id,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio generated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
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
