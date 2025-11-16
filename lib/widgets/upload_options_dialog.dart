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

class _UploadOptionsDialogState extends State<UploadOptionsDialog> {
  bool _loading = false;
  final ApiService _api = ApiService();

  @override
  Widget build(BuildContext context) {
    final cardColor = const Color(0xFFE0F5DA); // rgb(224, 245, 218)

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: 227,
        height: 300,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: _loading ? _buildLoading() : _buildOptions(context),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('正在处理，请稍候...'),
        ],
      ),
    );
  }

  Widget _buildOptions(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 183,
          height: 1,
          margin: const EdgeInsets.only(top: 44),
          color: Colors.black,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                _buildOptionItem(
                  context: context,
                  icon: Icons.insert_drive_file,
                  label: '导入',
                  onTap: () => _handleFileImport(context),
                ),
                const SizedBox(height: 8),
                _buildOptionItem(
                  context: context,
                  icon: Icons.text_fields,
                  label: '输入文本',
                  onTap: () {
                    widget.onOptionSelected?.call('text');
                  },
                ),
                const SizedBox(height: 8),
                _buildOptionItem(
                  context: context,
                  icon: Icons.link,
                  label: '打开网址',
                  onTap: () {
                    widget.onOptionSelected?.call('url');
                  },
                ),
                const SizedBox(height: 8),
                _buildOptionItem(
                  context: context,
                  icon: Icons.camera_alt,
                  label: '拍照',
                  onTap: () => _handleCamera(context),
                ),
                const SizedBox(height: 8),
                _buildOptionItem(
                  context: context,
                  icon: Icons.photo_library,
                  label: '图库',
                  onTap: () => _handleGallery(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.black, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFileImport(BuildContext context) async {
    try {
      await _requestStoragePermission();

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'epub', 'txt', 'jpg', 'jpeg', 'png', 'bmp'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        setState(() { _loading = true; });
        try {
          final ext = file.path.split('.').last.toLowerCase();
          String fileType = 'txt';
          if (['jpg', 'jpeg', 'png', 'bmp'].contains(ext)) fileType = 'image';
          else if (ext == 'pdf') fileType = 'pdf';
          else if (['docx', 'doc'].contains(ext)) fileType = 'docx';

          final resp = await _api.uploadFile(file: file, fileType: fileType);
          final text = resp['text']?.toString();
          widget.onOptionSelected?.call('processed', text: text);
        } catch (e) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传失败: $e')));
        } finally {
          if (mounted) setState(() { _loading = false; });
        }
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('选择文件失败: $e')));
    }
  }

  Future<void> _handleCamera(BuildContext context) async {
    try {
      await _requestCameraPermission();

      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        setState(() { _loading = true; });
        try {
          final resp = await _api.uploadFile(file: file, fileType: 'image');
          final text = resp['text']?.toString();
          widget.onOptionSelected?.call('processed', text: text);
        } catch (e) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传失败: $e')));
        } finally {
          if (mounted) setState(() { _loading = false; });
        }
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('拍照失败: $e')));
    }
  }

  Future<void> _handleGallery(BuildContext context) async {
    try {
      await _requestStoragePermission();

      final ImagePicker picker = ImagePicker();
      final List<XFile> pickedFiles = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        final files = pickedFiles.map((x) => File(x.path)).toList();
        setState(() { _loading = true; });
        try {
          final resp = await _api.uploadImages(files: files);
          final text = resp['text']?.toString();
          widget.onOptionSelected?.call('processed', text: text);
        } catch (e) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传失败: $e')));
        } finally {
          if (mounted) setState(() { _loading = false; });
        }
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
    }
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

