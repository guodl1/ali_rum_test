import '../alibabacloud_rum_agent_impl.dart';
import 'package:flutter/widgets.dart';

abstract class AlibabaCloudRUM {
  ///Factory which creates a [AlibabaCloudRUM] object
  factory AlibabaCloudRUM() => AlibabaCloudRUMImpl();

  //alibabacloud rum flutter start function
  Future<void> start(Widget topLevelWidget, {Function()? beforeRunApp});

  /// 设置用户附加信息，会覆盖之前的设置
  /// @param extraInfo 附加信息为Key-Value形式
  Future<void> setUserExtraInfo(Map<String, dynamic> extraInfo);

  /// 追加用户附加信息
  /// @param extraInfo 附加信息为Key-Value形式
  Future<void> addUserExtraInfo(Map<String, dynamic> extraInfo);

  /// 设置全局扩展属性，会覆盖之前的设置
  /// @param extraInfo 附加信息为Key-Value形式
  Future<void> setExtraInfo(Map<String, dynamic> extraInfo);

  /// 追加全局扩展属性
  /// @param extraInfo 附加信息为Key-Value形式
  Future<void> addExtraInfo(Map<String, dynamic> extraInfo);

  /// 设置用户名称
  Future<void> setUserName(String userName);

  /// 自定义异常收集
  /// @param exceptionType 异常类型
  /// @param causedBy 异常原因
  /// @param errorDump 异常堆栈
  Future<void> setCustomException(String exceptionType, String causedBy, String errorDump);

  /// 自定义事件
  /// @param name 事件名称
  /// @param group 事件分组
  /// @param snapshots 事件快照
  /// @param value 事件值
  /// @param attributes 事件扩展信息
  Future<void> setCustomEvent(String name,
      {String? group, String? snapshots, double? value, Map<String, String>? attributes});

  /// 自定义日志
  /// @param logInfo 日志信息
  /// @param name 日志名称
  /// @param snapshots 日志快照
  /// @param level 日志等级
  /// @param attributes 附加信息
  Future<void> setCustomLog(String logInfo,
      {String? name, String? snapshots, String? level, Map<String, String>? attributes});

  /// 自定义指标
  /// @param metricName 指标名称
  /// @param metricValue 指标值（整型）
  /// @param param 指标附加信息
  Future<void> setCustomMetric(String metricName, int metricValue, String param);

  /// 错误回调接口
  /// @param callback 回调方法
  /// @param error 错误原因
  /// @param stack 错误堆栈
  /// @param isAsync 是否为异步错误
  /// @return 是否要继续处理错误, true 继续处理
  void onRUMErrorCallback(bool callback(Object? error, StackTrace? stack, bool isAsync));

  /// 是否要 dump error
  /// @param enable true, 调用 `FlutterError.dumpErrorToConsole` dump error
  void setDumpError(bool enable);

  /// 获取设备ID
  Future<String?> getDeviceId();

  void triggerCrash();

  void triggerCrash2();
}
