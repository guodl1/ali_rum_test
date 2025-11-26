import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
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
  int _selectedIndex = -1; // -1: none
  bool _isLoading = false;
  double _progress = 0.0;
  Timer? _progressTimer;
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
    _progressTimer?.cancel();
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
        height: 50, // 固定高度，不再变化
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Stack(
          alignment: Alignment.center,
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
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Icon(
                    icon,
                    color: Colors.black,
                    size: 24,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progress = 0.0;
    // 总时长约 15 秒，每 100ms 更新一次
    // 15000ms / 100ms = 150 steps
    // step size = 1.0 / 150 ≈ 0.0066
    const totalDuration = 15000;
    const updateInterval = 100;
    const steps = totalDuration / updateInterval;
    const increment = 0.95 / steps; // 预留 5% 给完成状态

    _progressTimer = Timer.periodic(const Duration(milliseconds: updateInterval), (timer) {
      if (mounted) {
        setState(() {
          if (_progress < 0.95) {
            _progress += increment;
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _handleSimpleAction(String option) async {
     setState(() { 
       _selectedIndex = -1; // Simple actions don't show progress bar in the same way or maybe they should? 
       // The original code set progress to 1.0 immediately. Let's keep it simple for now or ask user if they want 15s for this too.
       // Assuming simple actions are instant/navigation, so no 15s wait needed.
       _progress = 1.0; 
     });
     await Future.delayed(const Duration(milliseconds: 300));
     widget.onOptionSelected?.call(option);
  }

  Future<void> _handleFileImport(BuildContext context) async {
    try {
      final hasPermission = await _requestStoragePermission(context);
      if (!hasPermission) {
        _resetSelection();
        return;
      }

      // Start timer when file picker opens? Or after selection?
      // Usually after selection is better for "uploading" phase.
      // But to match "filling" UI, let's wait for selection first.

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'epub', 'txt', 'jpg', 'jpeg', 'png', 'bmp'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        
        // 检查文件大小（10MB = 10 * 1024 * 1024 bytes）
        final fileSize = await file.length();
        const maxSize = 10 * 1024 * 1024; // 10MB
        
        if (fileSize > maxSize) {
          _resetSelection();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('文件大小超过限制（最大10MB）')),
            );
          }
          return;
        }
        
        // Start progress timer here
        _startProgressTimer();
        
        try {
          final ext = file.path.split('.').last.toLowerCase();
          String fileType = 'txt';
          if (['jpg', 'jpeg', 'png', 'bmp'].contains(ext)) fileType = 'image';
          else if (ext == 'pdf') fileType = 'pdf';
          else if (['docx', 'doc'].contains(ext)) fileType = 'docx';

          final resp = await _api.uploadFile(file: file, fileType: fileType);
          
          // Complete progress
          _progressTimer?.cancel();
          if (mounted) {
            setState(() => _progress = 1.0);
          }
          
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
      final hasPermission = await _requestCameraPermission(context);
      if (!hasPermission) {
        _resetSelection();
        return;
      }

      // setState(() => _progress = 0.3); // Don't show progress before picking

      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        
        _startProgressTimer();
        
        try {
          final resp = await _api.uploadFile(file: file, fileType: 'image');
          
          _progressTimer?.cancel();
          if (mounted) {
            setState(() => _progress = 1.0);
          }
          
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
      final hasPermission = await _requestStoragePermission(context);
      if (!hasPermission) {
        _resetSelection();
        return;
      }

      // setState(() => _progress = 0.3);

      final ImagePicker picker = ImagePicker();
      final List<XFile> pickedFiles = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        final files = pickedFiles.map((x) => File(x.path)).toList();
        
        _startProgressTimer();
        
        try {
          final resp = await _api.uploadImages(files: files);
          
          _progressTimer?.cancel();
          if (mounted) {
            setState(() => _progress = 1.0);
          }
          
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
      _progressTimer?.cancel();
    });
  }

  Future<bool> _requestStoragePermission(BuildContext context) async {
    if (Platform.operatingSystem == 'ohos') {
      final status = await Permission.storage.request();
      if (status.isGranted) {
        return true;
      } else if (status.isPermanentlyDenied) {
        await _showPermissionSettingsDialog(context, '存储');
        return false;
      }
      return false;
    }

    if (Platform.isAndroid) {
      final photosStatus = await Permission.photos.request();
      final storageStatus = await Permission.storage.request();
      
      if (photosStatus.isGranted || storageStatus.isGranted) {
        return true;
      } else if (photosStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
        await _showPermissionSettingsDialog(context, '存储');
        return false;
      }
      return false;
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      if (status.isGranted) {
        return true;
      } else if (status.isPermanentlyDenied) {
        await _showPermissionSettingsDialog(context, '相册');
        return false;
      } else if (status.isDenied) {
        // 用户拒绝了权限，但可以再次请求
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要相册权限才能使用此功能')),
          );
        }
        return false;
      }
      return false;
    }
    return false;
  }

  Future<bool> _requestCameraPermission(BuildContext context) async {
    // 鸿蒙系统处理
    if (Platform.operatingSystem == 'ohos') {
      final status = await Permission.camera.request();
      if (status.isGranted) {
        return true;
      } else if (status.isPermanentlyDenied) {
        await _showPermissionSettingsDialog(context, '相机');
        return false;
      }
      return false;
    }

    // iOS 处理 - 避免抛出异常
    if (Platform.isIOS) {
      final status = await Permission.camera.request();
      if (status.isGranted) {
        return true;
      } else if (status.isPermanentlyDenied) {
        await _showPermissionSettingsDialog(context, '相机');
        return false;
      } else if (status.isDenied) {
        // 用户拒绝了权限，但可以再次请求
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要相机权限才能使用此功能')),
          );
        }
        return false;
      }
      return false;
    }

    // Android 处理
    final cameraStatus = await Permission.camera.request();
    final storageStatus = await Permission.storage.request();

    if (cameraStatus.isGranted && storageStatus.isGranted) {
      return true;
    } else if (cameraStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
      await _showPermissionSettingsDialog(context, '相机和存储');
      return false;
    }
    
    return false;
  }

  Future<void> _showPermissionSettingsDialog(BuildContext context, String permissionName) async {
    if (!context.mounted) return;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要权限'),
        content: Text('请在设置中开启$permissionName权限以使用此功能'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('去设置'),
          ),
        ],
      ),
    );

    if (result == true) {
      await AppSettings.openAppSettings(type: AppSettingsType.settings);
    }
  }
}
