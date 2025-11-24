import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';

/// 上传选项弹出窗口（有状态），在选择并上传时显示加载动画
class UploadOptionsDialog extends StatefulWidget {
  final Function(String option, {File? file, List<File>? files, String? text})? onOptionSelected;

  const UploadOptionsDialog({
    Key? key,
    this.onOptionSelected,
  }) : super(key: key);

  @override
  State<UploadOptionsDialog> createState() => _UploadOptionsDialogState();
}

class _UploadOptionsDialogState extends State<UploadOptionsDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  int _selectedIndex = -1; // -1: none
  bool _isLoading = false;
  double _progress = 0.0;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400), // 更长的动画时间
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic, // 更柔和的曲线
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15), // 所有角都是圆角
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOptionItem(0, Icons.folder_outlined, '导入', () => _handleFileImport(context)),
            _buildDivider(0),
            _buildOptionItem(1, Icons.edit_outlined, '输入文本', () => _handleSimpleAction('text')),
            _buildDivider(1),
            _buildOptionItem(2, Icons.language_outlined, '打开网页', () => _handleSimpleAction('url')),
            _buildDivider(2),
            _buildOptionItem(3, Icons.camera_alt_outlined, '扫描', () => _handleCamera(context)),
            _buildDivider(3),
            _buildOptionItem(4, Icons.photo_library_outlined, '图库', () => _handleGallery(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(int index) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      color: Colors.grey.withOpacity(0.2),
    );
  }

  Widget _buildOptionItem(int index, IconData icon, String label, VoidCallback onTap) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        if (_selectedIndex == -1) {
          setState(() {
            _selectedIndex = index;
            _isLoading = true;
            _progress = 0.0;
          });
          onTap();
        }
      },
      child: Container(
        height: 34, // 固定高度，不再变化
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Stack(
          children: [
            // 进度条背景
            if (isSelected)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: index == 0 
                    ? const BorderRadius.vertical(top: Radius.circular(15)) // 第一个选项：只有上圆角
                    : index == 4 
                        ? const BorderRadius.vertical(bottom: Radius.circular(15)) // 最后一个选项：只有下圆角
                        : BorderRadius.zero, // 中间选项：无圆角
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    width: 240 * _progress,
                    decoration: BoxDecoration(
                      color: const Color(0x334CAF50), // 0x33 = 20% opacity
                    ),
                  ),
                ),
              ),
            
            // 内容
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Icon(
                    icon,
                    color: Colors.black,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSimpleAction(String option) async {
     setState(() { _progress = 1.0; });
     await Future.delayed(const Duration(milliseconds: 300));
     widget.onOptionSelected?.call(option);
  }

  Future<void> _handleFileImport(BuildContext context) async {
    try {
      await _requestStoragePermission();

      setState(() => _progress = 0.3);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'epub', 'txt', 'jpg', 'jpeg', 'png', 'bmp'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        setState(() => _progress = 0.5);
        
        try {
          final ext = file.path.split('.').last.toLowerCase();
          String fileType = 'txt';
          if (['jpg', 'jpeg', 'png', 'bmp'].contains(ext)) fileType = 'image';
          else if (ext == 'pdf') fileType = 'pdf';
          else if (['docx', 'doc'].contains(ext)) fileType = 'docx';

          setState(() => _progress = 0.7);
          final resp = await _api.uploadFile(file: file, fileType: fileType);
          setState(() => _progress = 1.0);
          
          await Future.delayed(const Duration(milliseconds: 300));
          
          final text = resp['text']?.toString();
          widget.onOptionSelected?.call('processed', text: text);
        } catch (e) {
          _resetSelection();
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传失败: $e')));
        }
      } else {
        _resetSelection();
      }
    } catch (e) {
      _resetSelection();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('选择文件失败: $e')));
    }
  }

  Future<void> _handleCamera(BuildContext context) async {
    try {
      await _requestCameraPermission();

      setState(() => _progress = 0.3);

      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        setState(() => _progress = 0.5);
        
        try {
          setState(() => _progress = 0.7);
          final resp = await _api.uploadFile(file: file, fileType: 'image');
          setState(() => _progress = 1.0);
          
          await Future.delayed(const Duration(milliseconds: 300));
          
          final text = resp['text']?.toString();
          widget.onOptionSelected?.call('processed', text: text);
        } catch (e) {
          _resetSelection();
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传失败: $e')));
        }
      } else {
        _resetSelection();
      }
    } catch (e) {
      _resetSelection();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('拍照失败: $e')));
    }
  }

  Future<void> _handleGallery(BuildContext context) async {
    try {
      await _requestStoragePermission();

      setState(() => _progress = 0.3);

      final ImagePicker picker = ImagePicker();
      final List<XFile> pickedFiles = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        final files = pickedFiles.map((x) => File(x.path)).toList();
        setState(() => _progress = 0.5);
        
        try {
          setState(() => _progress = 0.7);
          final resp = await _api.uploadImages(files: files);
          setState(() => _progress = 1.0);
          
          await Future.delayed(const Duration(milliseconds: 300));
          
          final text = resp['text']?.toString();
          widget.onOptionSelected?.call('processed', text: text);
        } catch (e) {
          _resetSelection();
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传失败: $e')));
        }
      } else {
        _resetSelection();
      }
    } catch (e) {
      _resetSelection();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
    }
  }

  void _resetSelection() {
    setState(() {
      _selectedIndex = -1;
      _isLoading = false;
      _progress = 0.0;
    });
  }

  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid) {
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

  Future<void> _requestCameraPermission() async {
    final cameraStatus = await Permission.camera.request();
    final storageStatus = Platform.isAndroid
        ? await Permission.storage.request()
        : await Permission.photos.request();

    if (!cameraStatus.isGranted || !storageStatus.isGranted) {
      throw Exception('需要相机和存储权限才能使用此功能');
    }
  }
}
