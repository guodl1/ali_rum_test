import 'dart:io';
import 'package:flutter/material.dart';
import 'package:alibabacloud_rum_flutter_plugin/alibabacloud_rum_flutter_plugin.dart';
void main() {
  // 在 iOS 和 Android 平台启动 Alibaba Cloud RUM，鸿蒙平台不启动
  if (Platform.isIOS || Platform.isAndroid) {
    AlibabaCloudRUM().start(const MyApp());
  } else {
    runApp(const MyApp());
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {


  @override
  void initState() {
    super.initState();

  }

  @override
  Widget build(BuildContext context) {
    // 显示加载指示器直到初始化完成
    return MaterialApp(
      title: 'TTS Reader',
      debugShowCheckedModeBanner: false,
    );
  }
}


