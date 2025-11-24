import 'package:flutter/material.dart';

/// URL 输入对话框
/// 支持输入 URL 并显示加载进度
class UrlInputDialog extends StatefulWidget {
  final Function(String url) onSubmit;
  
  const UrlInputDialog({
    Key? key,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<UrlInputDialog> createState() => UrlInputDialogState();
}

class UrlInputDialogState extends State<UrlInputDialog> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  double _loadingProgress = 0.0;
  bool _userTypedHttps = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = 'https://';
    _urlController.addListener(_onTextChanged);
    
    // 设置光标位置在 https:// 之后
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _urlController.selection = TextSelection.fromPosition(
        TextPosition(offset: _urlController.text.length),
      );
    });
  }

  void _onTextChanged() {
    final text = _urlController.text;
    
    // 检查用户是否自己输入了 https://
    if (text.length >= 8) {
      final hasHttps = text.toLowerCase().startsWith('https://');
      if (hasHttps && text.length > 8) {
        setState(() {
          _userTypedHttps = true;
        });
      }
    } else if (text.isEmpty) {
      // 如果用户删除了所有内容，重置
      _urlController.text = 'https://';
      _urlController.selection = TextSelection.fromPosition(
        TextPosition(offset: 8),
      );
      setState(() {
        _userTypedHttps = false;
      });
    } else if (text.length < 8 && !text.startsWith('https://')) {
      // 如果用户删除了部分 https://，恢复它
      _urlController.text = 'https://';
      _urlController.selection = TextSelection.fromPosition(
        TextPosition(offset: 8),
      );
      setState(() {
        _userTypedHttps = false;
      });
    }
  }

  @override
  void dispose() {
    _urlController.removeListener(_onTextChanged);
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void updateProgress(double progress) {
    if (mounted && _isLoading) {
      setState(() {
        _loadingProgress = progress;
      });
    }
  }

  void _handleSubmit() {
    final url = _urlController.text.trim();
    if (url.isEmpty || url == 'https://') {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _loadingProgress = 0.0;
    });
    
    widget.onSubmit(url);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isLoading ? _buildLoadingView() : _buildInputView(),
      ),
    );
  }

  Widget _buildInputView() {
    return Padding(
      key: const ValueKey('input'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 输入框
          TextField(
            controller: _urlController,
            focusNode: _focusNode,
            autofocus: true,
            style: TextStyle(
              fontSize: 16,
              color: _userTypedHttps ? Colors.black : Colors.black87,
            ),
            decoration: InputDecoration(
              // 使用 prefixText 来显示灰色的 https://
              prefixText: _userTypedHttps ? '' : 'https://',
              prefixStyle: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade400,
              ),
              hintText: '',
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.black, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onSubmitted: (_) => _handleSubmit(),
            onChanged: (text) {
              // 防止用户删除 https://
              if (!text.startsWith('https://')) {
                final cursorPos = _urlController.selection.baseOffset;
                _urlController.text = 'https://' + text.replaceAll('https://', '');
                _urlController.selection = TextSelection.fromPosition(
                  TextPosition(offset: cursorPos < 8 ? 8 : cursorPos),
                );
              }
            },
          ),
          
          const SizedBox(height: 24),
          
          // 按钮行
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '取消',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: _handleSubmit,
                child: const Text(
                  '确定',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Padding(
      key: const ValueKey('loading'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // URL 显示
          Text(
            _urlController.text,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 24),
          
          // 进度条容器
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                // 背景
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // 进度填充
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 8,
                  width: MediaQuery.of(context).size.width * _loadingProgress,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50), // 绿色
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 加载文本
          Text(
            '正在加载... ${(_loadingProgress * 100).toInt()}%',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
