# TTS Reader - 功能实现说明

## ✅ 已完成功能

### 1. 文件和图片选择
- ✅ **image_picker** - 支持拍照和从相册选择图片
- ✅ **file_picker** - 支持选择 PDF、DOCX、TXT、EPUB 文档
- ✅ 文件大小验证（最大 10MB）
- ✅ 文件类型验证
- ✅ 自动检测文本语言（中文/英文）

### 2. 权限管理
#### Android 权限
- ✅ INTERNET - 网络访问
- ✅ READ_EXTERNAL_STORAGE - 读取存储
- ✅ WRITE_EXTERNAL_STORAGE - 写入存储
- ✅ READ_MEDIA_IMAGES - Android 13+ 图片权限
- ✅ READ_MEDIA_VIDEO - Android 13+ 视频权限
- ✅ READ_MEDIA_AUDIO - Android 13+ 音频权限
- ✅ CAMERA - 相机权限

#### iOS 权限
- ✅ NSCameraUsageDescription - 相机访问
- ✅ NSPhotoLibraryUsageDescription - 照片库访问
- ✅ NSPhotoLibraryAddUsageDescription - 照片库添加
- ✅ NSDocumentsFolderUsageDescription - 文件访问

### 3. 多语言支持
- ✅ **中文（简体）** - zh-CN
- ✅ **英文** - en-US
- ✅ 语言切换功能（设置页面）
- ✅ 本地化字符串管理
- ✅ 自动保存语言偏好

### 4. 上传页面功能
```dart
_pickFile(String type)
- 'image' - 图片选择（拍照/相册）
- 'pdf' - PDF 文件
- 'document' - DOCX/EPUB 文档
- 'text' - TXT 文本文件
```

## 📱 使用方法

### 上传图片
1. 点击"上传图片"按钮
2. 选择"拍照"或"从相册选择"
3. 系统会请求相机/存储权限（首次使用）
4. 选择图片后自动验证大小和格式

### 上传文档
1. 点击对应的文档类型按钮（PDF/Document/Text）
2. 系统会请求存储权限（首次使用）
3. 从文件管理器选择文件
4. TXT 文件会自动提取文本并检测语言

### 切换语言
1. 进入"设置"页面
2. 点击"Language"选项
3. 选择"中文"或"English"
4. 应用会立即切换语言并显示提示

## 🔧 技术实现

### 权限请求流程
```dart
// 存储权限
_requestStoragePermission()
- Android: photos/storage 权限
- iOS: photos 权限

// 相机权限
_requestCameraPermission()
- Android: camera + storage
- iOS: camera + photos
```

### 语言切换流程
```dart
LocalizationService
├── init() - 初始化，加载保存的语言
├── changeLocale(Locale) - 切换语言
├── translate(String) - 获取翻译
└── currentLocale - 当前语言
```

### 文件处理流程
```
用户选择文件
    ↓
验证文件大小 (≤10MB)
    ↓
验证文件类型
    ↓
TXT文件 → 直接读取 → 检测语言
图片/PDF → 准备上传到服务器
DOCX/EPUB → 准备解析
```

## 🎨 UI 特性

### 液态玻璃效果
- ✅ 毛玻璃背景
- ✅ 渐变边框
- ✅ 深色/浅色模式自适应

### 页面动画
- ✅ 页面切换动画（300ms）
- ✅ 底部导航栏切换
- ✅ 对话框动画

### 状态栏适配
- ✅ 透明状态栏
- ✅ 图标颜色自适应主题

## 📝 多语言字段

### 新增字段
```json
{
  "select_image_source": "选择图片来源",
  "take_photo": "拍照",
  "choose_from_gallery": "从相册选择",
  "file_size_exceeded": "文件大小超过限制（最大10MB）",
  "unsupported_file_type": "不支持的文件类型",
  "file_selection_failed": "选择文件失败",
  "camera_and_storage_permission_required": "需要相机和存储权限",
  "language_changed": "语言切换成功",
  "chinese_detected": "检测到中文内容",
  "english_detected": "检测到英文内容",
  "storage_permission_desc": "需要存储权限以访问文件",
  "camera_permission_desc": "需要相机权限以拍照"
}
```

## 🚀 下一步开发

### 待实现功能
- [ ] OCR 文字识别（图片/PDF）
- [ ] DOCX/EPUB 文档解析
- [ ] 网页内容抓取完善
- [ ] TTS 语音生成
- [ ] 音频播放器完善
- [ ] 历史记录同步
- [ ] 用户登录系统

## 📦 依赖包

```yaml
dependencies:
  # 文件选择
  file_picker: ^6.1.1
  image_picker: ^1.0.7
  
  # 权限管理
  permission_handler: ^11.1.0
  
  # 多语言
  flutter_localizations: sdk
  intl: ^0.19.0
  
  # 其他
  shared_preferences: ^2.2.2
  audioplayers: ^5.2.1
  http: ^1.1.0
```

## 🎯 测试要点

### 权限测试
1. 首次启动应用
2. 点击上传图片 → 检查相机/存储权限弹窗
3. 点击上传文档 → 检查存储权限弹窗
4. 拒绝权限 → 检查错误提示

### 语言切换测试
1. 设置中切换语言
2. 检查所有页面文字是否更新
3. 重启应用 → 检查语言是否保存

### 文件上传测试
1. 选择超过10MB的文件 → 检查大小限制提示
2. 选择不支持的文件类型 → 检查类型验证
3. 上传TXT文件 → 检查文本提取和语言检测

## 📞 联系方式
Email: 1245105585@qq.com
