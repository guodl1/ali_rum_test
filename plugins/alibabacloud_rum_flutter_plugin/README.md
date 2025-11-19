Alibaba Cloud RUM SDK for Flutter
==========

| package             | pub                                                                                                                  | likes                                                                                                                | popularity                                                                                                                     | pub points                                                                                                                 |
|---------------------|----------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------|
| alibabacloud_rum_flutter_plugin | [![pub package](https://img.shields.io/pub/v/alibabacloud_rum_flutter_plugin.svg)](https://pub.dev/packages/alibabacloud_rum_flutter_plugin) | [![likes](https://img.shields.io/pub/likes/alibabacloud_rum_flutter_plugin)](https://pub.dev/packages/alibabacloud_rum_flutter_plugin/score) | [![popularity](https://img.shields.io/pub/popularity/alibabacloud_rum_flutter_plugin)](https://pub.dev/packages/alibabacloud_rum_flutter_plugin/score) | [![pub points](https://img.shields.io/pub/points/alibabacloud_rum_flutter_plugin)](https://pub.dev/packages/alibabacloud_rum_flutter_plugin/score) |


阿里云用户体验监控 RUM 官方 Flutter 插件，当前支持 Android、iOS 平台。

## 插件集成

### 1. 添加依赖
```yaml
dependencies:
  flutter:
    sdk: flutter

  alibabacloud_rum_flutter_plugin: ^1.0.5
```

### 2. 在Flutter项目根目录执行以下命令
```shell
flutter packages get
```

### 3. iOS 在工程 `ios` 目录下执行以下命令
```shell
pod install
```

### 4. 初始化 SDK
在 `main.dart` 文件中导入以下包：
```dart
import 'package:alibabacloud_rum_flutter_plugin/alibabacloud_rum_flutter_plugin.dart';
```

完成 SDK 的初始化：

```dart
void main() {
  // 注释原有的 runApp() ⽅法
  // runApp(MyApp());
  // （必须）初始化SDK
  AlibabaCloudRUM().start(MyApp());
  // （可选）自定义用户名称
  AlibabaCloudRUM().setUserName("xxxxxx");
}
```

### 5. 接入验证
Flutter 应用启动后，`DEBUG CONSOLE` 中返回 `[INFO][AlibabaCloudRUM]: alibabacloud_rum_flutter_plugin start success` 即表示 SDK 接入成功。示例如下：
```log
flutter: [2024-05-27 16:43:39][INFO][AlibabaCloudRUM]: alibabacloud_rum_flutter_plugin start success
```

## Native SDK 集成
Flutter 项目在集成 Alibaba Cloud RUM SDK 时，除了需要集成 Flutter 插件之外，还需要分别集成 Android、iOS SDK。您可以参考下面的文档集成：
* Android：[接入Android应用](https://help.aliyun.com/zh/arms/user-experience-monitoring/connect-android-applications-to-real-user-monitoring)
* iOS：[接入iOS应用](https://help.aliyun.com/zh/arms/user-experience-monitoring/connect-ios-applications-to-real-user-monitoring)

## Flutter API 说明
| API                | 说明            |
| ------------------ | --------------- |
| start              | 启动Flutter插件 |
| setUserName        | 设置用户名称    |
| setCustomEvent     | 设置自定义事件  |
| setCustomException | 设置自定义异常  |